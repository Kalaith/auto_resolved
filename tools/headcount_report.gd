extends SceneTree
## Balancing aid: staff, desks and floors per company archetype over many
## seeds, to compare with the tier table in docs/IMPLEMENTATION_GUIDE.md 7.1.
##   godot --headless --path . --script res://tools/headcount_report.gd
const Catalog = preload("res://scripts/core/catalog.gd")
const Job = preload("res://scripts/sim/job.gd")
const BuildingPlan = preload("res://scripts/sim/building_plan.gd")
const StaffFactory = preload("res://scripts/sim/staff_factory.gd")

const SEEDS: int = 40


func _init() -> void:
	Catalog.ensure_loaded()
	for id in Catalog.archetype_ids:
		var low: int = 1 << 30
		var high: int = 0
		var total: int = 0
		for seed_value in range(1, SEEDS + 1):
			var job: RefCounted = Job.create(id, seed_value)
			var count: int = StaffFactory.create(job, BuildingPlan.generate(job)).size()
			low = mini(low, count)
			high = maxi(high, count)
			total += count
		print("%-18s tier %d  staff %d-%d (mean %.1f)" % [id, int(Catalog.archetype(id).tier), low, high, float(total) / SEEDS])
	quit(0)
