extends RefCounted
## The words on the end-of-day card, from the office's tallies for the day.
const CompanyMetrics = preload("res://scripts/sim/company_metrics.gd")


static func body(office: RefCounted) -> String:
	var tally: Dictionary = office.metrics.day
	var lines: Array[String] = []
	lines.append("Tickets: %d opened, %d resolved (%d by you, %d by PATCH), %d still open." % [
		int(tally.opened), int(tally.resolved), int(tally.by_player), int(tally.by_patch), office.helpdesk.queue.open_count()])
	lines.append("People helped: %d.   Staff productivity: %d%%." % [tally.people.size(), roundi(CompanyMetrics.average_productivity(tally) * 100.0)])
	if float(tally.overdue_minutes) > 0.0:
		lines.append("Tickets spent %d minutes past their deadlines in total." % int(tally.overdue_minutes))
	lines.append("Management confidence: %d / 100." % roundi(office.metrics.confidence))
	return "\n".join(lines)
