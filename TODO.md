# Auto-Resolved: agent TODO

Updated 18 November 2026. Only outstanding work an agent can do alone belongs
here: bug fixes, required improvements and next steps. Playtests, listening,
publishing and decisions that need the owner are left out on purpose. Remove a
task when it is done; what is built is described in
[IMPLEMENTATION_GUIDE](docs/IMPLEMENTATION_GUIDE.md).

Review basis (16 November): the headless editor import is clean, `sim_checks`
passes 10 of 10 (they cover M0 only: data, buildings, the lift), and
`day_report` and `headcount_report` ran. Nothing was looked at or played in
this review.

Standing rule: the owner asked for no further headless checks after M0
(guide section 10). Verify new work with the capture tour and the two report
tools unless that changes.

## 1. Bugs and reliability

Nothing open.

## 2. Required before a store build

Nothing open.

## 3. Verification an agent can do

Nothing open.

## 4. Next steps

Nothing open. Prop sprites (guide M7) wait on art from the owner: no prop
art exists yet, and the title art came from the owner's image prompt
(`docs/art/title_image.md`).

## Analytics: anonymous play stats to Hatchery Signals (from one_more_upgrade, 22 Nov 2026)

one_more_upgrade (commits `57848cc` and `19a5af8`) now sends anonymous play
stats to Hatchery Signals, the WebHatchery analytics portal
(`D:\WebHatchery\apps\game_analytics`, live at
`https://webhatchery.au/game_analytics`). The client lives in the toolkit:
`res://addons/hatchery/telemetry/signals_client.gd` (toolkit commit `acd98a2`;
documented under "telemetry" in `godot_toolkit/GODOT_TOOLKIT.md`; the event
contract is `apps/game_analytics/docs/EVENT_CONTRACT.md`). It sends session
start, a heartbeat per minute of active play, session end, once-per-install
milestones and, for run-based games, `run_started` / `run_ended` reports.
Events go out in batches in the background and never block the game. Reports,
milestones and the session end are kept in `user://` until they are delivered.
Every build (editor, local preview, itch, webhatchery.au) sends to the live
portal and tags its source. Reporting is off headless, with `--no-save` or
`--no-analytics`, and when the player turns off "Share anonymous play stats".
Use the toolkit files; do not copy one_more_upgrade's. For a working example,
read one_more_upgrade's `scripts/presentation/main.gd` (search for
`analytics`), `scripts/presentation/settings_flow.gd`,
`scripts/presentation/run_report.gd`, `tools/analytics_check.gd` and the
Analytics line in its `AGENTS.md`.

- [ ] **Config.** Add `data/analytics.json`:
  ```json
  {
  	"schema_version": 1,
  	"endpoint": "https://webhatchery.au/game_analytics/api/v1/events",
  	"game": "auto_resolved",
  	"write_key": "<prefix>-<40 hex digits>"
  }
  ```
  Make a new random key, for example in PowerShell:
  `"ar-" + -join ((1..20) | ForEach-Object { '{0:x2}' -f (Get-Random -Maximum 256) })`.
  The key ships in the build. It identifies the game and is not a secret.
  Check that each preset's `include_filter` in `export_presets.cfg` takes it
  (`data/*.json` or `*.json` already does).
- [ ] **Portal key (the user's step).** The portal accepts a batch only if
  `GAME_WRITE_KEYS_JSON` in `apps/game_analytics/backend/.env` (local and
  production) has `"auto_resolved": "<the key>"`. Do not read or edit that
  `.env`. Tell the user the slug and key so they can add them. Until they do,
  every batch gets HTTP 403 and is dropped. The game is not affected.
- [ ] **Mount the client.** Start it in `scripts/main.gd`'s `_ready`, which
  lives for the whole launch. The pattern:
  ```gdscript
  const SignalsClient = preload("res://addons/hatchery/telemetry/signals_client.gd")
  const SignalsConfig = preload("res://addons/hatchery/telemetry/signals_config.gd")
  var analytics: SignalsClient
  # in _ready, once settings are loaded:
  analytics = SignalsClient.new()
  add_child(analytics)
  analytics.is_playing = func() -> bool: return <in gameplay>
  analytics.start("res://data/analytics.json", SignalsConfig.allowed(),
  		bool(<settings>.value(SignalsClient.SETTING_KEY)), false)  # false: no Steam bridge
  ```
  `is_playing`: true while the player is on the office floors during a work
  day; false on the title, menus and the PATCH upgrade screen. The client
  counts active time only while the window has focus and either `is_playing`
  is true or the player gave input in the last 45 s. The session end is sent
  automatically on quit.
- [ ] **Opt-out setting.** Settings are `scripts/settings_flow.gd` (the
  toolkit's `settings_bundle.gd`, the same shape as one_more_upgrade's). Add
  `SignalsClient.SETTING_KEY: true` to the defaults, a toggle labelled
  `SignalsClient.SETTING_LABEL` ("Share anonymous play stats") in the Display
  section (or the nearest equivalent), and on a change call
  `analytics.set_enabled(bool(<settings>.value(SignalsClient.SETTING_KEY)))`.
  one_more_upgrade does this in `settings_flow.gd` (DEFAULTS, WORDS and
  sections) and in `main.gd`'s setting-changed handler.
- [ ] **Milestones.** Call `analytics.milestone_once("<name>")` at the first
  meaningful progression moments. Names are stable snake_case ids, sent once
  per installation, and each must answer a design question ("do players get
  past X?"). Do not report every action. Suggested: `first_issue_fixed`,
  `first_day_completed`, `first_patch_upgrade`, `first_job_ended` and
  `second_company_started`.
- [ ] **Run reports.** Each job is a run. Send `run_started` when a job begins
  (company id, job number, PATCH upgrade levels as an id => level map) and
  `run_ended` when the player quits, is fired or abandons the job (`outcome`
  `quit`/`fired`/`abandoned`, days worked, issues fixed and missed, pay
  earned, PATCH trust as an int, company id, upgrade levels). Put the report
  builders in one pure script (like one_more_upgrade's `run_report.gd`: same
  state in, same report out). Call `analytics.run_started(report)` when a run
  begins (send `{}` when a saved run is continued) and
  `analytics.run_ended(report)` when it ends, before the run state is
  replaced. `analytics.run_seconds()` gives the run's active seconds. Reports
  hold catalogue ids, counts and flags only: snake_case keys, ints, floats,
  bools or id-like strings, one level of nesting (an id => count map or a list
  of up to 64 scalars), 8 KB at most. The portal's run view reads `wave`,
  `floor`, `bosses`, `seconds`, `outcome`, `mode`, `killer`, `player`,
  `enemy`, `lab` and `sets`, so use those names where they fit. Other keys are
  kept too.
- [ ] **Check.** Add `tools/analytics_check.gd` (headless, seconds,
  `extends SceneTree`, prints FAIL lines, exits 1). It must check that
  `SignalsConfig.read("res://data/analytics.json", errors)` gives no errors,
  that every milestone name the game uses is snake_case, and, if the game
  sends run reports, that reports built from scripted play pass
  `ReportRules.problems()` (`addons/hatchery/telemetry/report_rules.gd`) and
  survive `JsonIo.whole_numbers(JsonIo.from_bytes(JsonIo.bytes(...)))` with
  their counts still ints. Copy the optional
  `-- --endpoint=http://127.0.0.1:<port>/events` path from one_more_upgrade's
  check, which sends one real batch to a local server and expects 202. Never
  point it at the live portal. Also run the project's parse check and
  `--headless --editor --path . --quit`.
- [ ] **Docs.** Add an Analytics line to `AGENTS.md`, modelled on
  one_more_upgrade's: the client and where it starts, `data/analytics.json`
  and the key that must match `GAME_WRITE_KEYS_JSON.auto_resolved`, what the
  reports hold (ids, counts and flags only, never free text), when reporting
  is off, and the check command. Add the check to the checks list. Capture the
  settings screen with the new toggle and look at it.

## Rules that still hold

- Nothing in `scripts/sim/` touches the scene tree, `Time` or global
  randomness. Catalogs hold only what the code implements.
- UI and drawn text stay ASCII for the web font.
- Files stay under 800 lines (`patch_desk.gd` is the largest at 461). See
  `AGENTS.md`.
