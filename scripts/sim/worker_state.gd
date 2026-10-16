extends RefCounted
## The IT worker's own state: stress, hunger and how busy they look. The
## player's position is presentation-side, so main.gd reports each frame
## where they stand and what they are doing; the office steps this with
## office minutes like everything else.
##
## Stress rises with every fix, with the size of the queue and faster with
## overdue tickets, and faster again when hungry. It falls at the IT office and
## while eating. A stressed worker fixes more slowly; at 100 they snap at
## someone, which management notices. Hunger only falls by eating. Wandering
## the building with nothing to do looks lazy and costs confidence; the IT
## office, any task, eating, the arrival rush and the lunch hour all count as
## busy.
const Balance = preload("res://addons/hatchery/core/balance.gd")

var stress: float = 0.0
var hunger: float = 0.0
## Office minutes spent looking idle in a row.
var idle_minutes: float = 0.0
var snaps: int = 0
## Reported by main.gd each frame.
var room_type: String = ""
var working: bool = false
var eating: bool = false
var _warned_idle: bool = false


func _init() -> void:
	stress = Balance.number("worker.stress_start")
	hunger = Balance.number("worker.hunger_start")


## A new morning: some stress carries over, breakfast resets hunger.
func begin_day() -> void:
	stress *= Balance.number("worker.overnight_stress_keep")
	hunger = Balance.number("worker.hunger_start")
	idle_minutes = 0.0
	_warned_idle = false


func report(room: String, is_working: bool, is_eating: bool) -> void:
	room_type = room
	working = is_working
	eating = is_eating


func at_it() -> bool:
	return room_type == "it_office"


func is_hungry() -> bool:
	return hunger >= Balance.number("worker.hungry_at")


func is_starving() -> bool:
	return hunger >= Balance.number("worker.starving_at")


## Whether staff would call this slacking right now.
func looks_idle(phase: String) -> bool:
	return not working and not eating and not at_it() and phase != "lunch" and phase != "arrival"


func is_seen_slacking() -> bool:
	return idle_minutes >= Balance.number("worker.idle_grace_minutes")


## How much longer every fix and recovery takes, from stress and hunger.
func fix_time_scale() -> float:
	var scale: float = 1.0 + stress / 100.0 * Balance.number("worker.fix_slowdown")
	if is_starving():
		scale *= Balance.number("worker.starving_slowdown")
	return scale


func walk_scale() -> float:
	return Balance.number("worker.starving_walk") if is_starving() else 1.0


## A manual fix just finished: dealing with people is tiring, and long fixes
## more so (stress_per_fix is per half hour of effort).
func on_fix(effort_minutes: float) -> void:
	stress += Balance.number("worker.stress_per_fix") * effort_minutes / 30.0 * _hunger_scale()


func ate() -> void:
	hunger = 0.0


func _hunger_scale() -> float:
	return Balance.number("worker.hungry_stress_scale") if is_hungry() else 1.0


func step(office: RefCounted, minutes: float) -> void:
	var hours: float = minutes / 60.0
	hunger = minf(100.0, hunger + Balance.number("worker.hunger_per_hour") * hours)
	var now: float = office.clock.stamp()
	var open: float = 0.0
	var overdue: float = 0.0
	for ticket in office.helpdesk.queue.open_tickets():
		open += 1.0
		if ticket.is_overdue(now):
			overdue += 1.0
	var gain: float = Balance.number("worker.stress_per_open_hour") * minf(open, Balance.number("worker.open_cap"))
	gain += Balance.number("worker.stress_per_overdue_hour") * minf(overdue, Balance.number("worker.open_cap"))
	stress += gain * _hunger_scale() * hours
	if eating:
		stress -= Balance.number("worker.calm_eating_per_hour") * hours
	elif at_it() and not working:
		stress -= Balance.number("worker.calm_at_it_per_hour") * hours
	stress = maxf(stress, 0.0)
	if stress >= 100.0:
		_snap(office)
	_step_idle(office, minutes, hours)


func _snap(office: RefCounted) -> void:
	snaps += 1
	stress = Balance.number("worker.snap_stress_after")
	office.metrics.add_confidence(-Balance.number("worker.snap_confidence"))
	office.emit("worker_snapped", {"snaps": snaps})


func _step_idle(office: RefCounted, minutes: float, hours: float) -> void:
	if not looks_idle(office.clock.phase()):
		idle_minutes = 0.0
		_warned_idle = false
		return
	idle_minutes += minutes
	if not is_seen_slacking():
		return
	office.metrics.add_confidence(-Balance.number("worker.idle_confidence_per_hour") * hours)
	if not _warned_idle:
		_warned_idle = true
		office.emit("worker_slacking", {})
