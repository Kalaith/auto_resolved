extends RefCounted
## The office at the end of a workday as plain data, for the career save:
## management's mood, the tallies, tickets, incidents, the faults they left,
## automations, guardrails and the staff's names and moods. The building and
## staff are regenerated from archetype and seed, so they are never saved;
## this only lays the day's leftovers back over them.
const Ticket = preload("res://scripts/sim/ticket.gd")
const Incident = preload("res://scripts/sim/incident.gd")
const Automation = preload("res://scripts/sim/automation.gd")
const Proposal = preload("res://scripts/sim/proposal.gd")

const INT_LISTS: Array[String] = ["opened_tickets", "deleted_tickets", "closed_tickets", "floors"]


static func capture(office: RefCounted) -> Dictionary:
	var desk: RefCounted = office.patch_desk
	var tickets: Array = office.helpdesk.queue.tickets.map(func(ticket: Ticket) -> Dictionary: return ticket.to_dict())
	var incidents: Array = desk.incidents.map(func(item: Incident) -> Dictionary: return _incident(item))
	var faults: Dictionary = {}
	for device in office.devices:
		if not device.faults.is_empty():
			faults[device.id] = device.faults.duplicate(true)
	var staff: Dictionary = {}
	for person in office.staff:
		staff[person.id] = {"name": person.name, "mood": person.mood, "history": person.history.duplicate()}
	return {
		"confidence": office.metrics.confidence, "warnings": office.warnings, "summoned": office.summoned,
		"notice": office.notice_given, "job": office.metrics.job.duplicate(true),
		"confidence_by_day": office.metrics.confidence_by_day.duplicate(), "days": office.day_summaries.duplicate(true),
		"tickets": tickets, "incidents": incidents, "faults": faults, "areas": office.area_faults.duplicate(true),
		"automations": desk.automations.map(func(item: Automation) -> Dictionary: return _automation(item)),
		"guardrails": desk.job_guardrails.duplicate(), "repeat": desk.repeat_actions.duplicate(),
		"first": desk.first_archetypes.duplicate(), "staff": staff,
	}


static func _incident(item: Incident) -> Dictionary:
	var data: Dictionary = item.to_dict()
	for key in INT_LISTS:
		data[key] = item.get(key).duplicate()
	data.devices = item.devices.duplicate()
	data.lift = item.lift
	data.had_backup = item.had_backup
	data.can_rollback = item.can_rollback
	data.site = item.site_device
	return data


static func _automation(item: Automation) -> Dictionary:
	var proposal: RefCounted = item.proposal
	return {
		"action": proposal.action_id, "scope": proposal.scope, "floor": proposal.floor_index,
		"safeguards": proposal.safeguards.duplicate(), "enabled": item.enabled, "paused_by": item.paused_by,
		"runs": item.runs, "successes": item.successes, "clean": item.clean_days.duplicate(), "failed": item.failed_days.duplicate(),
	}


## Lays a captured day back over a freshly generated office of the same job.
static func restore(office: RefCounted, state: Dictionary) -> void:
	office.metrics.confidence = float(state.confidence)
	office.warnings = int(state.warnings)
	office.summoned = str(state.summoned)
	office.notice_given = bool(state.notice)
	office.metrics.job = state.job.duplicate(true)
	for value in state.confidence_by_day:
		office.metrics.confidence_by_day.append(float(value))
	for summary in state.days:
		office.day_summaries.append(summary)
	_restore_staff(office, state.staff)
	_restore_tickets(office, state.tickets)
	for id in state.faults:
		var device: RefCounted = office.device(str(id))
		if device != null:
			device.faults = state.faults[id].duplicate(true)
	for source in state.areas:
		var area: Dictionary = state.areas[source]
		var floors: Array[int] = []
		for value in area.floors:
			floors.append(int(value))
		office.add_area_fault(str(source), str(area.fault), float(area.block), floors)
	var desk: RefCounted = office.patch_desk
	for data in state.incidents:
		desk.incidents.append(_restore_incident(data))
	for data in state.automations:
		desk.restore_automation(_restore_automation(data))
	for key in ["guardrails", "repeat", "first"]:
		var target: Array[String] = {"guardrails": desk.job_guardrails, "repeat": desk.repeat_actions, "first": desk.first_archetypes}[key]
		for value in state[key]:
			target.append(str(value))
	desk.sync_ids()


static func _restore_staff(office: RefCounted, staff: Dictionary) -> void:
	for id in staff:
		var person: RefCounted = office.employee(str(id))
		if person == null:
			continue
		person.name = str(staff[id].name)
		person.mood = float(staff[id].mood)
		for note in staff[id].history:
			person.history.append(str(note))


static func _restore_tickets(office: RefCounted, tickets: Array) -> void:
	for data in tickets:
		var ticket := Ticket.new()
		ticket.issue = str(data.issue)
		ticket.title = str(data.title)
		ticket.device_id = str(data.device)
		ticket.reporter = str(data.reporter)
		ticket.floor_index = int(data.floor)
		ticket.status = str(data.status)
		ticket.severity = int(data.severity)
		ticket.created = float(data.created)
		ticket.deadline = float(data.deadline)
		ticket.resolved_at = float(data.resolved_at)
		ticket.resolved_by = str(data.resolved_by)
		ticket.falsely_closed = bool(data.falsely_closed)
		ticket.incident_id = int(data.incident)
		office.helpdesk.queue.restore(ticket, int(data.id))


static func _restore_incident(data: Dictionary) -> Incident:
	var item := Incident.new()
	item.id = int(data.id)
	item.execution_id = int(data.execution)
	item.action_id = str(data.action)
	item.backfire_id = str(data.backfire)
	item.archetype = str(data.archetype)
	item.severity = int(data.severity)
	item.created = float(data.created)
	item.revealed = true
	item.status = str(data.status)
	for step in data.timeline:
		item.timeline.append(step)
	for key in INT_LISTS:
		var target: Array[int] = item.get(key)
		for value in data[key]:
			target.append(int(value))
	for value in data.devices:
		item.devices.append(str(value))
	item.lift = bool(data.lift)
	item.had_backup = bool(data.had_backup)
	item.can_rollback = bool(data.can_rollback)
	item.site_device = str(data.site)
	return item


static func _restore_automation(data: Dictionary) -> Automation:
	var proposal := Proposal.new()
	proposal.action_id = str(data.action)
	proposal.scope = str(data.scope)
	proposal.floor_index = int(data.floor)
	for value in data.safeguards:
		proposal.safeguards.append(str(value))
	var item := Automation.new()
	item.proposal = proposal
	item.enabled = bool(data.enabled)
	item.paused_by = str(data.paused_by)
	item.runs = int(data.runs)
	item.successes = int(data.successes)
	for day in data.clean:
		item.clean_days[int(day)] = int(data.clean[day])
	for day in data.failed:
		item.failed_days[int(day)] = true
	return item


## A light shape check, so a hand-edited save cannot crash a restore.
static func valid(state: Dictionary) -> bool:
	if state.is_empty():
		return true
	for key in ["tickets", "incidents", "automations", "guardrails", "repeat", "first", "confidence_by_day", "days"]:
		if not state.get(key) is Array:
			return false
	for key in ["job", "faults", "areas", "staff"]:
		if not state.get(key) is Dictionary:
			return false
	return state.get("confidence") is float or state.get("confidence") is int
