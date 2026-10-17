# Auto-Resolved project guidance

Auto-Resolved is a 2D, browser-playable Godot game: a side-on cutaway of a multi-floor office where the player is a junior IT worker keeping the building running with PATCH, a newly released and overconfident AI assistant. Each job is a run; PATCH's upgrades carry from job to job. The shared standards at the end of this file apply as well as everything here.

Read before working:

- `Auto_Resolved_Game_Design_Document.md`: the game design document. Respect its pillars.
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
- Screenshot tour: `tools/capture.gd` in parts (`--only=career|buildings|day|patch|menus`): every archetype close and overview, a ride, a day from arrival to evening, PATCH proposals and a forced incident, the menus, and the career screens with a save round trip. Look at the images after any visual change. The career parts use a throwaway career with saving switched off.
- Balancing: `tools/headcount_report.gd` prints staff per archetype over many seeds; keep each tier inside the guide's table. `tools/day_report.gd` runs a day per archetype with a stand-in player fixing by hand and prints tickets opened, fixed and left over: the left-over number is how much a day needs PATCH (tier 1 should leave several).
- Commands are in README.md. Exports and headless tooling use the standard (non-mono) editor at `..\small_following\exports\tooling\Godot_v4.2.2-stable_win64_console.exe`, or `GODOT_EXE`.

## Commit voice

Commit lines describe what changed as it is felt in the office, by the player or by PATCH.

```
The elevator now waits for whoever is still walking to it (elevator dwell)
PATCH offers to restart the printer every morning (printer automation)
```

## Publishing

Publishing (`publish.ps1`, `publish-itch.ps1`) requires separate authorisation. `.\publish.ps1 -BuildOnly` (export only, no deploy) is fine for verification. Both are the shared templates from `../godot_toolkit/templates/`; the work lives in `../godot_toolkit/publishing/Publisher.ps1`.

## Shared WebHatchery Godot standards

This section is identical in the AGENTS.md of every WebHatchery Godot project (`bound_god`, `small_following`, `spiritwright`, `godot_toolkit`). Change it in all four together; project-specific rules go in the sections above.

### Working

- Work only inside this project unless the user explicitly broadens the task. Preserve any user changes.
- Do not install or upgrade Godot, export templates, tools, plugins or GDExtensions without approval. Prefer built-in engine features.
- Do not overwrite original art.

### Code

- Godot **4.2.2** GDScript. The renderer is set per project (see above).
- Static typing everywhere: variables, parameters and return types.
- Load dependencies with `const X = preload("res://...")`.
- Tabs, LF, UTF-8, final newline (`.editorconfig`).
- Split scripts by responsibility before they grow. Size limits are below.
- Simulation and rules code never touches the scene tree, `Time`, `OS` or the global `randi()`/`randf()`. All randomness comes from an owned `RandomNumberGenerator`, so the same seed gives the same result. Presentation reads that state and sends commands; it never changes it any other way.
- Balance numbers and catalogs live in JSON under `data/` with stable ids (and `schema_version` where a catalog has one), validated at startup. Missing or mistyped data fails fast: report it, never silently default in code.
- Keep every catalog (upgrades, parts, miracles, blocks and so on) bounded to implemented effects. Do not add entries the code does not support.
- Persistent state lives under `user://` with schema validation, staged writes and backup recovery. A failed save must never lose progress or spend anything.

### Verification

- Do not create a `tests/` directory, test frameworks or test addons. Automated checks, where a project has them, are headless scripts in `tools/`, kept out of the exported game.
- Checks do not gate commits. Run the full set (the project's checks, if any, and a parse/import check with `--headless --editor --quit`) when a major feature or milestone is finished, and fix what they find before calling it done.
- Headless checks do not verify visuals, audio, input or feel. Verify anything visual by running the game (`Run.ps1`) and looking at it.
- Say plainly what was and was not checked.

### Size limits (hard rule)

- **No function may exceed 400 lines.**
- **No file may exceed 800 lines**: scripts, scenes, data, docs and text catalogs. Check with `git ls-files -co --exclude-standard | grep -E '\.(gd|tscn|json|md)$' | xargs wc -l | sort -n | tail`.
- When a change would push a function or file past its limit, or one is already over, **bring it below the limit in the same change**. Split a long function into well-named helpers; shrink a file by moving a cohesive responsibility (HUD, settings wiring, area building, save validation, layout, a catalog section and so on) into its own file and having the original delegate to or load it.
- **Never shrink a function or file by deleting blank lines, joining statements, removing comments, minifying or packing several entries onto one line.** Blank lines between functions and the existing comment density stay as they are. Line count comes down by moving content, not by squeezing it.
- Keep public members that other scripts use working, either in place or through a delegating function.

### Commits

- Commit early and often: after every complete, working step (a system, a fix, a data pass), not at the end of a milestone. Commits do not wait on checks (see Verification).
- Commit **all pending project changes**, including modified, added and deleted files you did not make yourself. Do not leave user changes or another agent's changes uncommitted because you did not touch them: review and preserve their contents, include them in the validation, and finish with a clean working tree.
- Existing ignore rules still apply to generated files, local tooling and credentials. Never force-add ignored files or commit secrets.
- Do not push or publish unless the user asks.

Message style: one line describing what changed **as it is felt by the player** (for the toolkit, by the games that use it), then a short plain tag in parentheses saying what it is technically.

```
Neris raises a ward whenever she is struck (spirit trait)
A prayer at the tree now feeds the god's Favour (shrine favour)
The Lantern Fair opens: be more interesting than the fair (third map)
Every game's saves now survive a torn write (json save)
Scribes set down the covenant: design and building plan (docs)
```

- Present tense, no trailing period, under ~100 characters before the tag where possible.
- Fixes and refactors are still described by their effect: `Builders no longer wall themselves into the cottage they are raising (site reservation fix)`, `No script over 800 lines: split main and the ritual screen (refactor)`.
- Tags are lowercase and plain: the system touched, `docs`, `refactor`, or a milestone id such as `M25`.
- Add a body only when the reason is not obvious from the line.
