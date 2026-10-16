extends RefCounted
## The rules that end a job and score it, kept apart so they can be read in
## one place: management's warnings and dismissal at the end of a day, the
## reference grade, PATCH Points (section 7.2 of the guide), reputation and
## pay. Every number comes from balance.json under `career`.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const CompanyMetrics = preload("res://scripts/sim/company_metrics.gd")


## Judges the day that just ended: "ok", "warning", "final_warning" or
## "fired". Never fires on one bad day: it takes three bad evenings in a row
## without a recovery in between, and a good evening takes a warning back.
static func judge_day(office: RefCounted) -> String:
	var confidence: float = office.metrics.confidence
	if confidence < Balance.number("career.warning_confidence"):
		office.warnings += 1
	elif confidence >= Balance.number("career.recover_confidence") and office.warnings > 0:
		office.warnings -= 1
		return "forgiven"
	else:
		return "ok"
	match office.warnings:
		1:
			return "warning"
		2:
			return "final_warning"
	return "fired"


static func days_worked(office: RefCounted) -> int:
	return office.metrics.confidence_by_day.size()


static func pay(office: RefCounted) -> int:
	return days_worked(office) * int(office.job.pay_per_day)


## "A" .. "D" from the average confidence across the days worked; a firing
## is always a D.
static func grade(office: RefCounted, ended: String) -> String:
	if ended == "fired":
		return "D"
	var days: Array[float] = office.metrics.confidence_by_day
	var average: float = office.metrics.confidence
	if not days.is_empty():
		average = 0.0
		for value in days:
			average += value
		average /= float(days.size())
	if average >= Balance.number("career.grade_a"):
		return "A"
	if average >= Balance.number("career.grade_b"):
		return "B"
	if average >= Balance.number("career.grade_c"):
		return "C"
	return "D"


static func reputation_change(grade_letter: String, ended: String) -> int:
	if ended == "fired":
		return -Balance.integer("career.reputation_fired_loss")
	return Balance.integer("career.reputation." + grade_letter)


## [[label, points], ...] and the total, for the exit interview and the HUD.
## Quitting keeps everything; a firing keeps a share. Repeated identical
## disasters earn nothing: each backfire's recovery counts once per job.
static func points(office: RefCounted, ended: String) -> Dictionary:
	var items: Array = []
	items.append(["Tickets resolved", _ticket_points(office)])
	items.append(["Automations that ran clean all day", _automation_points(office)])
	items.append(["Incidents recovered", _recovery_points(office)])
	items.append(["New kinds of mistake discovered", float(office.patch_desk.first_archetypes.size()) * Balance.number("career.points_first_archetype")])
	var milestones: Array = _milestones(office)
	items.append(["Days with nothing overdue", float(milestones[0]) * Balance.number("career.points_clean_day")])
	items.append(["Days PATCH did most of the work", float(milestones[1]) * Balance.number("career.points_coverage_day")])
	var total: float = 0.0
	for item in items:
		total += float(item[1])
	if ended == "fired":
		total = maxf(total * Balance.number("career.fired_keep"), Balance.number("career.fired_minimum_points"))
	elif ended == "quit" and days_worked(office) >= 1:
		total = maxf(total, Balance.number("career.quit_minimum_points"))
	elif days_worked(office) < 1:
		total = 0.0
	return {"items": items, "total": roundi(total)}


static func _ticket_points(office: RefCounted) -> float:
	var groups: Dictionary = {}
	for ticket in office.helpdesk.queue.tickets:
		if ticket.status != "resolved" or ticket.falsely_closed:
			continue
		var key: String = "%d|%s" % [int(ticket.resolved_at / 1440.0), ticket.issue]
		groups[key] = int(groups.get(key, 0)) + 1
	var full: int = Balance.integer("career.points_ticket_full_per_issue_day")
	var total: float = 0.0
	for key in groups:
		var count: int = int(groups[key])
		total += float(mini(count, full)) * Balance.number("career.points_ticket")
		total += float(maxi(count - full, 0)) * Balance.number("career.points_ticket_extra")
	return total


static func _automation_points(office: RefCounted) -> float:
	var total: float = 0.0
	for automation in office.patch_desk.automations:
		for day in automation.clean_days:
			if int(automation.clean_days[day]) >= 2 and not automation.failed_days.has(day):
				total += Balance.number("career.points_automation_day")
	return total


static func _recovery_points(office: RefCounted) -> float:
	var seen: Dictionary = {}
	for incident in office.patch_desk.incidents:
		if incident.status == "recovered":
			seen[incident.backfire_id] = true
	return float(seen.size()) * Balance.number("career.points_recovery")


## [clean days, coverage days] over finished days.
static func _milestones(office: RefCounted) -> Array:
	var clean: int = 0
	var covered: int = 0
	for summary in office.day_summaries:
		if float(summary.overdue_minutes) <= 0.0 and int(summary.resolved) >= Balance.integer("career.clean_day_min_resolved"):
			clean += 1
		var resolved: int = int(summary.resolved)
		if resolved >= Balance.integer("career.coverage_min_resolved") \
				and float(summary.by_patch) / float(resolved) > Balance.number("career.coverage_share"):
			covered += 1
	return [clean, covered]


## The headline numbers of a job, for the exit interview and the career log.
static func summary(office: RefCounted) -> Dictionary:
	var tally: Dictionary = office.metrics.job
	var catastrophes: int = 0
	for incident in office.patch_desk.incidents:
		if incident.revealed and incident.severity >= 3:
			catastrophes += 1
	return {
		"days": days_worked(office), "people": tally.people.size(), "resolved": int(tally.resolved),
		"by_patch": int(tally.by_patch), "uptime": CompanyMetrics.average_productivity(tally),
		"automations": office.patch_desk.automations.size(), "incidents": int(tally.incidents),
		"recovered": int(tally.recovered), "catastrophes": catastrophes, "pay": pay(office),
	}
