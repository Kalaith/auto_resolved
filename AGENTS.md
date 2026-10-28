# Auto-Resolved project guidance

Auto-Resolved is a 2D, browser-playable Godot game: a side-on cutaway of a multi-floor office where the player is a junior IT worker keeping the building running with PATCH, a newly released and overconfident AI assistant. Each job is a run; PATCH's upgrades carry from job to job. The shared standards at the end of this file apply as well as everything here.

Read before working:

- `docs/GAME_DESIGN.md`: the game design document. Respect its pillars.
- `docs/IMPLEMENTATION_GUIDE.md`: the decisions that adjust the GDD (multi-floor building, elevator, career of jobs), the architecture, and the milestone plan. With the code, it is the reference for what is built and what comes next.

`docs/` carries a `.gdignore`: Godot does not import it and the export excludes it. Keep design notes, reference images (`docs/reference/`) and captures there.

## Product invariants

- The office is the main screen: a side-on cutaway of the whole building, floors stacked around an elevator. Keep the HUD small and contextual; the building stays visible.
- Every job generates its building from its company archetype and seed: floor count, width, elevator position, room layout and palette. The same job always gives the same building, and no two archetypes share a look.
- People change floors only by the elevator (and later stairs). Nothing teleports between floors.
- The player can always move, including while panels are open. Movement never depends on tickets, PATCH or the clock.
- A job ends only when the player quits or is fired. Quitting is always possible and is a positive progression step, not a failure.
- PATCH is one continuous character across jobs. Its upgrades are bought with points at the end of a job and persist; buildings, staff, tickets and local automations reset.
- Every AI execution has a nonzero, calculated, displayed (as a range) chance to backfire. Backfires come from the approved action's own pool and are recoverable; never a silent, unapproved destructive action.
- Better companies pay more and are harder: bigger buildings, more staff, new issue types.
- The room, prop, archetype, issue, action, backfire and upgrade catalogs stay bounded to implemented effects.

## Project engineering

- **Compatibility** renderer (required for the Web export). Base resolution 1280x720, `canvas_items` stretch, `expand` aspect. Mouse and touch must both work; nothing essential on hover alone.
- UI text is ASCII only: the web build's default font lacks arrows, bullets and similar glyphs.
- Layers: `scripts/core/` (catalog loading and validation), `scripts/sim/` (RefCounted rules and state: jobs, building plans, the elevator, and later the office simulation), `scripts/world/` (Node2D views and the player), `scripts/ui/` (CanvasLayer HUD and panels). Sim code never touches nodes; views read sim state and send commands.
- Per-job randomness forks from the job seed with `Det.fork(seed, "<stream>")`, one stream per system, so adding draws to one system never reshuffles another.
- Data lives in `data/` with `schema_version`, validated at startup by `scripts/core/catalog.gd` (catalogs and every balance number the code reads). Add a new catalog's validation there before using it.
- World coordinates: floor `f` stands on y = `-f * floor_height`; x runs 0..width across the building interior. Feet are at a node's origin.
- The shared WebHatchery Godot toolkit (`../godot_toolkit`) is linked in as `res://addons/hatchery/` by `..\godot_toolkit\tools\Link-Toolkit.ps1 -ProjectDir .` (a junction, ignored by Git). Auto-Resolved uses `Balance`, `JsonIO`, `DataRules`, `Det`, `Palette`/`UiKit`, and the check and capture runners. Reach for `JsonSave`, `SettingsStore`, `SettingsPanel`, `KeyBindings`, `ScreenSwitcher`, `Synth` and `VoicePool` before writing that plumbing. Change toolkit code in `../godot_toolkit` under its own AGENTS.md.
- Removing or copying this project must not follow the `addons/hatchery` junction: delete the junction itself first (`cmd /c rmdir addons\hatchery`), never recursively through it.

## Project checks

- Headless checks: `tools/sim_checks.gd` running `tools/checks/checks_*.gd` (data, building generation, elevator). The project owner has asked for no new tests; do not add check modules unless asked.
- Screenshot tour: `tools/capture.gd` in parts (`--only=career|buildings|day|patch|menus`): every archetype close and overview, a ride, a day from arrival to evening, PATCH proposals and a forced incident, the menus, and the career screens with a save round trip. Shots are written flat to `docs/verification/`. Look at the images after any visual change. The career parts use a throwaway career with saving switched off.
- Balancing: `tools/headcount_report.gd` prints staff per archetype over many seeds; keep each tier inside the guide's table. `tools/day_report.gd` runs a day per archetype with a stand-in player fixing by hand and prints tickets opened, fixed and left over: the left-over number is how much a day needs PATCH (tier 1 should leave several).
- Commands are in README.md. Exports and headless tooling use the standard (non-mono) editor at `C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe`, or `GODOT_EXE`.

## Commit voice

Commit lines describe what changed as it is felt in the office, by the player or by PATCH.

```
The elevator now waits for whoever is still walking to it (elevator dwell)
PATCH offers to restart the printer every morning (printer automation)
```

## Publishing

Publishing (`publish.ps1`, `publish-itch.ps1`) requires separate authorisation. `.\publish.ps1 -BuildOnly` (export only, no deploy) is fine for verification. Both are the shared templates from `../godot_toolkit/templates/`; the work lives in `../godot_toolkit/publishing/Publisher.ps1`.

## Shared WebHatchery Godot standards

Identical in every WebHatchery Godot project's AGENTS.md; change all together. Project-specific rules go above.

### Working

- Stay inside this project unless the user broadens the task; preserve user changes; never overwrite original art.
- No installing/upgrading Godot, export templates, tools, plugins or GDExtensions without approval; prefer built-in features.

### Code

- Godot **4.7.2** GDScript, statically typed everywhere (variables, parameters, returns). `const X = preload("res://...")`. Tabs, LF, UTF-8, final newline.
- Simulation/rules code never touches the scene tree, `Time`, `OS` or global `randi()`/`randf()`; randomness comes from an owned `RandomNumberGenerator` (same seed, same result). Presentation reads state and sends commands, nothing else.
- Balance and catalogs (upgrades, parts, miracles, blocks, ...) live in JSON under `data/` with stable ids (and `schema_version` where present), validated at startup, holding only implemented effects. Missing or mistyped data fails fast and is reported; never default silently in code.
- Persistent state lives under `user://` with schema validation, staged writes and backup recovery. A failed save never loses progress or spends anything.

### Verification

- No `tests/` directory, frameworks or addons. Any automated checks are headless scripts in `tools/`, kept out of the export.
- Checks don't gate commits. At a major feature or milestone, run all checks (plus `--headless --editor --quit`) and fix findings.
- Headless checks can't verify visuals, audio, input or feel: run the game and look. State plainly what was and wasn't checked.

### Verification images

- Only `docs/verification/` (flat; keep its `.gdignore` and `docs/`'s). Reference art: `docs/reference/` or `docs/art/`.
- Capture via the toolkit's `testing/capture_runner.gd` or `testing/capture_paths.gd` (`CapturePaths.file(label)`); never pass an output directory or write elsewhere (`builds/`, `exports/`, OS temp, `user://`).
- Stable names `<label>.png`: no subfolders, timestamps, run/revision/size suffixes, `-final`/`-fix` variants or backups. Recapturing a screen or state overwrites; new labels only for genuinely new ones.
- One window size and UI scale per game. Look at the image before saying a visual change works.

### Size limits (hard rule)

- **Functions ≤ 400 lines; files ≤ 800 lines** (scripts, scenes, data, docs, catalogs). Check: `git ls-files -co --exclude-standard | grep -E '\.(gd|tscn|json|md)$' | xargs wc -l | sort -n | tail`.
- Split scripts by responsibility before they grow. A change that would cross a limit, or touches something already over, brings it under in the same change: split functions into named helpers; move a cohesive responsibility (HUD, settings wiring, area building, save validation, layout, a catalog section, ...) into its own file the original delegates to or loads. Keep public members other scripts use working.
- **Never shrink by deleting blank lines, joining statements, removing comments, minifying or packing entries onto one line.** Move content; don't squeeze it.

### Commits

- **ALWAYS commit each feature slice and bug fix the moment it works. Mandatory.** One slice per commit; never batch, never leave finished work uncommitted, never end a turn with an uncommitted feature or fix. Don't wait to be asked or offer instead of doing it; a later request ("also tweak X") is a new slice.
- Commit **all pending changes**, including modified, added and deleted files you didn't make: review and preserve them, include them in validation, finish with a clean tree.
- **Before the final reply of any turn that touched files:** run `git status --short`; if it prints anything, commit and rerun until empty. A dirty tree means unfinished; the closing summary says the tree is clean.
- Ignore rules still apply; never force-add ignored files or commit secrets. Don't push or publish unless asked.

Message: one present-tense line, no trailing period, under ~100 characters before the tag, saying what changed **as the player feels it** (for the toolkit, as the games using it feel it), then a plain lowercase tag in parentheses for what it technically is (the system touched, `docs`, `refactor` for structural changes, or a milestone id such as `M25`). Fixes and refactors are still described by effect. Add a body only when the reason isn't obvious.

```
The Lantern Fair opens: be more interesting than the fair (third map)
A prayer at the tree now feeds the god's Favour (shrine favour)
Builders no longer wall themselves into the cottage they are raising (site reservation fix)
No script over 800 lines: split main and the ritual screen (refactor)
Every game's saves now survive a torn write (json save)
Scribes set down the covenant: design and building plan (docs)
```
