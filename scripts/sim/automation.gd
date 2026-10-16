extends RefCounted
## A PATCH automation installed at this job: an approved proposal that runs
## on a cadence. Each run is one execution with its own risk roll (never one
## per employee or per tick). A backfire pauses it until the player decides.

var id: int = 0
## The approved proposal it repeats (action, scope, floor, safeguards).
var proposal: RefCounted
var enabled: bool = true
## Why it is off: "" (running), "incident" or "player".
var paused_by: String = ""
var next_run: float = 0.0
var runs: int = 0
var successes: int = 0
## Successful runs per day (day -> count), for the "ran clean all day" points.
var clean_days: Dictionary = {}
var failed_days: Dictionary = {}


func name() -> String:
	return str(proposal.action().label)


func covers_floor(index: int) -> bool:
	return proposal.scope == "building" or proposal.floor_index == index


func covers_issue(issue: String) -> bool:
	return proposal.action().intents.has(issue)
