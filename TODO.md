# Auto-Resolved: agent TODO

Updated 16 November 2026. Only outstanding work an agent can do alone belongs
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

- [ ] **Sprites for props** (guide M7, last bullet): `room_props.gd` still
  draws every prop as shapes and `assets/` holds only the icon and title
  art. Replace props one kind at a time, keeping prop ids and layout.
## Rules that still hold

- Nothing in `scripts/sim/` touches the scene tree, `Time` or global
  randomness. Catalogs hold only what the code implements.
- UI and drawn text stay ASCII for the web font.
- Files stay under 800 lines (`patch_desk.gd` is the largest at 461). See
  `AGENTS.md`.
