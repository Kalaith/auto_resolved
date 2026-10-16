extends RefCounted
## What a successful PATCH execution does, per success effect in
## actions.json. Prevention and lift tuning are passive while an automation is
## enabled (office.issue_factor, office lift sync); a run only resolves or
## tidies. Returns how many tickets the run resolved.
const Catalog = preload("res://scripts/core/catalog.gd")


static func apply(office: RefCounted, proposal: RefCounted, by: String) -> int:
	var resolved: int = 0
	for effect in proposal.action().success:
		match str(effect.do):
			"resolve_ticket":
				var ticket: RefCounted = office.helpdesk.queue.get_ticket(proposal.ticket_id)
				if ticket != null and ticket.is_open():
					office.helpdesk.resolve(office, ticket, by)
					resolved += 1
			"resolve_open":
				resolved += _resolve_in_scope(office, proposal, by)
			"triage_queue":
				for ticket in office.helpdesk.queue.open_tickets():
					if ticket.status == "new" or ticket.status == "reopened":
						ticket.status = "triaged"
						ticket.deadline += float(effect.minutes)
				office.metrics.add_confidence(1.0)
			"archive":
				office.metrics.add_confidence(1.0)
	return resolved


static func _resolve_in_scope(office: RefCounted, proposal: RefCounted, by: String) -> int:
	var count: int = 0
	for issue in proposal.action().intents:
		for ticket in office.helpdesk.queue.open_of_issue(str(issue)):
			if proposal.scope == "building" or ticket_floor(office, ticket) == proposal.floor_index:
				office.helpdesk.resolve(office, ticket, by)
				count += 1
	return count


static func ticket_floor(office: RefCounted, ticket: RefCounted) -> int:
	if ticket.issue == "network":
		return ticket.floor_index
	var device: RefCounted = office.device(ticket.device_id)
	return device.floor_index if device != null else ticket.floor_index
