extends RefCounted
## One member of staff: who they are, where their desk is, their traits and
## how the day is going for them. The schedule (schedule.gd) decides what they
## do next; their walker carries them there.
const Walker = preload("res://scripts/sim/walker.gd")

var id: String = ""
var name: String = ""
var department: String = ""
var department_label: String = ""
var colour: Color = Color.WHITE
## "worker" at an open-plan desk or "manager" in an exec office.
var role: String = "worker"
var desk_room: String = ""
var desk_floor: int = 0
var desk_x: float = 0.0
## The workstation device at this desk (set once devices exist).
var device_id: String = ""
## Traits, 0..1: how well they help themselves, and how long they wait calmly.
var tech_confidence: float = 0.5
var patience: float = 0.5
## 0 miserable .. 1 delighted. Falls while IT problems block them.
var mood: float = 0.7
## How much of a normal day's work they are managing, 0..1.
var productivity: float = 1.0
var present: bool = false
## home, arriving, working, walking, visiting, returning, leaving.
var activity: String = "home"
## What they went to do on a trip: kitchen, meeting, printer, break.
var errand: String = ""
var walker: Walker
## Today's plan, in minutes of the day.
var arrive_at: float = 0.0
var leave_at: float = 0.0
var lunch_at: float = 0.0
var lunch_out: bool = false
var lunch_done: bool = false
var busy_until: float = 0.0
var next_decision: float = 0.0
## Recent IT trouble, remembered for reactions: ticket ids and incident kinds.
var history: Array[String] = []


func full_name() -> String:
	return name


func at_desk() -> bool:
	return present and activity == "working" and walker.arrived() and walker.floor_index == desk_floor


func mood_word() -> String:
	if mood >= 0.7:
		return "content"
	if mood >= 0.45:
		return "fine"
	if mood >= 0.25:
		return "frustrated"
	return "furious"


func remember(note: String) -> void:
	history.append(note)
	if history.size() > 6:
		history.pop_front()
