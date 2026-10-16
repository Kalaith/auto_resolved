extends RefCounted
## The next positions on offer: three jobs from the career's
## "offers_<n>" stream. At least one at the highest tier reputation opens, one
## a tier below when there is one (a safe step), and a lateral pick from any
## open tier. Each offer names the company, its pay, its size and what is new
## there compared with jobs already done.
const Catalog = preload("res://scripts/core/catalog.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const Job = preload("res://scripts/sim/job.gd")
const BuildingPlan = preload("res://scripts/sim/building_plan.gd")
const StaffFactory = preload("res://scripts/sim/staff_factory.gd")

const OFFERS: int = 3


static func first_archetype() -> String:
	for id in Catalog.archetype_ids:
		if int(Catalog.archetype(id).tier) == 1:
			return id
	return Catalog.archetype_ids[0]


static func first_seed(career_seed: int) -> int:
	return Det.fork(career_seed, "first_job").randi_range(1, 2147483646)


static func offers(career: RefCounted) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = Det.fork(career.career_seed, "offers_%d" % career.history.size())
	var top: int = career.max_tier()
	var picks: Array[String] = []
	picks.append(_pick(rng, func(tier: int) -> bool: return tier == top, picks))
	picks.append(_pick(rng, func(tier: int) -> bool: return tier == maxi(top - 1, 1), picks))
	picks.append(_pick(rng, func(tier: int) -> bool: return tier <= top, picks))
	var result: Array[Dictionary] = []
	for id in picks:
		if not id.is_empty():
			result.append(describe(id, rng.randi_range(1, 2147483646), career))
	return result


## An archetype whose tier passes `allowed`, preferring ones not already
## picked or recently worked; "" only if the catalog has none at all.
static func _pick(rng: RandomNumberGenerator, allowed: Callable, taken: Array[String]) -> String:
	var fits: Array = Catalog.archetype_ids.filter(func(id: String) -> bool: return allowed.call(int(Catalog.archetype(id).tier)))
	var fresh: Array = fits.filter(func(id: String) -> bool: return not taken.has(id))
	if not fresh.is_empty():
		return str(Det.pick(rng, fresh))
	if not fits.is_empty():
		return str(Det.pick(rng, fits))
	return str(Det.pick(rng, Catalog.archetype_ids, ""))


static func describe(archetype: String, job_seed: int, career: RefCounted) -> Dictionary:
	var job: RefCounted = Job.create(archetype, job_seed)
	var plan: RefCounted = BuildingPlan.generate(job)
	var headcount: int = StaffFactory.create(job, plan).size()
	return {
		"archetype": archetype, "seed": job_seed, "name": job.company_name, "label": job.label(), "tier": job.tier,
		"pay": job.pay_per_day, "floors": plan.highest + 1, "basement": plan.lowest < 0, "staff": headcount,
		"hint": _hint(job.tier, career),
	}


## What is new at this tier compared with the jobs done so far.
static func _hint(tier: int, career: RefCounted) -> String:
	var worked: int = 0
	for record in career.history:
		worked = maxi(worked, int(record.get("tier", 1)))
	var fresh: Array[String] = []
	for id in Catalog.issue_ids:
		var needs: int = int(Catalog.issue(id).min_tier)
		if needs <= tier and needs > worked:
			fresh.append(str(Catalog.issue(id).label).to_lower())
	if fresh.is_empty():
		return "Familiar problems, more of them." if tier >= worked else "A quieter office. Fewer people, smaller pay."
	return "New here: " + ", ".join(fresh) + "."
