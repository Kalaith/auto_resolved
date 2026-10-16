extends RefCounted
## Creates the job's staff from its building: one employee per desk, a
## department per open-plan room, a manager in each exec office. Every draw
## comes from the job's "staff" stream, so the same job has the same people.
## The IT office's desk is the player's and gets nobody.
const Catalog = preload("res://scripts/core/catalog.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const RoomLayout = preload("res://scripts/sim/room_layout.gd")
const Employee = preload("res://scripts/sim/employee.gd")
const Walker = preload("res://scripts/sim/walker.gd")

## Room types whose desks are staffed, and the role sitting there.
const STAFFED: Dictionary = {"open_office": "worker", "exec_office": "manager"}
## Employees sit on the chair just left of the desk's centre.
const CHAIR_OFFSET: float = -14.0


static func create(job: RefCounted, plan: RefCounted) -> Array:
	var rng: RandomNumberGenerator = Det.fork(job.seed_value, "staff")
	var people: Dictionary = Catalog.people
	var departments: Array = people.departments.duplicate()
	Det.shuffle(rng, departments)
	var used_names: Dictionary = {}
	var staff: Array = []
	var office_index: int = 0
	for index in plan.floor_indices():
		for room in plan.rooms_on(index):
			if not STAFFED.has(room.type):
				continue
			var department: Dictionary = people.management
			if STAFFED[room.type] == "worker":
				department = departments[office_index % departments.size()]
				office_index += 1
			for item in RoomLayout.standing(room):
				if item.prop != "desk_pc":
					continue
				var person: Employee = _person(rng, staff.size(), room, float(item.x), department, used_names)
				person.role = STAFFED[room.type]
				staff.append(person)
	return staff


static func _person(rng: RandomNumberGenerator, index: int, room: Dictionary, desk: float, department: Dictionary, used: Dictionary) -> Employee:
	var people: Dictionary = Catalog.people
	var person := Employee.new()
	person.id = "e%d" % index
	person.name = unique_name(rng, used)
	person.department = str(department.id)
	person.department_label = str(department.label)
	person.colour = Color(str(department.colour))
	person.desk_room = str(room.id)
	person.desk_floor = int(room.floor)
	person.desk_x = desk + CHAIR_OFFSET
	person.tech_confidence = rng.randf_range(float(people.traits.tech_confidence[0]), float(people.traits.tech_confidence[1]))
	person.patience = rng.randf_range(float(people.traits.patience[0]), float(people.traits.patience[1]))
	person.mood = rng.randf_range(0.6, 0.85)
	var speed: float = rng.randf_range(Balance.number("staff.walk_speed_min"), Balance.number("staff.walk_speed_max"))
	person.walker = Walker.new(person.id, 0, 0.0, speed)
	person.walker.wait_offset = _landing_spot(rng)
	person.walker.ride_offset = rng.randf_range(-26.0, 26.0)
	return person


## Somewhere beside the landing, either side of the doors, outside the shaft.
static func _landing_spot(rng: RandomNumberGenerator) -> float:
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	return side * rng.randf_range(58.0, 110.0)


static func unique_name(rng: RandomNumberGenerator, used: Dictionary) -> String:
	var people: Dictionary = Catalog.people
	var candidate: String = ""
	for attempt in range(12):
		candidate = "%s %s" % [Det.pick(rng, people.first_names), Det.pick(rng, people.last_names)]
		if not used.has(candidate):
			break
	used[candidate] = true
	return candidate
