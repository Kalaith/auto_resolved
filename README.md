# Auto-Resolved

You are starting your IT career the same week PATCH, a new AI assistant, is
released. Keep a multi-floor office running: walk the floors, ride the
elevator, fix what breaks, and decide how much to trust PATCH. Stay until you
quit or are fired, spend what you earned upgrading PATCH, and take the next
job: a bigger company, better pay, a building that looks nothing like the last.

- Design: [GAME_DESIGN.md](docs/GAME_DESIGN.md)
- Plan and architecture: [docs/IMPLEMENTATION_GUIDE.md](docs/IMPLEMENTATION_GUIDE.md)
- Agent rules: [AGENTS.md](AGENTS.md)

Godot 4.7.2, Compatibility renderer, web and Windows exports.

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
| Eat button, kitchen fridge / vending | Eat (resets hunger, calms you down; costs office time) |
| Games button (in the IT office) | Play games at the IT desk: a big stress drop for 30 office minutes |
| P, 1 / 2 / 3 | Pause, normal, double, fast |
| Tab | Whole-building overview |
| Esc, Menu | Hand in notice, settings, quit to title |
| F1 / F2 / F6 (debug builds) | Force PATCH's next execution to succeed / backfire / pick the backfire |
| F3 / F4 (debug builds) | Open a random ticket / skip to the end of the day |

Your own state matters: every fix uses office minutes (the clock races
while you work), so a day only holds so many manual fixes. Fixes and a
backlog raise your stress, hunger makes it worse, and wandering about idle
outside the IT office costs confidence. The first job's first day has a
skippable tutorial.

The career saves to `user://career.json` at the end of each workday and at
every step between jobs.

## Checks

```powershell
$godot = 'C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --editor --quit                          # import and parse
& $godot --headless --path . --script res://tools/sim_checks.gd       # behaviour checks
& $godot --path . --script res://tools/capture.gd # screenshots into docs/verification (--only=career|buildings|day|patch|menus)
& $godot --headless --path . --script res://tools/headcount_report.gd  # staff per archetype
& $godot --headless --path . --script res://tools/day_report.gd        # tickets vs hand-fixing capacity per day
```

Captures need a window (not `--headless`). They are written flat to
`docs/verification/` (the one folder for verification images; Godot ignores it).

## Publish

```powershell
.\publish.ps1 -BuildOnly    # export web + Windows to builds/, no deploy
.\publish.ps1 -DryRun       # show what a publish would do
```

## Promoter capture

Promoter uses the shared [Godot capture driver](../godot_toolkit/tools/promo/README.md); this project does not need its own capture script. It starts from the title screen. Use the documented mouse, keyboard and ticket controls above to stage public features. See the [Promoter plan and update rules](../../local_apps/promoter/adapters/godot/README.md).

From this project root, check whether source changes need an update video:

```powershell
$promoter = (Resolve-Path '..\..\local_apps\promoter').Path
$project = (Resolve-Path '.').Path
& "$promoter\scripts\godot-promo.ps1" -Mode status -ProjectRoot $project -ProjectKey auto-resolved
```

Keep `auto-resolved` as the project key when generating later videos. Put plans and generated media under Promoter's ignored `data/media/` directory.
