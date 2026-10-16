extends SceneTree
## Balancing aid: runs one workday per company archetype with a stand-in
## player who fixes the most urgent ticket back to back (its effort plus
## WALK_MINUTES of walking each) and never asks PATCH. Prints tickets opened,
## fixed by hand and still open at the end of the day: a day where the last
## number is near zero needs no PATCH at all.
##   godot --headless --path . --script res://tools/day_report.gd
const Catalog = preload("res://scripts/core/catalog.gd")
const Job = preload("res://scripts/sim/job.gd")
const OfficeSim = preload("res://scripts/sim/office_sim.gd")

const SEEDS: Array[int] = [11, 22, 33]
const WALK_MINUTES: float = 10.0


func _init() -> void:
	Catalog.ensure_loaded()
	for id in Catalog.archetype_ids:
		var tickets: int = 0
		var fixed: int = 0
		var left: int = 0
		var staff: int = 0
		for seed_value in SEEDS:
			var office: RefCounted = OfficeSim.create(Job.create(id, seed_value))
			office.begin_day(1)
			var free_at: float = office.clock.stamp()
			while office.day_running:
				office.step(OfficeSim.TICK * 6.0)
				var open: Array = office.helpdesk.queue.by_urgency()
				if office.clock.stamp() >= free_at and not open.is_empty():
					free_at = office.clock.stamp() + office.helpdesk.fix_effort(open[0]) + WALK_MINUTES
					office.helpdesk.resolve(office, open[0], "player")
					fixed += 1
			staff += office.staff.size()
			tickets += office.helpdesk.queue.tickets.size()
			left += office.helpdesk.queue.open_count()
		var runs: float = float(SEEDS.size())
		print("%-18s staff %4.1f  opened %5.1f  fixed by hand %4.1f  open at day end %4.1f" % [
			id, staff / runs, tickets / runs, fixed / runs, left / runs])
	quit(0)
