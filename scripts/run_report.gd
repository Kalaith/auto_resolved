extends RefCounted
## The run reports sent to Hatchery Signals (the toolkit's
## telemetry/signals_client.gd). Each job is a run: what it started with and
## how it ended, as catalogue ids, counts and flags only (the portal rejects
## free text, so company names never go out). Pure: same career and office,
## same report.
const Catalog = preload("res://scripts/core/catalog.gd")
const CareerRules = preload("res://scripts/sim/career_rules.gd")


## Sent when a job begins from the job board (not when a saved day continues).
static func started(career: RefCounted, office: RefCounted) -> Dictionary:
	var report: Dictionary = _career_part(career)
	report["company"] = str(office.job.archetype_id)
	report["tier"] = int(office.job.tier)
	report["floors"] = int(office.plan.highest - office.plan.lowest + 1)
	report["staff"] = int(office.staff.size())
	return report


## Sent when the job ends at the exit interview: `outcome` is "quit" or
## "fired". Call before the career records the job. `seconds` is the run's
## active play time.
static func ended(career: RefCounted, office: RefCounted, outcome: String, seconds: int) -> Dictionary:
	var report: Dictionary = started(career, office)
	var tally: Dictionary = office.metrics.job
	report["outcome"] = outcome
	report["seconds"] = maxi(seconds, 0)
	report["days"] = CareerRules.days_worked(office)
	report["issues_opened"] = int(tally.opened)
	report["issues_fixed"] = int(tally.resolved)
	report["fixed_by_hand"] = int(tally.by_player)
	report["fixed_by_patch"] = int(tally.by_patch)
	report["issues_missed"] = int(office.helpdesk.queue.open_count())
	report["executions"] = int(tally.executions)
	report["backfires"] = int(tally.backfires)
	report["incidents"] = int(tally.incidents)
	report["recovered"] = int(tally.recovered)
	report["automations"] = int(office.patch_desk.automations.size())
	report["confidence"] = roundi(float(office.metrics.confidence))
	report["warnings"] = int(office.warnings)
	report["grade"] = CareerRules.grade(office, outcome).to_lower()
	report["points"] = int(CareerRules.points(office, outcome).total)
	report["pay"] = CareerRules.pay(office)
	return report


## Sent when a new career replaces a saved one that was part-way through a
## job: only what the save holds, since that office was never built.
static func abandoned(career: RefCounted, seconds: int) -> Dictionary:
	var report: Dictionary = _career_part(career)
	var archetype: String = str(career.current_job.get("archetype", ""))
	report["outcome"] = "abandoned"
	report["seconds"] = maxi(seconds, 0)
	report["company"] = archetype
	report["tier"] = int(Catalog.archetype(archetype).tier) if Catalog.archetype_ids.has(archetype) else 0
	report["days"] = int(career.current_job.get("day", 0))
	return report


## What carries between jobs: PATCH's upgrades and the career so far.
static func _career_part(career: RefCounted) -> Dictionary:
	return {
		"job_number": career.history.size() + 1,
		"patch_upgrades": upgrade_levels(career.patch), "patch_version": career.patch.upgrades.size(),
		"guardrails": career.patch.guardrails.size(), "reputation": int(career.reputation),
	}


## {upgrade id: level} for every PATCH upgrade: 1 when bought, else 0.
static func upgrade_levels(patch: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	for id in Catalog.upgrade_ids:
		result[str(id)] = 1 if patch.has(str(id)) else 0
	return result
