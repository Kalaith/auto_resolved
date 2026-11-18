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

## Screen fit: a real 1920x1080 layout (from spiritwright, 18 Nov 2026)

Spiritwright (commit `4a335a1`) now lays out at 1920x1080 on a 1080p screen
instead of stretching a 1280x720 layout by 1.5x, so bigger screens show more
room, not bigger text. How it works: `project.godot` has a 1920x1080 viewport
with `stretch/mode="canvas_items"` and `stretch/aspect="expand"`, and
`scripts/ui/screen_fit.gd` (started from `main.gd`'s `_ready` with
`ScreenFit.watch(get_tree().root)`) sets `root.content_scale_size` on every
resize. Windows between 1280x720 and 1920x1080 get one layout unit per
pixel. Larger screens are scaled up so the layout stays at least 1920x1080
(4K doubles), and smaller ones are shrunk to a 1280x720 layout. The Interface
size setting (`content_scale_factor`) still multiplies on top. Use the
toolkit's `res://addons/hatchery/settings/screen_fit.gd` (it also handles
high-DPI screens and takes the smallest layout as an argument) rather than
copying spiritwright's file.

- [ ] `project.godot`: viewport 1280x720 -> 1920x1080 (already `expand`, no
  window override). Mount screen fit in the main scene's `_ready`.
- [ ] No hardcoded 1280/720 in scripts, so layouts should follow; check that
  side panels and the HUD use their extra room at 1920 (spiritwright widens
  its map side panel to 500 at 1700+ wide instead of 410).
- [ ] The Interface size slider (`settings_flow.gd`, 85-150%) stays on
  `content_scale_factor`; check 150% still fits a 1280x720 layout.
- [ ] Capture every screen (title, settings, the main play screen and each
  panel/overlay) at 1920x1080, 1600x900, 1280x720 and 1280x800, and look at
  them: nothing pinned to the old 1280 edge, no panel left skinny in the
  middle of a wide layout, no text overlapping. Then play the web build in
  Chrome at a full-screen 1080p window and a small one.
- [ ] Toggle full screen and drag-resize the window mid-screen: anything
  sized once at build time (e.g. `get_viewport_rect()` read in `_ready`)
  must follow `resized`, or it keeps the old width.

- [ ] **Lift throughput in tier 4.** With one 8-person car, rolls over about
  50 staff (megacorp, bank, data centre) queue 20 to 30 deep in the lobby at
  9:00 and about 25 people are still not at their desk at 9:35
  (`headcount_report`). Add stairs between neighbouring floors (the
  invariants allow them) or a second car for tier 4, then rerun the report
  and the `roll_*_largest` captures.

## Rules that still hold

- Nothing in `scripts/sim/` touches the scene tree, `Time` or global
  randomness. Catalogs hold only what the code implements.
- UI and drawn text stay ASCII for the web font.
- Files stay under 800 lines (`patch_desk.gd` is the largest at 461). See
  `AGENTS.md`.
