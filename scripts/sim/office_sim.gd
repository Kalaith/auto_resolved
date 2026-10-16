extends RefCounted
## Everything about the current job's office, stepped at a fixed rate by
## main.gd: the building, the elevator, the clock and the staff. It never
## touches nodes; views read its state and send commands, and whatever
## happened in a step is appended to `events` for views and the HUD to drain.
const Det = preload("res://addons/hatchery/core/det.gd")
const BuildingPlan = preload("res://scripts/sim/building_plan.gd")
const Elevator = preload("res://scripts/sim/elevator.gd")
const WorkClock = preload("res://scripts/sim/work_clock.gd")
const StaffFactory = preload("res://scripts/sim/staff_factory.gd")
const Schedule = preload("res://scripts/sim/schedule.gd")
const RoomLayout = preload("res://scripts/sim/room_layout.gd")

const TICK: float = 1.0 / 30.0

var job: RefCounted
var plan: RefCounted
var elevator: Elevator
var clock: WorkClock
var staff: Array = []
var events: Array[Dictionary] = []
## False between the end of one workday and the start of the next.
var day_running: bool = false
var _staff_rng: RandomNumberGenerator
var _by_id: Dictionary = {}


static func create(for_job: RefCounted) -> RefCounted:
	var office: RefCounted = load("res://scripts/sim/office_sim.gd").new()
	office._setup(for_job)
	return office


func _setup(for_job: RefCounted) -> void:
	job = for_job
	plan = BuildingPlan.generate(job)
	elevator = Elevator.new(plan.lowest, plan.highest, 0)
	clock = WorkClock.new()
	staff = StaffFactory.create(job, plan)
	for person in staff:
		_by_id[person.id] = person
	_staff_rng = Det.fork(job.seed_value, "staff_days")


## Opens the office for workday `index`: everyone is at home with a fresh
## plan for the day.
func begin_day(index: int) -> void:
	clock.begin_day(index)
	elevator.reset_to(0)
	for person in staff:
		Schedule.plan_day(person, _staff_rng)
	day_running = true
	emit("day_started", {"day": index})


func step(delta: float) -> void:
	elevator.step(delta)
	if not day_running:
		return
	var ended: bool = clock.step(delta)
	for person in staff:
		Schedule.update(person, self, clock.minute, _staff_rng)
		if person.present:
			person.walker.step(delta, elevator, plan)
	if ended:
		_end_day()


## While the office is paused the player can still ride: only the car moves.
func step_paused(delta: float) -> void:
	elevator.step(delta)


func _end_day() -> void:
	day_running = false
	for person in staff:
		if person.walker.riding:
			elevator.leave(person.id)
		person.present = false
		person.activity = "home"
	emit("day_ended", {"day": clock.day})


func emit(type: String, data: Dictionary = {}) -> void:
	var event: Dictionary = data.duplicate()
	event["type"] = type
	event["at"] = clock.stamp()
	events.append(event)


## Everything that happened since the last drain, oldest first.
func drain_events() -> Array[Dictionary]:
	var drained: Array[Dictionary] = events.duplicate()
	events.clear()
	return drained


func employee(id: String) -> RefCounted:
	return _by_id.get(id)


func present_staff() -> Array:
	return staff.filter(func(person: RefCounted) -> bool: return person.present)


## The lobby's street door: its edge away from the elevator.
func entrance_x() -> float:
	var lobby: Dictionary = plan.find_rooms("lobby")[0]
	if lobby.x < plan.shaft_x:
		return float(lobby.x) + 24.0
	return float(lobby.x) + float(lobby.width) - 24.0


## A place to stand for an errand: in a room of one of `types`, preferring
## floor `near`, beside the printer when there is one. {} when none exists.
func errand_spot(errand: String, types: Array, near: int, rng: RandomNumberGenerator) -> Dictionary:
	var candidates: Array = []
	for type in types:
		candidates.append_array(plan.find_rooms(type))
		if not candidates.is_empty():
			break
	if candidates.is_empty():
		return {}
	var same_floor: Array = candidates.filter(func(room: Dictionary) -> bool: return room.floor == near)
	var room: Dictionary = Det.pick(rng, same_floor if not same_floor.is_empty() else candidates)
	var x: float = rng.randf_range(float(room.x) + 30.0, float(room.x) + float(room.width) - 30.0)
	if errand == "printer":
		for item in RoomLayout.standing(room):
			if item.prop == "printer":
				x = float(item.x) + rng.randf_range(30.0, 46.0)
	return {"floor": int(room.floor), "x": x}
