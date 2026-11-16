# Auto-Resolved: agent TODO

Updated 16 November 2026. Only outstanding work an agent can do alone belongs
here: bug fixes, required improvements and next steps. Playtests, listening,
publishing and decisions that need the owner are left out on purpose. Remove a
task when it is done; what is built is described in
[IMPLEMENTATION_GUIDE](IMPLEMENTATION_GUIDE.md).

Review basis (16 November): the headless editor import is clean, `sim_checks`
passes 10 of 10 (they cover M0 only: data, buildings, the lift), and
`day_report` and `headcount_report` ran. Nothing was looked at or played in
this review.

Standing rule: the owner asked for no further headless checks after M0
(guide section 10). Verify new work with the capture tour and the two report
tools unless that changes.

## 1. Bugs and reliability

- [ ] **A day left half-way.** The career saves only at the end of a workday
  and between jobs. Check what Menu > Quit to title does in the middle of a
  day and what Continue then restores. If the day is silently lost, either
  say so before quitting or keep a day checkpoint in `career_store.gd`
  (schema bump, old saves still load).
- [ ] **Show that the big offices are winnable with PATCH.** `day_report`
  plays hand-fixing only: about 13 fixes a day everywhere, against 28 to 48
  tickets opened in tiers 3 and 4 (law firm 23.6 left open at day end,
  megacorp 34.4, bank 34.3, data centre 35.1). Add a second policy to
  `tools/day_report.gd` that approves PATCH's proposals and automations the
  way a careful player would, and print open tickets, backfires and the
  day's warning for each archetype. Retune `data/balance.json` and
  `data/companies.json` only where that policy still ends in a firing.
- [ ] **Staff ranges are wide inside a tier** (startup 4 to 21, bank 31 to
  65 in `headcount_report`). Check the smallest and largest rolls of each
  archetype in the capture tour (`--only=buildings`) for empty floors and
  for lift queues, and narrow the range in `data/companies.json` where one
  breaks.

## 2. Required before a store build

- [ ] **Version.** `project.godot` has no `config/version`. Add `0.1.0`,
  show it on the title, and keep `publish.json` in step.
- [ ] **Credits and licences.** No credits page exists. Add one from the
  title with the Godot licence and third-party notices read from the engine
  (`Engine.get_license_text`, `get_copyright_info`), as The Bound God does.
- [ ] **Quit on desktop.** No script calls `get_tree().quit()`. Add Quit to
  the title and the job menu on desktop builds only.
- [ ] **Windows executable details.** The Windows preset has
  `application/modify_resources=false` and no icon. Set the icon from
  `assets/icon.svg`, plus product name, company, version and copyright.
- [ ] **Gamepad and focus.** No pad bindings or focus handling were found.
  Add focus navigation to the title, job board, PATCH panel, incident view
  and menus with the toolkit's `ui/focus.gd`, and pad bindings with
  `input/pad_bindings.gd`. Drive every screen once by scripted pad input in
  the capture tour.

## 3. Verification an agent can do

- [ ] **Browser pass.** `.\publish.ps1 -BuildOnly`, serve `builds/web` from a
  fresh local port and drive it in Chrome: title, new career, the tutorial
  day, a manual fix, a PATCH approval, end of day, reload and Continue. Check
  the console for errors and that every drawn string is ASCII.
- [ ] **Touch pass.** Repeat the capture tour's `day` and `patch` parts with
  emulated touch input only (tap to walk, tap a device, tap a ticket) and fix
  anything that needs hover or a key.
- [ ] **Recapture** `docs/verification/` after any of the above changes a
  screen, and look at the images.

## 4. Next steps

- [ ] **Sprites for props** (guide M7, last bullet): `room_props.gd` still
  draws every prop as shapes and `assets/` holds only the icon and title
  art. Replace props one kind at a time, keeping prop ids and layout.
- [ ] **A finale for the career.** A career is an open run of jobs. Add a
  closing beat once PATCH has every upgrade or the top tier is cleared
  (the GDD's north star: PATCH becomes an effective successor), with a
  summary of the jobs worked.
- [ ] **Named recurring staff** (GDD question 5): let one or two people
  follow the player between jobs through `data/people.json` and
  `text_staff.json`, remembering an incident from the last job.

## Rules that still hold

- Nothing in `scripts/sim/` touches the scene tree, `Time` or global
  randomness. Catalogs hold only what the code implements.
- UI and drawn text stay ASCII for the web font.
- Files stay under 800 lines (`patch_desk.gd` is the largest at 461). See
  `AGENTS.md`.
