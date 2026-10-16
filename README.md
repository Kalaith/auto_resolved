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

The game opens on the title: start a new career or continue one. Each job
is a run of workdays; at the end of a day you can hand in notice, and every
job ends with an exit interview, PATCH's update and the job board.

| Input | Action |
| --- | --- |
| Click / tap | Walk there, riding the lift if needed; tap a broken device to fix it, a person to see their card |
| A / D, arrows | Walk |
| E, Space | Fix what is beside you; at the lift: call it, board, or go to the picked floor; at the IT desk: open PATCH |
| W / S | Inside the lift: pick a floor |
| Ticket list | Tap a ticket to walk to the nearest place to fix it; AI asks PATCH about it |
| PATCH button | Talk to PATCH: a ticket, a recurring category, the queue, running automations |
| Incident alert | Open the incident view: timeline, recoveries, guardrails |
| P, 1 / 2 / 3 | Pause, normal, double, fast |
| Tab | Whole-building overview |
| Esc, Menu | Hand in notice, settings, quit to title |
| F1 / F2 / F6 (debug builds) | Force PATCH's next execution to succeed / backfire / pick the backfire |
| F3 / F4 (debug builds) | Open a random ticket / skip to the end of the day |

The career saves to `user://career.json` at the end of each workday and at
every step between jobs.

## Checks

```powershell
$godot = '..\small_following\exports\tooling\Godot_v4.2.2-stable_win64_console.exe'
& $godot --headless --path . --editor --quit                          # import and parse
& $godot --headless --path . --script res://tools/sim_checks.gd       # behaviour checks
& $godot --path . --script res://tools/capture.gd -- captures --size=1280x720   # screenshots (--only=career|buildings|day|patch|menus)
& $godot --headless --path . --script res://tools/headcount_report.gd  # staff per archetype
```

Captures need a window (not `--headless`); write them outside the project or
under `docs/` so Godot does not import them.

## Publish

```powershell
.\publish.ps1 -BuildOnly    # export web + Windows to builds/, no deploy
.\publish.ps1 -DryRun       # show what a publish would do
```
