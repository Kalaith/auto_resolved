extends RefCounted
## One support ticket. Lifecycle: new -> triaged -> in_progress -> resolved,
## with the side states blocked, reopened and deleted (PATCH's doing, mostly).
## Times are job stamps (minutes since the job began, see WorkClock.stamp).

const OPEN_STATES: Array[String] = ["new", "triaged", "in_progress", "blocked", "reopened"]

var id: int = 0
var issue: String = ""
var title: String = ""
var device_id: String = ""
## The employee who reported it ("" for shared equipment).
var reporter: String = ""
## The floor an outage covers, for floor-wide issues.
var floor_index: int = 0
var status: String = "new"
var severity: int = 1
var created: float = 0.0
var deadline: float = 0.0
var resolved_at: float = -1.0
## player, patch, automation
var resolved_by: String = ""
## Marked resolved by PATCH while the problem is still there (false success).
var falsely_closed: bool = false
## An earlier incident this ticket belongs to, if any.
var incident_id: int = -1


func is_open() -> bool:
	return OPEN_STATES.has(status)


func is_overdue(now: float) -> bool:
	return is_open() and now > deadline


## Minutes until the deadline (negative once overdue).
func minutes_left(now: float) -> float:
	return deadline - now


func source() -> String:
	return "ticket:%d" % id


func to_dict() -> Dictionary:
	return {
		"id": id, "issue": issue, "title": title, "device": device_id, "reporter": reporter,
		"floor": floor_index, "status": status, "severity": severity, "created": created,
		"deadline": deadline, "resolved_at": resolved_at, "resolved_by": resolved_by,
		"falsely_closed": falsely_closed, "incident": incident_id,
	}
