extends RefCounted
## Every archetype generates sound buildings across many seeds, and the same
## job always generates the same building.
const Catalog = preload("res://scripts/core/catalog.gd")
const Job = preload("res://scripts/sim/job.gd")
const BuildingPlan = preload("res://scripts/sim/building_plan.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")

const SEEDS: int = 60


func check_rooms_tile_each_floor_exactly() -> String:
	for id in Catalog.archetype_ids:
		for seed_value in range(1, SEEDS + 1):
			var plan: RefCounted = BuildingPlan.generate(Job.create(id, seed_value))
			for index in plan.floor_indices():
				var problem: String = _floor_problem(plan, index)
				if not problem.is_empty():
					return "%s seed %d floor %d: %s" % [id, seed_value, index, problem]
	return ""


func check_required_rooms_are_where_the_archetype_says() -> String:
	for id in Catalog.archetype_ids:
		var data: Dictionary = Catalog.archetype(id)
		for seed_value in range(1, SEEDS + 1):
			var plan: RefCounted = BuildingPlan.generate(Job.create(id, seed_value))
			for item in data.required:
				var rooms: Array = plan.find_rooms(item.room)
				var wanted: int = {"ground": 0, "top": plan.highest, "basement": plan.lowest}.get(item.floor, -99)
				var placed: bool = rooms.any(func(room: Dictionary) -> bool: return wanted == -99 or room.floor == wanted)
				if rooms.is_empty() or not placed:
					return "%s seed %d: no %s on the %s floor" % [id, seed_value, item.room, item.floor]
	return ""


func check_lobby_opens_onto_the_elevator() -> String:
	for id in Catalog.archetype_ids:
		for seed_value in range(1, SEEDS + 1):
			var plan: RefCounted = BuildingPlan.generate(Job.create(id, seed_value))
			var lobby: Dictionary = plan.find_rooms("lobby")[0]
			var touches: bool = is_equal_approx(lobby.x + lobby.width, plan.shaft_x) \
				or is_equal_approx(lobby.x, plan.shaft_x + plan.shaft_width)
			if not touches:
				return "%s seed %d: lobby at %s does not meet the shaft" % [id, seed_value, lobby.x]
	return ""


func check_same_job_same_building() -> String:
	var describe := func(seed_value: int) -> String:
		var plan: RefCounted = BuildingPlan.generate(Job.create("startup", seed_value))
		return str([plan.width, plan.shaft_x, plan.highest, plan.rooms_by_floor])
	return Expect.all([
		Expect.deterministic(describe, 4242, "building generation"),
		Expect.truthy(describe.call(1) != describe.call(2), "different seeds give different buildings"),
	])


func check_archetypes_look_different() -> String:
	var skies: Dictionary = {}
	for id in Catalog.archetype_ids:
		var plan: RefCounted = BuildingPlan.generate(Job.create(id, 7))
		skies[str(plan.colours.sky.to_html(false)) + str(plan.rooms_on(0)[0].wall.to_html(false))] = id
	return Expect.equal(skies.size(), Catalog.archetype_ids.size(), "every archetype has its own palette")


func _floor_problem(plan: RefCounted, index: int) -> String:
	var rooms: Array = plan.rooms_on(index)
	if rooms.is_empty():
		return "no rooms"
	var expected: float = 0.0
	for room in rooms:
		if absf(room.x - expected) > 0.01:
			if absf(expected - plan.shaft_x) > 0.01 or absf(room.x - plan.shaft_x - plan.shaft_width) > 0.01:
				return "gap or overlap at x=%s" % expected
		if room.width < float(Catalog.room(room.type).min_width) - 0.01:
			return "%s narrower than its minimum" % room.type
		expected = room.x + room.width
	if absf(expected - plan.width) > 0.01:
		return "rooms end at %s, building is %s wide" % [expected, plan.width]
	return ""
