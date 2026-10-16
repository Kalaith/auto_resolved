extends RefCounted
## Runs one PATCH execution (GDD 14.4): verify the approval and scope, roll
## the risk from the job's "patch_risk" stream, apply success or pick a
## backfire from the action's own pool, open an incident, and append the
## audit log with the roll. Delayed and false-success backfires schedule their
## reveal; recoveries undo exactly one incident. Stateless: the desk holds
## the state and passes itself in.
const Catalog = preload("res://scripts/core/catalog.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const Incident = preload("res://scripts/sim/incident.gd")
const PatchEffects = preload("res://scripts/sim/patch_effects.gd")
const BackfireEffects = preload("res://scripts/sim/backfire_effects.gd")


## `origin` is approved, automation or repeat. Returns the audit entry.
static func run(office: RefCounted, desk: RefCounted, proposal: RefCounted, origin: String) -> Dictionary:
	proposal.refresh(office)
	var now: float = office.clock.stamp()
	var roll: float = desk.rng.randf()
	var entry: Dictionary = {"id": desk.next_execution_id(), "action": proposal.action_id, "scope": proposal.scope_text(office),
		"origin": origin, "risk": proposal.raw_risk, "roll": roll, "at": now, "outcome": "success", "backfire": ""}
	office.metrics.count("executions")
	var failed: bool = roll < proposal.raw_risk
	if desk.forced == "success":
		failed = false
	elif desk.forced == "backfire":
		failed = true
	desk.forced = ""
	if not failed:
		var fixed: int = PatchEffects.apply(office, proposal, "patch" if origin != "automation" else "automation")
		entry.fixed = fixed
		desk.say(Catalog.say("action.%s.success" % proposal.action_id, {"target": proposal.target_text(office), "scope": proposal.scope_text(office)}))
	else:
		_backfire(office, desk, proposal, entry)
	desk.audit.append(entry)
	office.emit("patch_executed", {"execution": entry.id, "outcome": entry.outcome, "action": proposal.action_id})
	return entry


static func _backfire(office: RefCounted, desk: RefCounted, proposal: RefCounted, entry: Dictionary) -> void:
	var chosen: Dictionary = _choose(office, desk, proposal)
	entry.backfire = chosen.id
	var label: String = Catalog.say("backfire.%s.label" % chosen.id)
	if desk.guarded_archetypes(office).has(chosen.archetype) and desk.rng.randf() >= Balance.number("risk.guardrail"):
		entry.outcome = "near_miss"
		desk.say(Catalog.say("patch.near_miss", {"label": label, "guardrail": Catalog.failure_archetypes[chosen.archetype].guardrail}))
		return
	if desk.incidents_today >= Balance.integer("patch.cascade_cap_per_day"):
		entry.outcome = "near_miss"
		desk.say(Catalog.say("patch.near_miss_cap", {"label": label}))
		return
	entry.outcome = "backfire"
	desk.incidents_today += 1
	office.metrics.count("backfires")
	var incident: Incident = _incident(office, desk, proposal, chosen, entry)
	var delay: String = str(chosen.delay)
	if delay == "partial" or delay == "delayed" or delay == "false_success":
		PatchEffects.apply(office, proposal, "patch")
		desk.say(Catalog.say("action.%s.success" % proposal.action_id, {"target": proposal.target_text(office), "scope": proposal.scope_text(office)}))
	if delay == "delayed":
		desk.pending.append({"due": entry.at + float(chosen.delay_minutes), "kind": "strike", "incident": incident.id, "proposal": proposal.duplicate_proposal()})
		incident.note(entry.at, "execution", "PATCH reported success.")
		return
	BackfireEffects.apply(office, incident, chosen, proposal, desk.rng)
	if delay == "false_success":
		desk.pending.append({"due": entry.at + float(chosen.delay_minutes), "kind": "reveal", "incident": incident.id})
		incident.note(entry.at, "execution", "PATCH reported success.")
		return
	_reveal(office, desk, incident, false)


## A backfire from the action's pool, weighted by the archetypes PATCH has
## learned to avoid (Understanding upgrades).
static func _choose(office: RefCounted, desk: RefCounted, proposal: RefCounted) -> Dictionary:
	var pool: Array = Catalog.pools[proposal.action().backfires]
	if not desk.forced_backfire.is_empty():
		for candidate in pool:
			if candidate.id == desk.forced_backfire:
				desk.forced_backfire = ""
				return candidate
	var weights: Array = []
	for candidate in pool:
		weights.append(float(candidate.weight) * office.patch.archetype_scale(str(candidate.archetype)))
	var index: int = Det.weighted_index(desk.rng, weights)
	return pool[maxi(index, 0)]


static func _incident(office: RefCounted, desk: RefCounted, proposal: RefCounted, chosen: Dictionary, entry: Dictionary) -> Incident:
	var incident := Incident.new()
	incident.id = desk.next_incident_id()
	incident.execution_id = int(entry.id)
	incident.action_id = proposal.action_id
	incident.backfire_id = str(chosen.id)
	incident.archetype = str(chosen.archetype)
	incident.severity = int(chosen.severity)
	incident.created = float(entry.at)
	incident.had_backup = proposal.safeguards.has("backup")
	incident.can_rollback = bool(proposal.action().rollback)
	var target: RefCounted = desk.target_device(office, proposal)
	incident.site_device = target.id if target != null else ""
	var origin: String = {"approved": "You approved", "automation": "An automation ran", "repeat": "PATCH repeated"}.get(entry.origin, "PATCH ran")
	incident.note(float(entry.at), "request", "%s: %s." % [origin, proposal.action().label])
	incident.note(float(entry.at), "scope", "Scope: %s. Protections: %s" % [proposal.scope_text(office), proposal.protections_text()])
	incident.note(float(entry.at), "plan", "Risk was %d%%; the roll was %d%% (seed %d, execution %d)." % [
		roundi(proposal.raw_risk * 100.0), roundi(float(entry.roll) * 100.0), office.job.seed_value, int(entry.id)])
	desk.incidents.append(incident)
	return incident


## Due delayed effects strike; due false successes come to light.
static func step_pending(office: RefCounted, desk: RefCounted) -> void:
	var now: float = office.clock.stamp()
	var still: Array[Dictionary] = []
	for item in desk.pending:
		if now < float(item.due):
			still.append(item)
			continue
		var incident: Incident = desk.incident(int(item.incident))
		if incident == null:
			continue
		if item.kind == "strike":
			BackfireEffects.apply(office, incident, Catalog.backfire(incident.backfire_id), item.proposal, desk.rng)
		_reveal(office, desk, incident, true)
	desk.pending = still


static func _reveal(office: RefCounted, desk: RefCounted, incident: Incident, later: bool) -> void:
	var now: float = office.clock.stamp()
	incident.revealed = true
	var label: String = Catalog.say("backfire.%s.label" % incident.backfire_id)
	incident.note(now, "effect", "Observed: PATCH managed to %s." % label)
	office.metrics.count("incidents")
	office.metrics.add_confidence(-2.0 * float(incident.severity))
	var first: bool = office.patch.remember(incident.backfire_id, incident.archetype)
	if first:
		desk.first_archetypes.append(incident.archetype)
	desk.say(Catalog.say("patch.discovered", {"label": label}) if later else Catalog.say("backfire.%s.line" % incident.backfire_id))
	for automation in desk.automations:
		if automation.enabled and automation.proposal.action_id == incident.action_id:
			automation.enabled = false
			automation.paused_by = "incident"
			desk.say(Catalog.say("patch.automation_paused", {"name": automation.name()}))
	var people: Array[String] = _affected_people(office, incident)
	for id in people:
		office.employee(id).remember("incident:" + incident.archetype)
	office.emit("incident_opened", {"incident": incident.id, "backfire": incident.backfire_id, "first": first,
		"archetype": incident.archetype, "people": people})


## Who felt it: owners of touched devices, staff on touched floors, and the
## reporters of tickets PATCH deleted or closed.
static func _affected_people(office: RefCounted, incident: Incident) -> Array[String]:
	var result: Array[String] = []
	for id in incident.devices:
		var device: RefCounted = office.device(id)
		if device != null and not device.owner.is_empty() and not result.has(device.owner):
			result.append(device.owner)
	for person in office.staff:
		if incident.floors.has(person.desk_floor) and not result.has(person.id):
			result.append(person.id)
	for id in incident.deleted_tickets + incident.closed_tickets:
		var ticket: RefCounted = office.helpdesk.queue.get_ticket(id)
		if ticket != null and not ticket.reporter.is_empty() and not result.has(ticket.reporter):
			result.append(ticket.reporter)
	return result


## Applies a finished recovery to `incident`. False if it is not offered.
static func recover(office: RefCounted, desk: RefCounted, incident: Incident, recovery_id: String) -> bool:
	if incident == null or not incident.is_active() or not desk.recoveries_for(incident).has(recovery_id):
		return false
	var recovery: Dictionary = Catalog.recoveries[recovery_id]
	for step in recovery.does:
		match str(step):
			"clear_faults":
				office.clear_source(incident.source())
			"close_tickets":
				for id in incident.opened_tickets:
					var ticket: RefCounted = office.helpdesk.queue.get_ticket(id)
					if ticket != null and ticket.is_open():
						office.helpdesk.resolve(office, ticket, "player")
			"restore_tickets":
				_reopen(office, incident.deleted_tickets, "deleted")
			"reopen_tickets":
				_reopen(office, incident.closed_tickets, "resolved")
	office.metrics.add_confidence(float(recovery.confidence))
	incident.status = "recovered"
	incident.note(office.clock.stamp(), "recovery", "Recovered: %s." % recovery.label)
	office.metrics.count("recovered")
	desk.say(Catalog.say("recovery.%s.done" % recovery_id))
	office.emit("incident_recovered", {"incident": incident.id, "recovery": recovery_id})
	return true


static func _reopen(office: RefCounted, ids: Array[int], from_status: String) -> void:
	for id in ids:
		var ticket: RefCounted = office.helpdesk.queue.get_ticket(id)
		if ticket != null and ticket.status == from_status and (from_status == "deleted" or ticket.falsely_closed):
			ticket.status = "reopened"
			ticket.falsely_closed = false
			ticket.resolved_at = -1.0
			ticket.resolved_by = ""
