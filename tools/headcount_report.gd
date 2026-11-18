extends SceneTree
## Balancing aid: staff, desks and floors per company archetype over many
## seeds, to compare with the tier table in docs/IMPLEMENTATION_GUIDE.md 7.1.
## The smallest and largest roll of each archetype are then played from the
## morning to the end of lunch: the longest lift queue on one floor, the
## longest any one person waited at a landing, how many were still not at
## their desk at LATE_MINUTE, and how many floors above ground have no desk.
##   godot --headless --path . --script res://tools/headcount_report.gd -- [--staff-only]
const Catalog = preload("res://scripts/core/catalog.gd")
const Job = preload("res://scripts/sim/job.gd")
const BuildingPlan = preload("res://scripts/sim/building_plan.gd")
const StaffFactory = preload("res://scripts/sim/staff_factory.gd")
const OfficeSim = preload("res://scripts/sim/office_sim.gd")

const SEEDS: int = 40
## The last arrival is at 560; a quarter of an hour on, everyone should be seated.
const LATE_MINUTE: float = 575.0
const PLAY_UNTIL: float = 800.0


func _init() -> void:
	Catalog.ensure_loaded()
	var staff_only: bool = OS.get_cmdline_user_args().has("--staff-only")
	for id in Catalog.archetype_ids:
		var low: int = 1 << 30
		var high: int = 0
		var low_seed: int = 0
		var high_seed: int = 0
		var total: int = 0
		for seed_value in range(1, SEEDS + 1):
			var job: RefCounted = Job.create(id, seed_value)
			var count: int = StaffFactory.create(job, BuildingPlan.generate(job)).size()
			if count < low:
				low = count
				low_seed = seed_value
			if count > high:
				high = count
				high_seed = seed_value
			total += count
		if staff_only:
			print("%-18s tier %d  staff %d-%d (mean %.1f)" % [id, int(Catalog.archetype(id).tier), low, high, float(total) / SEEDS])
			continue
		print("%-18s tier %d  staff %d-%d (mean %.1f)  smallest seed %d: %s  largest seed %d: %s" % [
			id, int(Catalog.archetype(id).tier), low, high, float(total) / SEEDS,
			low_seed, _morning(id, low_seed), high_seed, _morning(id, high_seed)])
	quit(0)


## "<floors>f <desk-less floors> bare, queue <n>, wait <s>s, late <n>"
func _morning(id: String, seed_value: int) -> String:
	var office: RefCounted = OfficeSim.create(Job.create(id, seed_value))
	var plan: RefCounted = office.plan
	# A basement holding only servers and IT is meant to; above ground, a
	# floor without a single desk reads as empty.
	var bare: int = 0
	for index in plan.floor_indices():
		if index >= 0 and office.staff.filter(func(person: RefCounted) -> bool: return person.desk_floor == index).is_empty():
			bare += 1
	office.begin_day(1)
	var queue: int = 0
	var longest: float = 0.0
	var waited: Dictionary = {}
	var late: int = 0
	var counted_late: bool = false
	while office.day_running and office.clock.minute < PLAY_UNTIL:
		office.step(OfficeSim.TICK)
		var by_floor: Dictionary = {}
		for person in office.staff:
			if person.present and person.walker.waiting:
				by_floor[person.walker.floor_index] = int(by_floor.get(person.walker.floor_index, 0)) + 1
				waited[person.id] = float(waited.get(person.id, 0.0)) + OfficeSim.TICK
				longest = maxf(longest, waited[person.id])
			else:
				waited.erase(person.id)
		for index in by_floor:
			queue = maxi(queue, int(by_floor[index]))
		if not counted_late and office.clock.minute >= LATE_MINUTE:
			counted_late = true
			for person in office.staff:
				if person.activity == "arriving" or person.activity == "home":
					late += 1
	return "%d staff %df %d bare, queue %d, wait %ds, late %d" % [office.staff.size(), plan.floor_indices().size(), bare, queue, roundi(longest), late]
