# IT Guy

You are starting your IT career the same week PATCH, a new AI assistant, is
released. Keep a multi-floor office running: walk the floors, ride the
elevator, fix what breaks, and decide how much to trust PATCH. Stay until you
quit or are fired, spend what you earned upgrading PATCH, and take the next
job: a bigger company, better pay, a building that looks nothing like the last.

- Design: [IT_Guy_Game_Design_Document.md](IT_Guy_Game_Design_Document.md)
- Plan and architecture: [docs/IMPLEMENTATION_GUIDE.md](docs/IMPLEMENTATION_GUIDE.md)
- Agent rules: [AGENTS.md](AGENTS.md)

Godot 4.2.2, Compatibility renderer, web and Windows exports.

## Setup

The shared toolkit must be linked once (a junction, ignored by Git):

```powershell
..\godot_toolkit\tools\Link-Toolkit.ps1 -ProjectDir .
```

## Run

```powershell
.\Run.ps1
```

| Input | Action |
| --- | --- |
| A / D, arrows | Walk |
| E, Space | At the elevator: call it, or board when open. Inside: go to the picked floor |
| W / S | Inside the elevator: pick a floor |
| Click / tap | Walk there, riding the elevator if needed |
| Tab | Whole-building overview |
| F12 | Debug: next company archetype, new seed |

## Checks

```powershell
$godot = '..\small_following\exports\tooling\Godot_v4.2.2-stable_win64_console.exe'
& $godot --headless --path . --editor --quit                          # import and parse
& $godot --headless --path . --script res://tools/sim_checks.gd       # behaviour checks
& $godot --path . --script res://tools/capture.gd -- captures --size=1280x720   # screenshots
```

Captures need a window (not `--headless`); write them outside the project or
under `docs/` so Godot does not import them.

## Publish

```powershell
.\publish.ps1 -BuildOnly    # export web + Windows to builds/, no deploy
.\publish.ps1 -DryRun       # show what a publish would do
```
