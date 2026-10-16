extends RefCounted
## What each employee does next, by phase of the day: arrive through the lobby
## and go to their desk, work, run the odd errand (printer, meeting, kitchen,
## break room), take lunch at their desk or out, and go home. Decisions come
## from the office's "staff" stream; the walker does the moving.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Det = preload("res://addons/hatchery/core/det.gd")

## Errand -> room types that serve it.
const ERRANDS: Dictionary = {
	"printer": ["printer_bay"],
	"meeting": ["meeting_room"],
	"kitchen": ["kitchen", "break_room"],
	"break": ["break_room", "kitchen"],
}


## Rolls one employee's plan for a new day.
static func plan_day(person: RefCounted, rng: RandomNumberGenerator) -> void:
	person.present = false
	person.activity = "home"
	person.errand = ""
	person.walker.stop()
	person.walker.riding = false
	person.arrive_at = rng.randf_range(Balance.number("staff.arrive_first_minute"), Balance.number("staff.arrive_last_minute"))
	person.leave_at = rng.randf_range(Balance.number("day.leaving_start_minute"), Balance.number("staff.leave_last_minute"))
	person.lunch_at = rng.randf_range(Balance.number("day.lunch_start_minute"), Balance.number("day.lunch_end_minute") - 20.0)
	person.lunch_out = Det.chance(rng, Balance.number("staff.lunch_out_chance"))
	person.lunch_done = false
	person.busy_until = 0.0
	person.next_decision = person.arrive_at + rng.randf_range(10.0, 30.0)


## One decision step for `person` at `minute`; `office` gives the building,
## the entrance and blocked state. Only acts once the walker has arrived.
static func update(person: RefCounted, office: RefCounted, minute: float, rng: RandomNumberGenerator) -> void:
	match person.activity:
		"home":
			if minute >= person.arrive_at and minute < person.leave_at:
				_arrive(person, office)
		"arriving", "returning":
			if person.walker.arrived():
				person.activity = "working"
				person.errand = ""
		"walking":
			if person.walker.arrived():
				person.activity = "visiting"
				person.busy_until = maxf(person.busy_until, minute + 3.0)
		"visiting":
			if minute >= person.busy_until:
				_return_to_desk(person)
		"leaving":
			if person.walker.arrived():
				person.present = false
				person.activity = "home"
		"working":
			_decide_at_desk(person, office, minute, rng)


static func _arrive(person: RefCounted, office: RefCounted) -> void:
	person.present = true
	person.activity = "arriving"
	person.walker.floor_index = 0
	person.walker.riding = false
	person.walker.x = office.entrance_x()
	_send_to_desk(person)


static func _send_to_desk(person: RefCounted) -> void:
	person.walker.go_to(person.desk_floor, person.desk_x)


static func _return_to_desk(person: RefCounted) -> void:
	person.activity = "returning"
	_send_to_desk(person)


static func _decide_at_desk(person: RefCounted, office: RefCounted, minute: float, rng: RandomNumberGenerator) -> void:
	if minute >= person.leave_at:
		person.activity = "leaving"
		person.walker.go_to(0, office.entrance_x())
		return
	if not person.lunch_done and minute >= person.lunch_at:
		person.lunch_done = true
		var lunch: float = rng.randf_range(Balance.number("staff.lunch_minutes_min"), Balance.number("staff.lunch_minutes_max"))
		if person.lunch_out and _go_on_errand(person, office, "kitchen", minute + lunch, rng):
			return
		person.busy_until = minute + lunch
		return
	if minute < person.next_decision or minute < person.busy_until:
		return
	var every: float = Balance.number("staff.decide_every_minutes")
	person.next_decision = minute + every * rng.randf_range(0.6, 1.4)
	if office.clock.phase() == "lunch" or not Det.chance(rng, Balance.number("staff.trip_chance_per_hour") * every / 60.0):
		return
	var errand: String = str(Det.pick(rng, ["printer", "printer", "meeting", "kitchen", "break"]))
	var stay: float = rng.randf_range(Balance.number("staff.trip_minutes_min"), Balance.number("staff.trip_minutes_max"))
	_go_on_errand(person, office, errand, minute + stay, rng)


## Sends `person` to a room for `errand`, preferring their own floor. False
## when the building has no such room.
static func _go_on_errand(person: RefCounted, office: RefCounted, errand: String, until: float, rng: RandomNumberGenerator) -> bool:
	var spot: Dictionary = office.errand_spot(errand, ERRANDS[errand], person.desk_floor, rng)
	if spot.is_empty():
		return false
	person.activity = "walking"
	person.errand = errand
	person.busy_until = until
	person.walker.go_to(int(spot.floor), float(spot.x))
	return true
