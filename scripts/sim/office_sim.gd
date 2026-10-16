extends RefCounted
## Everything about the current job's office, stepped at a fixed rate by
## main.gd: the building, the elevator, the clock, the staff, their devices,
## the helpdesk's tickets and the company's view of IT. It never
## touches nodes; views read its state and send commands, and whatever
## happened in a step is appended to `events` for views and the HUD to drain.
const Det = preload("res://addons/hatchery/core/det.gd")
const BuildingPlan = preload("res://scripts/sim/building_plan.gd")
const Elevator = preload("res://scripts/sim/elevator.gd")
const WorkClock = preload("res://scripts/sim/work_clock.gd")
const StaffFactory = preload("res://scripts/sim/staff_factory.gd")
const Schedule = preload("res://scripts/sim/schedule.gd")
const RoomLayout = preload("res://scripts/sim/room_layout.gd")
const DeviceFactory = preload("res://scripts/sim/device_factory.gd")
const Helpdesk = preload("res://scripts/sim/helpdesk.gd")
const CompanyMetrics = preload("res://scripts/sim/company_metrics.gd")
const PatchState = preload("res://scripts/sim/patch_state.gd")
const PatchDesk = preload("res://scripts/sim/patch_desk.gd")

## Issues the Remote session upgrade lets the player fix from the IT desk.
const REMOTE_ISSUES: Array[String] = ["password", "software_install", "slow_pc", "new_employee"]

const TICK: float = 1.0 / 30.0

var job: RefCounted
var plan: RefCounted
var elevator: Elevator
var clock: WorkClock
var staff: Array = []
var devices: Array = []
var helpdesk: Helpdesk
var metrics: CompanyMetrics
## PATCH as a character (carried between jobs) and its work at this job.
var patch: PatchState
var patch_desk: PatchDesk
## Outages covering whole floors: source -> {"fault", "block", "floors"}.
var area_faults: Dictionary = {}
var events: Array[Dictionary] = []
## False between the end of one workday and the start of the next.
var day_running: bool = false
## Management's warnings so far (career_rules.gd), and whether the player has
## handed in notice (the job ends when the current day does).
var warnings: int = 0
var notice_given: bool = false
## The manager summoned to the IT office tomorrow morning ("" for nobody).
var summoned: String = ""
## Each finished day's tallies, oldest first.
var day_summaries: Array[Dictionary] = []
var _staff_rng: RandomNumberGenerator
var _starter_rng: RandomNumberGenerator
var _by_id: Dictionary = {}
var _devices_by_id: Dictionary = {}
var _used_names: Dictionary = {}


## `patch_state` is the career's PATCH; null gives a fresh v1.0.
static func create(for_job: RefCounted, patch_state: RefCounted = null) -> RefCounted:
	var office: RefCounted = load("res://scripts/sim/office_sim.gd").new()
	office._setup(for_job, patch_state if patch_state != null else PatchState.new())
	return office


func _setup(for_job: RefCounted, patch_state: RefCounted) -> void:
	job = for_job
	patch = patch_state
	plan = BuildingPlan.generate(job)
	elevator = Elevator.new(plan.lowest, plan.highest, 0)
	clock = WorkClock.new()
	staff = StaffFactory.create(job, plan)
	for person in staff:
		_by_id[person.id] = person
		_used_names[person.name] = true
	devices = DeviceFactory.create(plan, staff)
	for device in devices:
		_devices_by_id[device.id] = device
	helpdesk = Helpdesk.new(job.seed_value)
	metrics = CompanyMetrics.new()
	patch_desk = PatchDesk.new(job.seed_value)
	patch_desk.greet(self)
	_staff_rng = Det.fork(job.seed_value, "staff_days")
	_starter_rng = Det.fork(job.seed_value, "new_starters")


## Opens the office for workday `index`: everyone is at home with a fresh
## plan for the day.
func begin_day(index: int) -> void:
	clock.begin_day(index)
	elevator.reset_to(0)
	for person in staff:
		Schedule.plan_day(person, _staff_rng)
	helpdesk.roller.begin_day(index, clock.start_minute)
	metrics.begin_day()
	patch_desk.begin_day()
	day_running = true
	emit("day_started", {"day": index})


func step(delta: float) -> void:
	elevator.step(delta)
	if not day_running:
		return
	var before: float = clock.minute
	var ended: bool = clock.step(delta)
	for person in staff:
		Schedule.update(person, self, clock.minute, _staff_rng)
		if person.present:
			person.walker.step(delta, elevator, plan)
	helpdesk.roller.step(self, clock.minute)
	patch_desk.step(self)
	metrics.step(self, clock.minute - before)
	_sync_elevator()
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
	metrics.end_day()
	day_summaries.append(metrics.day.duplicate(true))
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


## Picks someone senior to walk down to the IT office tomorrow morning.
func summon_manager() -> void:
	for person in staff:
		if person.role == "manager":
			summoned = person.id
			return
	if not staff.is_empty():
		summoned = staff[0].id


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


func device(id: String) -> RefCounted:
	return _devices_by_id.get(id)


func devices_of(kind: String) -> Array:
	return devices.filter(func(item: RefCounted) -> bool: return item.kind == kind)


func tickets_for_person(person_id: String) -> Array:
	return helpdesk.queue.open_for_person(person_id)


## Floors where somebody has a desk, lowest first.
func staffed_floors() -> Array[int]:
	var result: Array[int] = []
	for person in staff:
		if not result.has(person.desk_floor):
			result.append(person.desk_floor)
	result.sort()
	return result


func pick_staffed_floor(rng: RandomNumberGenerator) -> int:
	return int(Det.pick(rng, staffed_floors(), 0))


func add_area_fault(source: String, fault: String, block: float, floors: Array) -> void:
	area_faults[source] = {"fault": fault, "block": block, "floors": floors.duplicate()}


## Takes away everything one ticket or incident did to devices and floors.
func clear_source(source: String) -> void:
	area_faults.erase(source)
	for item in devices:
		item.clear_source(source)


## Whether an area fault of `fault` covers floor `index`.
func floor_has(fault: String, index: int) -> bool:
	for source in area_faults:
		var area: Dictionary = area_faults[source]
		if area.fault == fault and area.floors.has(index):
			return true
	return false


## The share of work IT problems take from `person` right now, 0..1.
func block_for(person: RefCounted) -> float:
	var worst: float = 0.0
	var desk: RefCounted = device(person.device_id)
	if desk != null:
		worst = desk.block()
	for source in area_faults:
		var area: Dictionary = area_faults[source]
		if area.floors.has(person.desk_floor):
			worst = maxf(worst, float(area.block))
	return worst


## How much more or less likely `issue` is on `target` than its base rate:
## PATCH's prevention automations lower it; 1 means untouched.
func issue_factor(issue: String, target: RefCounted) -> float:
	return patch_desk.prevention(issue, target)


## Whether the player may fix `issue` from the IT desk instead of walking.
func remote_fix_allowed(issue: String) -> bool:
	return patch.remote_session() and REMOTE_ISSUES.has(issue)


## A new hire takes over a desk: new name, fresh mood, no history.
func replace_with_new_starter(person: RefCounted) -> void:
	var old_name: String = person.name
	person.name = StaffFactory.unique_name(_starter_rng, _used_names)
	person.mood = 0.65
	person.history.clear()
	emit("new_starter", {"employee": person.id, "replaces": old_name})


## The lift controller's faults show in how the car behaves.
func _sync_elevator() -> void:
	var lift: RefCounted = device("lift")
	var confused: bool = lift != null and lift.has_fault("confused")
	elevator.stop_everywhere = confused
	elevator.speed_scale = (0.6 if confused else 1.0) * patch_desk.lift_boost()
