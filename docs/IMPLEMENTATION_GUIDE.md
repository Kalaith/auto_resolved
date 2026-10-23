# Auto-Resolved implementation guide

This guide turns `GAME_DESIGN.md` (the GDD) into a build plan
for Godot 4.7.2. It records the decisions that change or settle the GDD, the
architecture the code follows, what is already built, and the milestones that
come next. When the code and this guide disagree, fix whichever is wrong in
the same change.

Status legend: **Built** is in the code and checked. **Next** is the
following milestone. **Planned** is designed here but not started.

Milestones M0 to M7 are **Built**. Section 4 records M0 in detail and
section 4.4 maps every later system to its files; section 5 keeps each
milestone's plan with notes on how it was built.

---

## 1. Decisions that adjust the GDD

The GDD was written for a single top-down office. The direction for this
project changes that in four ways; everything else in the GDD stands.

### 1.1 A side-on, multi-floor building with an elevator

- The office is a **cutaway building seen from the side** (see
  `docs/reference/office_cutaway.png`): floors stacked vertically, each split
  into rooms with their own wall colour, furniture and people.
- One **elevator shaft** runs the full height. Everyone, player and staff,
  changes floor by the elevator. Later tiers may add stairs (slow, always
  available) and a second car; both are Planned.
- The building is **generated per job** from a company archetype and the
  job's seed: floor count, width, basement, elevator position, room mix and
  palette all vary. This replaces the GDD's "one floor, extra floors after the
  vertical slice".
- Movement is one-dimensional on a floor (left/right) plus the elevator. Click
  or tap anywhere to route there automatically.

Why it matters for play: distance is now vertical as well as horizontal. A
printer on the fourth floor is a ride away; a busy elevator is a real cost;
"remote intervention" upgrades (GDD open question 7) become valuable.

### 1.2 The story frame

You are starting your IT career in the same week **PATCH v1.0** is released.
The vendor pitches it as "your new IT colleague". Each job is another
supervised field trial; you are the unlucky but increasingly expert beta
tester (GDD 9.2). PATCH's personality, catchphrases and callbacks carry across
every job.

### 1.3 A career of jobs

- A **job is a run**. You stay until you **quit** or are **fired**. There is
  no other end state: the GDD's burnout folds into firing (an unmanageable
  backlog drives company confidence to zero), and its "successful transition"
  is simply quitting while things are going well.
- **Quit is always available.** Quitting with good standing earns a better
  reference; being fired earns fewer points and a worse reference, never
  nothing.
- At the end of every job you receive **PATCH Points** and spend them on
  PATCH upgrades. Upgrades persist for the rest of the career.
- Then the **job board** offers the next positions. **Better companies pay
  more** and are harder: more floors, more staff, wider issue catalogs, higher
  expectations. Your **reputation** decides which tiers are offered.
- **Pay** accrues per day worked and is the career score (lifetime earnings).
  It is not spent on PATCH; PATCH is upgraded with points earned by doing the
  job well. Optional personal perks bought with savings are Later.

### 1.4 Every job looks different

Each archetype has its own palette and building shape, and each job jitters
the palette's hue and re-rolls the layout and skyline. See section 5.4 for
the levers.

### 1.5 GDD open questions, settled

| GDD question | Decision |
| --- | --- |
| 1. Run length | 20-45 minutes: 3-6 workdays of 6-8 real minutes. Tune in playtests. |
| 2. Resignation | Available at any time from the pause/IT-desk menu; a minimum of one completed day before it pays points. |
| 3. Upgrade cadence | Points earned per job, spent between jobs on an upgrade tree. One guaranteed upgrade choice after each completed job (GDD 18). |
| 4. Next run | A job board of 3 offers; tiers unlocked by reputation. |
| 5. Named employees | Procedural staff per job; PATCH and a few recurring vendor characters carry the story. |
| 6. Failure frequency | Start near the GDD 7.2 table; decline with upgrades. Tune per playtest. |
| 7. Walking vs remote | Walking first; "remote session" is a Capability upgrade that lets some fixes run from the IT desk. |
| 8. Guardrails | Workplace guardrails reset; one per job may be promoted to permanent PATCH knowledge at the exit interview. |

---

## 2. Project layout

```
auto_resolved/
  AGENTS.md, README.md
  project.godot, export_presets.cfg, publish.json
  publish.ps1, publish-itch.ps1, Run.ps1        (toolkit templates)
  addons/hatchery/        junction to ../godot_toolkit/addons/hatchery (ignored)
  assets/                 icon now; sprites, fonts, audio later
  data/                   JSON catalogs with schema_version
  docs/                   .gdignore'd: GAME_DESIGN.md, this guide, reference/, verification/ (captures)
  scenes/main.tscn        a Node2D running scripts/main.gd
  scripts/
    main.gd               owns the office while a job runs, steps the sim, routes input
    career_flow.gd        title, end of day, exit interview, upgrades, job board, save
    settings_flow.gd      preferences and the toolkit settings page
    audio_director.gd     synthesised sound
    debug_keys.gd         F-key debug controls (debug builds only)
    core/catalog*.gd      loads and validates every catalog and balance key
    core/career_store.gd  the career file (toolkit JsonSave)
    sim/                  RefCounted rules and state (no nodes)
    world/                Node2D views and the player
    ui/                   CanvasLayer HUD and panels; ui/screens/ between jobs
  tools/
    sim_checks.gd         headless check runner (M0 modules)
    checks/checks_*.gd    one module per system
    capture.gd            screenshot tour, in parts (--only=career|buildings|day|patch|menus)
    headcount_report.gd   staff per archetype over many seeds, for tuning
```

### Toolkit modules

| Module | Used for | Status |
| --- | --- | --- |
| `core/balance.gd` | `Balance.number("elevator.door_seconds")` | Built |
| `core/json_io.gd`, `core/data_rules.gd` | catalog loading and validation | Built |
| `core/det.gd` | seeded picks, weighted keys, shuffles, `fork` streams | Built |
| `ui/palette.gd`, `ui/ui_kit.gd` | HUD and panels | Built |
| `testing/check_runner.gd`, `expect.gd`, `capture_runner.gd` | tools/ | Built |
| `core/text_catalog.gd` | PATCH and staff dialogue | Built |
| `storage/json_save.gd` | career save (section 8) | Built |
| `settings/settings_store.gd`, `ui/settings_panel.gd`, `input/key_bindings.gd` | settings, rebinding | Built |
| `ui/screen_switcher.gd` | title, job board, exit interview, upgrades | Built |
| `audio/synth.gd`, `voice_pool.gd`, `ambience.gd`, `levels.gd` | office hum, lift ding, printer, alarm | Built |
| `input/pointer_tap.gd` | if click-to-move needs drag rejection on touch | Planned |

---

## 3. Architecture

### 3.1 Layers

- **core**: `catalog.gd` reads `data/*.json` once, validates with `DataRules`,
  and exposes typed lookups. Startup shows `Catalog.problems()` instead of
  running a broken game.
- **sim**: plain `RefCounted` objects. Deterministic from the job seed. Never
  touch nodes, `Time`, `OS` or global random. All state the save needs lives
  here.
- **world**: `Node2D` views that read sim state every frame and draw it, plus
  the player controller. Views send commands (call the elevator, start a fix);
  they never edit sim state directly.
- **ui**: `CanvasLayer` HUD and panels built with `UiKit`.

### 3.2 The office simulation (Built)

One `OfficeSim` (`scripts/sim/office_sim.gd`) owns everything for the current
job and is stepped at a fixed rate from `main.gd`:

```gdscript
# main.gd
func _physics_process(delta: float) -> void:
	_accumulator += delta * time_scale          # pause = 0, fast = 2 or 4
	while _accumulator >= OfficeSim.TICK:
		office.step(OfficeSim.TICK)
		_accumulator -= OfficeSim.TICK
```

```
OfficeSim
  job: Job                    archetype, seed, pay, tier           (Built)
  plan: BuildingPlan          floors, rooms, shaft, colours        (Built)
  elevator: Elevator          car state machine                    (Built)
  clock: WorkClock            day, minute, phase (morning/lunch/afternoon)  (Built)
  staff: Array[Employee]      people with routines and walkers            (Built)
  devices: Array[Device]      workstations, printers, racks, router, lift (Built)
  helpdesk: Helpdesk          TicketQueue, IssueRoller, fixes             (Built)
  patch: PatchState           version, upgrades, guardrails, memory  (persists, Built)
  patch_desk: PatchDesk       chat, proposals, automations, executions, incidents (Built)
  metrics: CompanyMetrics     confidence, productivity, tallies           (Built)
  rng streams: Det.fork(job.seed, "staff" | "issues" | "patch_risk" | ...)
  events: Array[Dictionary]   emitted this tick, drained by views and HUD
```

The player is presentation-side (like small_following's cultist) but reports
"arrived at device X" and "held interact for N seconds" to the sim as
commands. That keeps fixes deterministic and checkable without a scene tree.

### 3.3 Events, not signals, out of the sim

The sim appends dictionaries such as
`{"type": "ticket_opened", "ticket": 12, "device": "f2_r3_d1"}` to
`events`. `main.gd` drains them each frame and fans them out to views (speech
bubbles, device sparks, HUD toasts, PATCH chat). Checks read the same list.
This keeps the sim free of nodes and makes every outcome explainable (GDD 7.5
incident log).

### 3.4 Ids

Everything that can be referenced in a ticket, incident or save has a stable
string id derived from generation order: rooms `f<floor>_r<index>` (Built),
devices `<room id>_d<index>`, employees `e<index>`, tickets incrementing ints.

---

## 4. Built: milestone M0, the building and the elevator

What runs today: a generated building for any archetype, the elevator, a
player who walks, rides and can be sent anywhere by click, a camera with a
whole-building overview, a HUD with company, pay and position, and F12 to
cycle archetypes with a fresh seed.

| File | Responsibility |
| --- | --- |
| `scripts/core/catalog.gd` | rooms.json, companies.json, balance keys: load and validate |
| `scripts/sim/job.gd` | `Job.create(archetype, seed)`: company name, tier, pay |
| `scripts/sim/building_plan.gd` | `BuildingPlan.generate(job)`: floors, rooms, shaft, colours |
| `scripts/sim/theme_colours.gd` | archetype hex theme to Colors with per-job hue turn |
| `scripts/sim/elevator.gd` | car state machine: calls, travel, doors, dwell |
| `scripts/world/building_view.gd` | sky, skyline, ground, shell, rooms, dividers, labels, shaft |
| `scripts/world/room_props.gd` | placeholder furniture drawn from shapes and theme colours |
| `scripts/world/elevator_view.gd` | car layer (behind player) and doors layer (in front of a rider) |
| `scripts/world/player.gd` | walk, call, board, ride, exit, click-to-route |
| `scripts/world/office_camera.gd` | follow and overview zoom |
| `scripts/ui/hud.gd` | company panel, position line, control hints |
| `tools/checks/checks_*.gd` | data loads; rooms tile every floor; required rooms placed; lobby meets shaft; determinism; archetypes differ; elevator behaviour |

### 4.1 Building generation

1. Fork `Det.fork(job.seed, "building")`.
2. Floors above ground: random in the archetype's `floors` range; floor -1
   exists when `basement` is true.
3. Width: random in `width`, rounded to tens. The shaft centre is placed in
   the `elevator_position` fraction range and clamped so each side can hold
   the archetype's narrowest weighted room.
4. Required rooms are assigned to floors: `ground` = 0, `top` = highest,
   `basement` = -1, `any` = the above-ground floor with the fewest required
   rooms so far (ties broken by the generator).
5. Each floor has two segments either side of the shaft. Required rooms go to
   the side with more space, lobby first. Weighted random rooms fill each
   segment while one fits; leftover width is spread over rooms up to their
   maximum, the last room taking any remainder, so walls meet exactly.
6. The lobby is ordered next to the shaft; other rooms are shuffled.
7. Each room picks a wall colour from the theme (never the same as its left
   neighbour) shifted by the room type's `wall_shift`.

Coordinates: floor `f` stands on `y = -f * floor_height`; the ground floor on
`y = 0`; a basement below it. `plan.floor_at_y(y)` maps a click to a floor.

### 4.2 Elevator

States `IDLE -> MOVING -> OPENING -> OPEN -> CLOSING -> IDLE`. Calls queue
first come, first served. Calling the floor the car stands at reopens or holds
the doors. `hurry()` shortens the dwell once a rider has chosen. Speeds and
timings are in `balance.json`.

Planned improvements, in order, each with a check:

1. **Collective control** (M1): serve calls in the direction of travel
   (SCAN), not strictly in order, once several employees ride.
2. **Capacity** (M1): `capacity` riders; others wait at the landing and are
   visible queuing.
3. **Riders as sim data** (M1): the elevator knows who is inside so the sim
   can move them; the player rides through the same API.
4. **Elevator as an IT system** (M4): a building-management "device" PATCH
   can optimise (shorter waits) or break (car stuck, everyone takes the
   stairs, doors open on every floor). It is a natural, visible backfire.

### 4.3 Adding content

- **Room type**: add to `data/rooms.json` (id, label, widths, wall shift,
  props, optional `fill` and `fill_spacing`). Any new prop must also be added
  to `Catalog.PROPS` and drawn in `room_props.gd`.
- **Company archetype**: add to `data/companies.json`. Validation requires a
  ground-floor lobby, known rooms and floor rules, a basement when one is
  required there, and a complete hex theme. Run the checks: every archetype
  is generated for 60 seeds.
- Keep the `required` rooms' minimum widths well below half the narrowest
  building width, or a floor overflows. The tiling check will catch it.
- After changing sizes or weights, run `tools/headcount_report.gd` and keep
  each archetype's mean staff inside its tier's band (section 7.1).

### 4.4 Built since M0: where things live

| System | Files |
| --- | --- |
| Clock, staff, routes | `sim/work_clock.gd`, `employee.gd`, `staff_factory.gd`, `walker.gd`, `schedule.gd`, `room_layout.gd` |
| Office | `sim/office_sim.gd` (owner), `office_snapshot.gd` (end-of-day save state) |
| Devices and tickets | `sim/device.gd`, `device_factory.gd`, `ticket.gd`, `ticket_queue.gd`, `issue_roller.gd`, `helpdesk.gd`, `company_metrics.gd` |
| PATCH | `sim/patch_state.gd` (persists), `patch_desk.gd`, `proposal.gd`, `risk.gd`, `patch_executor.gd`, `patch_effects.gd`, `backfire_effects.gd`, `automation.gd`, `incident.gd` |
| Career | `sim/career.gd`, `career_rules.gd`, `job_board.gd`; `core/career_store.gd`; `scripts/career_flow.gd` |
| World views | `world/staff_view.gd`, `figure_art.gd`, `device_view.gd`, `fault_art.gd`, `bubble_view.gd`, `sky_view.gd`, `window_shade.gd`, `work_controller.gd` |
| UI | `ui/hud.gd`, `clock_bar.gd`, `ticket_panel.gd`, `patch_panel.gd`, `proposal_card.gd`, `incident_panel.gd`, `person_card.gd`, `notice_panel.gd`, `day_report.gd`, `ui/screens/*` |

Notes on how the plan was built:

- The player's walker is stepped in real time by `world/player.gd`; staff
  walkers are stepped by the sim. Pausing stops the office but not the lift,
  so the player can always move. The player may squeeze into a full car.
- Manual fixes and incident recoveries are both "tasks" in
  `work_controller.gd`: walk to a valid place (the device, the IT desk, or
  with Remote session the desk for both), stand there, and the seconds count.
- PATCH talks through structured intents only. Every execution is rolled from
  the job's `patch_risk` stream; guardrails stop their archetype half the time
  (shown as a near miss), which is exactly the risk reduction the card shows.
- Delayed backfires apply their effects later; false successes apply at once
  but stay hidden until their delay passes; partial ones apply success too.
- Firing takes three bad evenings in a row (warning, final warning,
  dismissal); a good evening withdraws a warning. A manager walks down to the
  IT office the morning after a warning.
- The career saves at the end of every workday (with the office snapshot:
  tickets, incidents and the faults they left, automations, guardrails, staff
  names and moods) and at every between-jobs step. Quitting to the title loses
  only the current day.
- Content beyond the plan's minimum: twelve company archetypes (M0's six
  plus game studio, university, hospital, government office, bank and data
  centre company, with M0's sizes retuned), each later one with its own rooms,
  props, palette and one issue family that only happens there.
- After first playtests (too easy, a bit dull): every issue and recovery has
  `effort_minutes`, and the office clock runs through them while the player
  works, so manual capacity per day is limited and PATCH becomes necessary.
  `sim/worker_state.gd` adds the IT worker's stress (fixes, backlog,
  overdue; worse when hungry; slows fixes; snapping costs confidence),
  hunger (eat in a kitchen or break room) and looking idle outside the IT
  office (costs confidence). Ticket rates rose 1.5x with a morning and
  post-lunch rush (`issues.phase.*`) and a gentler first day. A skippable
  day-1 tutorial (`scripts/tutorial.gd`, `data/text_tutorial.json`) runs on a
  career's first job.
- Second pass: rates up 1.6x again and no gentler first day, so even a
  tier-1 office opens about 20 tickets a day against about 14 a perfect
  hand-fixer could clear (`tools/day_report.gd`). Day 1 then runs at
  `issues.first_day_scale` 0.75, tuned so a tier-1 first day ends with about
  four tickets open for the stand-in; playing games at the IT
  desk trades 30 office minutes for a big drop in stress.
- Per the project owner's instruction, no new headless check modules were
  added after M0; behaviour was verified by running the game and the capture
  tour, and the M0 checks still run.

---

## 5. Milestones

Each milestone ends with: headless checks passing, a parse/import check, the
capture tour looked at, a short manual play, and a commit. Size limits from
AGENTS.md apply throughout; split before a file nears 800 lines.

### M1 The living office (Built)

Goal: the building fills with people who arrive, work, take lunch and leave,
using the elevator.

- `sim/work_clock.gd`: day number, minute of the workday, phases (arrival,
  morning, lunch, afternoon, leaving). Balance: `day.real_seconds`,
  phase boundaries. HUD clock, pause and 1x/2x/4x speed.
- `data/people.json`: name parts, departments, role per room type
  (`open_office` desks are workers, `exec_office` has a manager), trait
  ranges (tech confidence, patience). `sim/staff_factory.gd` creates one
  employee per desk from the plan, from `Det.fork(seed, "staff")`.
- `sim/employee.gd`: id, name, department, desk (room id + slot x), traits,
  mood, productivity, current activity, route.
- `sim/route.gd` and `sim/walker.gd`: a route is a list of legs
  (`walk to x on floor f`, `wait for car`, `ride to floor g`). The player's
  click-to-move (now in `player.gd`) moves onto the same walker so player and
  staff share one tested path.
- `sim/schedule.gd`: picks the next activity by phase: desk, kitchen at
  lunch, meeting room, printer trips, leave via lobby.
- `world/employee_view.gd`: placeholder figures in department colours,
  seated at desks; mood shown by a small icon. Clickable for a detail card.
- Elevator: collective control, capacity, riders (section 4.2).
- Checks: staff count equals desks; a scripted day ends with everyone home;
  no one changes floor outside the car; determinism of a full day by seed.

### M2 Devices and tickets (Built)

Goal: things break where people work, and the player fixes them by hand.

- `sim/device.gd` and generation from props: `desk_pc` becomes a
  workstation owned by that desk's employee, `printer` a printer,
  `server_rack` a server, the server room also gets the network core. Device
  ids `<room id>_d<n>`.
- `data/issues.json` (GDD 5.2 launch set): `password`, `printer_offline`,
  `software_install` first; `slow_pc`, `new_employee`, `network` after. Each
  entry: device kinds it can hit, base frequency per device per day,
  severity, patience window, manual fix (where, seconds of hold-to-fix,
  tool), and which employee state it affects.
- `sim/ticket_queue.gd`: lifecycle `New -> Triaged -> In Progress ->
  Resolved`, plus `Blocked`, `Reopened`, `Deleted`. Deadline from the
  reporter's patience.
- Issues are rolled per device on a cadence from `Det.fork(seed, "issues")`,
  scaled by company tier and day.
- Manual fix: walk to the device, hold interact (progress ring over the
  device); some issues fix from the IT office desk (password resets).
- `ui/ticket_panel.gd`: compact queue (click a ticket to route to it).
- Company metrics: productivity (staff blocked by open tickets), company
  confidence (falls with overdue tickets, rises with fast fixes), backlog.
- Checks: issues only target valid devices; a fix resolves exactly its
  ticket; confidence responds in the right direction.

### M3 PATCH, proposals and execution (Built)

Goal: talk to PATCH, review a proposal, approve it, see it work.

- `ui/patch_panel.gd`: a persistent PATCH icon (bottom right) and a fuller
  panel at the IT office desk. Structured intents, not free text: pick a
  ticket, a category ("We keep getting printer tickets") or a device.
- `data/actions.json`: curated action templates (GDD 14.2): intent keys,
  preconditions, targets, scope options (one device, one floor, one
  department, whole building: floors are a natural scope in this building),
  risk class, success effects, backfire pool id, rollback support, dialogue
  keys.
- `sim/proposal.gd`: builds the GDD 13 card: what, who, benefit, what could
  go wrong (risk range), protections. Actions: Approve, Test safely, Ask for
  alternative, Cancel.
- `sim/risk.gd`: the GDD 7.2 formula, every factor from `balance.json`:
  `clamp(base * version * scope * safeguards * context, min, max)`. Display
  as a band ("Low (2-6%)").
- `sim/execution.gd`: verify approval and scope, roll from
  `Det.fork(seed, "patch_risk")`, apply success or select a backfire, append
  the audit log (seed and roll recorded).
- `data/text_patch.json`: proposal, success, failure and retrospective lines
  per action, through the toolkit `TextCatalog`. ASCII only.
- Checks: risk formula matches the table; an approved one-device action never
  touches another device; a recorded seed replays the same outcome.

### M4 Automations, backfires and incidents (Built)

Goal: PATCH can run things on a schedule; sometimes that goes wrong in a
funny, recoverable, physically visible way.

- `sim/automation.gd`: trigger (time of day, event), action, approved
  bounds, cadence, safeguards. Each scheduled run is one execution (GDD 7.2
  note: batch, never per tick per employee).
- `data/backfires.json`: the GDD 7.3 table as pools per action: effect list,
  severity, delay (immediate, next day, partial, false success), recoveries.
  Each backfire must be visible somewhere in the building: the printer floor
  fills with paper, a whole floor's monitors go dark, the elevator stops, the
  ticket panel empties.
- `sim/incident.gd` and `ui/incident_view.gd`: the timeline request -> plan
  -> scope -> execution -> effects -> recovery (GDD 13).
- Recovery actions: rollback, restore snapshot, reissue, re-enable; manual
  repair where needed. Cascades capped per day (balance).
- In-job guardrails: "Never delete tickets without approval", "Stage software
  to one floor first". They reduce the matching archetype's risk or force
  confirmation (GDD 8).
- Debug panel (F-keys, debug builds only): force success, force each backfire
  archetype, add a ticket, skip to end of day.
- Checks: every backfire's effects match its action's domain and scope; the
  cascade cap holds; a guardrail stops its archetype firing identically.

### M5 The end of a job (Built)

- Firing: company confidence below thresholds gives a warning from your
  manager (an email toast and an exec visiting the IT office), then a final
  warning, then dismissal at day end. Never on a single minor failure.
- Quitting: a "Hand in notice" action at the IT desk; finishes the current
  day, then the exit interview.
- `ui/exit_interview.gd`: days worked, people supported, uptime, automations,
  catastrophes, incidents solved (GDD 9.2), pay earned, reference grade, PATCH
  Points earned, and the guardrail to promote.
- PATCH Points (section 7.2) and reputation change are computed in
  `sim/career_rules.gd` so checks can verify them.

### M6 Career, PATCH upgrades and the job board (Built)

- `sim/career.gd`: the persistent owner: PATCH version and upgrades, learned
  failure archetypes, promoted guardrails, unlocked blueprints, reputation,
  savings, job history. Single owner of the save (section 8). Purchases do
  not spend points if the save fails.
- `data/patch_upgrades.json`: the GDD 9.4 tracks (Reliability, Safety,
  Understanding, Capability, Autonomy) as a small tree with costs and
  effects the code implements. Buying upgrades bumps PATCH's version
  (v1.0 -> v1.1 ...).
- `ui/upgrade_screen.gd`: spend points; each node says what it changes in
  play, not "+5%".
- `sim/job_board.gd` and `ui/job_board.gd`: 3 offers from
  `Det.fork(career_seed, "offers_<n>")`: at least one at the current tier,
  one at the next tier when reputation allows, an occasional lateral "weird"
  archetype. Each offer shows company name, archetype, pay per day, floors,
  headcount and a one-line hint of what is new there.
- Title screen: Continue career / New career / Settings.

### M7 Content and polish (Built)

- More archetypes: hospital, game studio, bank, university, government
  office, data centre company; each with one new issue family or legacy
  system (the GDD 9.5 answer to runaway perfection).
- Time of day: the sky colour shifts morning to evening; lit windows at night.
- Employee reactions and speech bubbles, remembered incidents ("Is PATCH
  printing again?").
- Audio from the toolkit synth: elevator ding, printer, office hum, alarm.
- Settings (toolkit `SettingsStore` and `SettingsPanel`), key rebinding,
  fullscreen, UI scale.
- Art: replace `room_props.gd` shapes with sprites one prop at a time; keep
  prop ids and layout.

---

## 6. Data catalogs

Built catalogs: `balance.json`, `rooms.json`, `companies.json`,
`people.json`, `issues.json`, `actions.json`, `backfires.json`,
`patch_upgrades.json`, `text_patch.json`, `text_staff.json`. Every catalog
has `schema_version` and validation in `catalog.gd` or a split
`catalog_<topic>.gd` (people, issues, patch). The game's text catalogs are
checked for every key the code will ask for.

The shapes below were the plan; the built files follow them with these
refinements: issues carry `title`, `fault`, `blocks`, `spread` (device,
floor, building) and optional `archetypes`; actions list `success` effects
(`resolve_ticket`, `resolve_open`, `prevent`, `tune_elevator`,
`triage_queue`, `archive`); backfires hold `archetypes` (with each one's
guardrail), `recoveries` and `pools`; upgrades have `label`, `says` and an
`effects` list.

```json
// issues.json
{"schema_version": 1, "issues": [
  {"id": "printer_offline", "devices": ["printer"], "per_device_per_day": 0.35,
   "min_tier": 1, "severity": 2, "patience_minutes": 90,
   "manual": {"at": "device", "seconds": 4.0}, "blocks": "printing"}
]}

// actions.json
{"schema_version": 1, "actions": [
  {"id": "printer_watchdog", "intents": ["printer"], "kind": "automation",
   "risk_class": "simple", "scopes": ["device", "floor", "building"],
   "cadence": "daily_08_00", "success": {"prevents": "printer_offline"},
   "backfires": "printer_watchdog", "rollback": true}
]}

// backfires.json
{"schema_version": 1, "pools": {"printer_watchdog": [
  {"id": "endless_test_page", "weight": 3, "severity": 1, "delay": "immediate",
   "effects": [{"do": "device_state", "state": "paper_flood"}],
   "recoveries": ["cancel_queue", "clear_jam"], "archetype": "runaway_job"}
]}}

// patch_upgrades.json
{"schema_version": 1, "upgrades": [
  {"id": "staged_rollout", "track": "safety", "cost": 3, "requires": [],
   "effect": {"unlock_safeguard": "staged"}}
]}
```

Keep effect kinds (`"do"` values) a closed list implemented in the sim;
validation rejects unknown ones.

---

## 7. Career and economy (starting numbers)

All of these go in `balance.json` under `career` and are tuned in playtests.

### 7.1 Pay and tiers

| Tier | Example archetypes | Pay per day | Floors | Staff |
| --- | --- | --- | --- | --- |
| 1 | family business, startup | 120-150 | 2-3 | 8-14 |
| 2 | accounting firm, design agency | 210-230 | 3-4 | 14-24 |
| 3 | law firm, hospital | 320-360 | 4-5 + basement | 24-36 |
| 4 | megacorp | 480 | 6-8 + basement | 36-60 |

### 7.2 PATCH Points

Earned during the job, shown live in the HUD so the player can judge when to
quit:

- tickets resolved (manual or by PATCH): small, with diminishing returns per
  identical issue per day;
- automations that ran successfully for a full day: medium;
- incidents recovered: medium; first time an archetype is seen: bonus
  (never repeatable, GDD 10);
- milestones (a day with no overdue tickets, automation coverage over 50%):
  large.

At the end: quitting keeps 100%, firing keeps 60%. Repeated identical
disasters give nothing (GDD 16).

### 7.3 Reputation

A career number moved by each job's reference: a good quit raises it, a
firing lowers it. Tier offered = highest tier whose threshold reputation
meets; a firing can still offer the same tier. Pay feeds lifetime earnings
(score) only.

---

## 8. Save design (Built)

One career file, `user://career.json`, through the toolkit `JsonSave`
(staged write, `.bak` rotation, recovery, version migration). Written at the
end of each workday and at every between-jobs step; never mid-tick.

```json
{
  "schema": 1,
  "career_seed": 123456,
  "patch": {"version": "1.2", "upgrades": ["staged_rollout"],
            "archetypes_seen": ["bulk_delete"], "guardrails": ["confirm_delete"],
            "blueprints": ["printer_watchdog"], "callbacks": ["deleted_all_tickets"]},
  "career": {"reputation": 14, "earnings": 2310, "points": 3,
             "history": [{"archetype": "startup", "name": "Bloop.io", "days": 4,
                          "ended": "quit", "points": 9}]},
  "current_job": {"archetype": "accounting_firm", "seed": 99881, "day": 2,
                  "state": {}}
}
```

`current_job.state` is the office sim snapshot at the end of a day (tickets,
automations, metrics, staff moods). Because the building is regenerated from
archetype and seed, it is never saved.

---

## 9. Visual identity per job

Levers, all data-driven and seeded:

- **Palette** per archetype: sky, exterior, slab, trim, floor, furniture,
  accent and 4+ wall colours. Each job turns the hue by up to `hue_jitter`.
- **Shape**: floor count, basement, width, elevator position, room mix.
- **Skyline** blocks from `Det.fork(seed, "skyline")`.
- **Accent** colours the HUD stripe, elevator badges, couches, vending
  machines and screens, so the company's colour is everywhere.
- Planned: time-of-day sky, exterior signage with the company name,
  archetype-specific props (hospital beds, bank vault, studio dev kits),
  weather in windows, seasonal decorations.

Rules: room labels and text must stay legible on every wall colour (the label
ink flips by luminance); the player and staff must contrast with any wall;
the capture tour shows every archetype, so check it after palette changes.

---

## 10. Verification

The headless checks are M0's (data, building tiling for every archetype,
required rooms, lobby by shaft, determinism, archetypes differ, elevator);
the project owner asked for no further tests, so later milestones were
verified through the capture tour and by playing. The planned check ideas
(staff from desks, risk formula, save round trip and so on) remain good
candidates if that changes.

| Capture part (`--only=`) | Shots |
| --- | --- |
| `career` | title, exit interview, PATCH update, job board, a day saved to JSON and restored |
| `buildings` | every archetype close and overview, a ride |
| `day` | morning arrival, a manual fix, working, lunch crowd, evening |
| `patch` | ticket proposal, approval, automation card, a forced incident and its view |
| `menus` | paper flood, job menu, settings, end of a bad day with a warning |

Headless checks never prove feel. After each milestone, play a full day with
mouse and with touch emulation, and once in the web export
(`.\publish.ps1 -BuildOnly`, then open `builds/web/index.html` from a local
server).

---

## 11. Pitfalls to avoid

- **Junction deletes**: removing this folder recursively follows
  `addons/hatchery` into the shared toolkit. Remove the junction first.
- **Elevator gridlock** once staff ride: stagger arrivals, add capacity and
  collective control before scaling headcount past ~15.
- **Draw cost**: `building_view.gd` redraws only on setup; keep per-frame
  `_draw` to moving things (elevator, people, effects).
- **z-order**: building 0, car 1, riding player 2, doors 3, walking player 4.
  Employees follow the same rule.
- **Web font**: ASCII only in any UI or drawn string.
- **Global randomness**: `main.gd` may draw a new job seed; nothing in
  `scripts/sim/` may call `randi()`/`randf()`.
- **Catalog drift**: never add a room, prop, issue, action or upgrade the code
  does not implement.
