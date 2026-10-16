extends RefCounted
## A job's office building as plain data: floors stacked around one elevator
## shaft, each floor split into rooms on either side of it, every room with its
## own wall colour. Generated from the company archetype and the job seed, so
## the same job always gets the same building.
##
## Coordinates: x runs 0..width across the interior. Floor `f`'s walking line is
## at y = -f * floor_height, so the ground floor stands on y = 0 and a basement
## (floor -1) lies below it.
const Catalog = preload("res://scripts/core/catalog.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const ThemeColours = preload("res://scripts/sim/theme_colours.gd")

var width: float = 0.0
var floor_height: float = 0.0
var shaft_x: float = 0.0
var shaft_width: float = 0.0
var lowest: int = 0
var highest: int = 0
## floor index -> Array of room Dictionaries {id, type, label, x, width, wall}.
var rooms_by_floor: Dictionary = {}
## Resolved theme Colors (sky, exterior, slab, trim, floor, furniture, accent).
var colours: Dictionary = {}


static func generate(job: RefCounted) -> RefCounted:
	var plan: RefCounted = load("res://scripts/sim/building_plan.gd").new()
	plan._build(job)
	return plan


func floor_count() -> int:
	return highest - lowest + 1


func floor_indices() -> Array[int]:
	var result: Array[int] = []
	for index in range(lowest, highest + 1):
		result.append(index)
	return result


func floor_y(index: int) -> float:
	return -float(index) * floor_height


## The floor whose band contains world `y`, clamped to the building.
func floor_at_y(y: float) -> int:
	return clampi(floori(-y / floor_height), lowest, highest)


func shaft_center() -> float:
	return shaft_x + shaft_width * 0.5


func rooms_on(index: int) -> Array:
	return rooms_by_floor.get(index, [])


## The room at interior `x` on floor `index`, or {} inside the shaft.
func room_at(index: int, x: float) -> Dictionary:
	for room in rooms_on(index):
		if x >= room.x and x < room.x + room.width:
			return room
	return {}


func find_rooms(type: String) -> Array:
	var found: Array = []
	for index in floor_indices():
		for room in rooms_on(index):
			if room.type == type:
				found.append(room)
	return found


func _build(job: RefCounted) -> void:
	var data: Dictionary = Catalog.archetype(job.archetype_id)
	var rng: RandomNumberGenerator = Det.fork(job.seed_value, "building")
	floor_height = Balance.number("building.floor_height")
	shaft_width = Balance.number("building.shaft_width")
	lowest = -1 if data.basement else 0
	highest = rng.randi_range(int(data.floors[0]), int(data.floors[1])) - 1
	width = float(_tens(rng.randi_range(int(data.width[0]), int(data.width[1]))))
	var side_minimum: float = _smallest_room_width(data.room_weights) + 20.0
	var centre: float = width * rng.randf_range(float(data.elevator_position[0]), float(data.elevator_position[1]))
	shaft_x = roundf(clampf(centre - shaft_width * 0.5, side_minimum, width - shaft_width - side_minimum))
	colours = ThemeColours.resolve(data.theme, rng)
	var required: Dictionary = _assign_required(data.required, rng)
	var walls: Array[Color] = ThemeColours.walls(data.theme, float(colours.turn))
	for index in floor_indices():
		_build_floor(index, required.get(index, []), data.room_weights, walls, rng)


## Rounds a width down to a multiple of ten so walls land on tidy pixels.
static func _tens(value: int) -> int:
	return value - value % 10


## The narrowest room the archetype fills with, so neither side of the shaft
## is too thin to hold one.
func _smallest_room_width(weights: Dictionary) -> float:
	var smallest: float = INF
	for id in weights:
		smallest = minf(smallest, float(Catalog.rooms[id].min_width))
	return smallest


## floor index -> room types that must be built there.
func _assign_required(required: Array, rng: RandomNumberGenerator) -> Dictionary:
	var result: Dictionary = {}
	for item in required:
		var index: int = 0
		match str(item.floor):
			"ground": index = 0
			"top": index = highest
			"basement": index = lowest
			"any": index = _roomiest_floor(result, rng)
		if not result.has(index):
			result[index] = []
		result[index].append(str(item.room))
	return result


## The above-ground floor with the fewest required rooms so far; ties are
## broken by the job's generator so layouts vary between jobs.
func _roomiest_floor(assigned: Dictionary, rng: RandomNumberGenerator) -> int:
	var best: Array[int] = []
	var fewest: int = 1 << 30
	for index in range(0, highest + 1):
		var count: int = assigned.get(index, []).size()
		if count < fewest:
			fewest = count
			best = [index]
		elif count == fewest:
			best.append(index)
	return int(Det.pick(rng, best))


func _build_floor(index: int, required: Array, weights: Dictionary, walls: Array[Color], rng: RandomNumberGenerator) -> void:
	# Two segments either side of the shaft; each lists its rooms outward from
	# the shaft, so a lobby put first always opens onto the elevator.
	var left_free: float = shaft_x
	var right_free: float = width - shaft_x - shaft_width
	var segments: Array = [[], []]
	var free: Array[float] = [left_free, right_free]
	# The lobby claims its side first so it is never squeezed out.
	var ordered: Array = required.filter(func(type: String) -> bool: return type == "lobby")
	ordered.append_array(required.filter(func(type: String) -> bool: return type != "lobby"))
	for type in ordered:
		var side: int = 0 if free[0] >= free[1] else 1
		var room_width: float = _pick_width(type, free[side], rng)
		segments[side].append({"type": type, "width": room_width})
		free[side] -= room_width
	for side in range(2):
		_fill_segment(segments[side], free[side], weights, rng)
		if ordered.has("lobby"):
			_keep_lobby_by_shaft(segments[side], rng)
		else:
			Det.shuffle(rng, segments[side])
	rooms_by_floor[index] = _place(index, segments, walls, rng)


func _pick_width(type: String, available: float, rng: RandomNumberGenerator) -> float:
	var room: Dictionary = Catalog.room(type)
	var high: int = mini(int(room.max_width), int(available))
	var low: int = mini(int(room.min_width), high)
	return float(maxi(_tens(rng.randi_range(low, maxi(low, high))), low))


## Adds weighted rooms while one fits, then spreads what is left over the
## rooms (up to their maximum, the last one past it) so walls meet exactly.
func _fill_segment(items: Array, free: float, weights: Dictionary, rng: RandomNumberGenerator) -> void:
	while true:
		var fitting: Dictionary = {}
		for type in weights:
			if float(Catalog.room(type).min_width) <= free:
				fitting[type] = weights[type]
		if fitting.is_empty():
			break
		var type: String = str(Det.weighted_key(rng, fitting))
		var room_width: float = _pick_width(type, free, rng)
		items.append({"type": type, "width": room_width})
		free -= room_width
	for item in items:
		var grow: float = minf(free, float(Catalog.room(item.type).max_width) - float(item.width))
		if grow > 0.0:
			item.width += grow
			free -= grow
	if free > 0.0 and not items.is_empty():
		items[items.size() - 1].width += free


func _keep_lobby_by_shaft(items: Array, rng: RandomNumberGenerator) -> void:
	var lobby: Array = items.filter(func(item: Dictionary) -> bool: return item.type == "lobby")
	var rest: Array = items.filter(func(item: Dictionary) -> bool: return item.type != "lobby")
	Det.shuffle(rng, rest)
	items.clear()
	items.append_array(lobby)
	items.append_array(rest)


func _place(index: int, segments: Array, walls: Array[Color], rng: RandomNumberGenerator) -> Array:
	var placed: Array = []
	var x: float = shaft_x
	for item in segments[0]:
		x -= item.width
		placed.push_front(_room(index, item, x))
	x = shaft_x + shaft_width
	for item in segments[1]:
		placed.append(_room(index, item, x))
		x += item.width
	var previous: int = -1
	for i in range(placed.size()):
		var choice: int = rng.randi_range(0, walls.size() - 1)
		if choice == previous and walls.size() > 1:
			choice = (choice + 1) % walls.size()
		previous = choice
		placed[i].id = "f%d_r%d" % [index, i]
		placed[i].wall = ThemeColours.shifted(walls[choice], float(Catalog.room(placed[i].type).wall_shift))
	return placed


func _room(index: int, item: Dictionary, x: float) -> Dictionary:
	return {"id": "", "floor": index, "type": item.type, "label": str(Catalog.room(item.type).label),
		"x": x, "width": float(item.width), "wall": Color.WHITE}
