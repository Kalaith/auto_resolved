extends RefCounted
## PATCH's side of one job: the conversation, the proposals it makes for a
## ticket, a recurring category or the queue, the automations it runs, the
## executions it has logged, the incidents it caused and the guardrails set
## here. Persistent knowledge lives in office.patch (PatchState). The office
## is passed in to every call, so there is no reference cycle.
const Catalog = preload("res://scripts/core/catalog.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const Proposal = preload("res://scripts/sim/proposal.gd")
const Automation = preload("res://scripts/sim/automation.gd")
const PatchExecutor = preload("res://scripts/sim/patch_executor.gd")
const PatchEffects = preload("res://scripts/sim/patch_effects.gd")

const CHAT_LIMIT: int = 40

var rng: RandomNumberGenerator
## [{"who": "patch" | "you", "text"}], oldest first.
var chat: Array[Dictionary] = []
var automations: Array = []
var incidents: Array = []
var audit: Array[Dictionary] = []
## Archetypes guarded at this job only (reset when the job ends).
var job_guardrails: Array[String] = []
## Archetypes PATCH caused for the first time ever during this job.
var first_archetypes: Array[String] = []
## Scheduled work: dry runs, delayed strikes, false successes coming to light.
var pending: Array[Dictionary] = []
## One-off actions the player let PATCH repeat on its own (Autonomy).
var repeat_actions: Array[String] = []
var incidents_today: int = 0
## Debug: "success" or "backfire" forces the next roll; a backfire id picks it.
var forced: String = ""
var forced_backfire: String = ""
var _repeat_tried: Dictionary = {}
var _next_execution: int = 1
var _next_incident: int = 1
var _next_automation: int = 1


func _init(job_seed: int) -> void:
	rng = Det.fork(job_seed, "patch_risk")


func next_execution_id() -> int:
	_next_execution += 1
	return _next_execution - 1


func next_incident_id() -> int:
	_next_incident += 1
	return _next_incident - 1


func say(text: String) -> void:
	_log("patch", text)


func you(text: String) -> void:
	_log("you", text)


func _log(who: String, text: String) -> void:
	chat.append({"who": who, "text": text})
	if chat.size() > CHAT_LIMIT:
		chat.pop_front()


func greet(office: RefCounted) -> void:
	var patch: RefCounted = office.patch
	if patch.jobs_done == 0:
		say(Catalog.say("patch.greet.first", {"version": patch.version()}))
	else:
		say(Catalog.say("patch.greet.again", {"version": patch.version(), "company": office.job.company_name}))
		if not patch.memories.is_empty():
			var memory: String = str(Det.pick(rng, patch.memories))
			say(Catalog.say("patch.greet.memory", {"memory": Catalog.say("backfire.%s.label" % memory)}))
	say(Catalog.say("patch.ready"))


func begin_day() -> void:
	incidents_today = 0


func guarded_archetypes(office: RefCounted) -> Array:
	var result: Array = job_guardrails.duplicate()
	for archetype in office.patch.guardrails:
		if not result.has(archetype):
			result.append(archetype)
	return result


func incident(id: int) -> RefCounted:
	for item in incidents:
		if item.id == id:
			return item
	return null


func active_incidents() -> Array:
	return incidents.filter(func(item: RefCounted) -> bool: return item.revealed and item.is_active())


## Recoveries this incident would offer with a backup or a reversible action.
func locked_recoveries(item: RefCounted) -> Array[String]:
	var offered: Array[String] = recoveries_for(item)
	var result: Array[String] = []
	for id in Catalog.backfire(item.backfire_id).recoveries:
		if not offered.has(str(id)):
			result.append(str(id))
	return result


func recovery_ids(item: RefCounted) -> Array[String]:
	return recoveries_for(item)


## The recoveries this incident offers, given its safeguards and action.
func recoveries_for(item: RefCounted) -> Array[String]:
	var result: Array[String] = []
	for id in Catalog.backfire(item.backfire_id).recoveries:
		var needs: String = str(Catalog.recoveries[id].requires)
		if needs == "backup" and not item.had_backup:
			continue
		if needs == "rollback" and not item.can_rollback:
			continue
		result.append(str(id))
	return result


## The IT desk, or the incident's site, depending on the recovery.
func recovery_places(office: RefCounted, item: RefCounted, recovery_id: String) -> Array[String]:
	var places: Array[String] = []
	var at_site: bool = Catalog.recoveries[recovery_id].at == "site"
	if at_site and not item.site_device.is_empty():
		places.append(item.site_device)
	if not at_site or office.patch.remote_session():
		for desk in office.devices_of("it_desk"):
			places.append(desk.id)
	return places


func recovery_label(recovery_id: String) -> String:
	return str(Catalog.recoveries[recovery_id].label)


func recovery_seconds(office: RefCounted, recovery_id: String) -> float:
	return float(Catalog.recoveries[recovery_id].seconds) * office.patch.recovery_scale()


func recover(office: RefCounted, item: RefCounted, recovery_id: String) -> bool:
	return PatchExecutor.recover(office, self, item, recovery_id)


func add_guardrail(archetype: String) -> void:
	if not job_guardrails.has(archetype):
		job_guardrails.append(archetype)
		say(Catalog.say("patch.guardrail", {"guardrail": Catalog.failure_archetypes[archetype].guardrail}))


## Device kinds an action works on, from its intents' issues.
func action_kinds(action_id: String) -> Array:
	var kinds: Array = []
	for intent in Catalog.action(action_id).intents:
		if Catalog.issues.has(intent):
			for kind in Catalog.issue(intent).devices:
				if not kinds.has(kind):
					kinds.append(kind)
	return kinds


## The devices a proposal reaches. `for_backfire` applies a staged rollout:
## a failure only reaches the first floor.
func scope_devices(office: RefCounted, proposal: RefCounted, for_backfire: bool = false) -> Array:
	if proposal.scope == "ticket":
		var target: RefCounted = target_device(office, proposal)
		if target == null:
			return []
		if target.kind == "network_core" or target.kind == "printer":
			var ticket: RefCounted = office.helpdesk.queue.get_ticket(proposal.ticket_id)
			var index: int = ticket.floor_index if ticket != null else target.floor_index
			return office.devices.filter(func(item: RefCounted) -> bool: return item.kind == "workstation" and item.floor_index == index)
		return [target]
	var kinds: Array = action_kinds(proposal.action_id)
	var staged: bool = for_backfire and proposal.safeguards.has("staged")
	var floor_only: bool = proposal.scope == "floor" or staged
	return office.devices.filter(func(item: RefCounted) -> bool:
		return kinds.has(item.kind) and (not floor_only or item.floor_index == proposal.floor_index))


func target_device(office: RefCounted, proposal: RefCounted) -> RefCounted:
	if proposal.ticket_id >= 0:
		var ticket: RefCounted = office.helpdesk.queue.get_ticket(proposal.ticket_id)
		if ticket != null:
			return office.device(ticket.device_id)
	var scope: Array = scope_devices(office, proposal) if proposal.scope != "ticket" else []
	return scope[0] if not scope.is_empty() else null


func target_floor(office: RefCounted, proposal: RefCounted) -> int:
	if proposal.ticket_id >= 0:
		var ticket: RefCounted = office.helpdesk.queue.get_ticket(proposal.ticket_id)
		if ticket != null:
			return PatchEffects.ticket_floor(office, ticket)
	return proposal.floor_index


## A one-off fix for `ticket`, or null with PATCH explaining why not.
func propose_ticket(office: RefCounted, ticket: RefCounted) -> RefCounted:
	you("Can you help with #%d, %s?" % [ticket.id, ticket.title.to_lower()])
	for id in Catalog.action_ids:
		var action: Dictionary = Catalog.action(id)
		if action.kind == "one_off" and action.intents.has(ticket.issue) and office.patch.can_propose(id):
			var proposal := Proposal.new()
			proposal.action_id = id
			proposal.scope = "ticket"
			proposal.ticket_id = ticket.id
			proposal.floor_index = PatchEffects.ticket_floor(office, ticket)
			return _offer(office, proposal)
	say(Catalog.say("patch.no_tickets"))
	return null


## An automation for a recurring issue, or null (PATCH names the upgrade).
func propose_category(office: RefCounted, issue: String) -> RefCounted:
	you("We keep getting %s tickets." % str(Catalog.issue(issue).label).to_lower())
	for id in Catalog.action_ids:
		var action: Dictionary = Catalog.action(id)
		if action.kind != "automation" or not action.intents.has(issue):
			continue
		if not office.patch.can_propose(id):
			say(Catalog.say("patch.no_blueprint", {"upgrade": Catalog.upgrade(str(action.requires)).label}))
			return null
		var proposal := Proposal.new()
		proposal.action_id = id
		proposal.scope = "floor" if action.scopes.has("floor") else "building"
		proposal.floor_index = _busiest_floor(office, issue)
		return _offer(office, proposal)
	say(Catalog.say("patch.no_categories"))
	return null


func propose_queue(office: RefCounted, action_id: String) -> RefCounted:
	you("Can you %s?" % str(Catalog.action(action_id).label).to_lower())
	var proposal := Proposal.new()
	proposal.action_id = action_id
	proposal.scope = "building"
	return _offer(office, proposal)


func _offer(office: RefCounted, proposal: RefCounted) -> RefCounted:
	proposal.refresh(office)
	say(Catalog.say("action.%s.propose" % proposal.action_id, {"target": proposal.target_text(office), "scope": proposal.scope_text(office)}))
	for entry in Catalog.pools[proposal.action().backfires]:
		if office.patch.memories.has(entry.id):
			say(Catalog.say("backfire.%s.callback" % entry.id))
			break
	return proposal


## The floor where `issue` has come up most this job (its tickets' floors).
func _busiest_floor(office: RefCounted, issue: String) -> int:
	var counts: Dictionary = {}
	for ticket in office.helpdesk.queue.tickets:
		if ticket.issue == issue:
			var index: int = PatchEffects.ticket_floor(office, ticket)
			counts[index] = int(counts.get(index, 0)) + 1
	var best: int = office.staffed_floors()[0] if not office.staffed_floors().is_empty() else 0
	for index in counts:
		if int(counts[index]) > int(counts.get(best, 0)):
			best = int(index)
	return best


## Issues raised at least twice this job that an automation could target.
func categories(office: RefCounted) -> Array[String]:
	var counts: Dictionary = {}
	for ticket in office.helpdesk.queue.tickets:
		counts[ticket.issue] = int(counts.get(ticket.issue, 0)) + 1
	var result: Array[String] = []
	for issue in Catalog.issue_ids:
		if int(counts.get(issue, 0)) >= 2:
			result.append(issue)
	return result


## A safer version of `proposal` and PATCH's line about it, or [null, line].
func alternative(office: RefCounted, proposal: RefCounted) -> Array:
	var safer: RefCounted = proposal.duplicate_proposal()
	var line: String = ""
	if safer.scope == "building" and safer.action().scopes.has("floor"):
		safer.scope = "floor"
		safer.floor_index = _busiest_floor(office, str(safer.action().intents[0]))
		line = Catalog.say("patch.alt.scope", {"scope": safer.scope_text(office)})
	elif safer.scope != "ticket" and not safer.safeguards.has("staged"):
		safer.safeguards.append("staged")
		if safer.scope == "building":
			safer.floor_index = _busiest_floor(office, str(safer.action().intents[0]))
		line = Catalog.say("patch.alt.staged")
	elif safer.scope == "ticket" and not safer.safeguards.has("dry_run"):
		safer.safeguards.append("dry_run")
		line = Catalog.say("patch.alt.dry_run")
	else:
		say(Catalog.say("patch.alt.none"))
		return [null, Catalog.say("patch.alt.none")]
	safer.refresh(office)
	you("Is there a safer way?")
	say(line)
	return [safer, line]


## The player approved. One-offs run (after a dry run's delay); automations
## are installed and first run on their cadence.
func approve(office: RefCounted, proposal: RefCounted, let_repeat: bool) -> void:
	you("Approved.")
	say(Catalog.say("patch.approved_staged" if proposal.safeguards.has("staged") else "patch.approved"))
	if proposal.is_automation():
		_install(office, proposal)
		return
	if let_repeat and office.patch.limited_autonomy() and not repeat_actions.has(proposal.action_id):
		repeat_actions.append(proposal.action_id)
	if proposal.safeguards.has("dry_run"):
		pending.append({"due": office.clock.stamp() + Balance.number("patch.dry_run_minutes"), "kind": "run", "proposal": proposal, "origin": "approved"})
		var ticket: RefCounted = office.helpdesk.queue.get_ticket(proposal.ticket_id)
		if ticket != null and ticket.status == "new":
			ticket.status = "triaged"
		return
	PatchExecutor.run(office, self, proposal, "approved")


func _install(office: RefCounted, proposal: RefCounted) -> void:
	var automation := Automation.new()
	automation.id = _next_automation
	_next_automation += 1
	automation.proposal = proposal
	automation.next_run = _first_run(office, proposal)
	automations.append(automation)
	office.emit("automation_installed", {"automation": automation.id, "action": proposal.action_id})


func _first_run(office: RefCounted, proposal: RefCounted) -> float:
	if proposal.action().cadence == "daily":
		return office.clock.stamp() + 5.0
	return office.clock.stamp() + 3.0


func _next_run(office: RefCounted, automation: RefCounted) -> float:
	if automation.proposal.action().cadence == "daily":
		return float(office.clock.day) * 1440.0 + Balance.number("patch.daily_run_minute")
	return automation.next_run + 60.0 * office.patch.cadence_scale()


func set_automation_enabled(automation: RefCounted, on: bool) -> void:
	automation.enabled = on
	automation.paused_by = "" if on else "player"
	say(Catalog.say("patch.automation_resumed" if on else "patch.automation_paused", {"name": automation.name()}))


func remove_automation(automation: RefCounted) -> void:
	automations.erase(automation)
	say(Catalog.say("patch.automation_removed", {"name": automation.name()}))


## Scheduled runs, dry runs coming due, delayed effects, and repeats.
func step(office: RefCounted) -> void:
	var now: float = office.clock.stamp()
	var due: Array[Dictionary] = []
	for item in pending:
		if item.kind == "run" and now >= float(item.due):
			due.append(item)
	for item in due:
		pending.erase(item)
		PatchExecutor.run(office, self, item.proposal, str(item.origin))
	PatchExecutor.step_pending(office, self)
	for automation in automations:
		if automation.enabled and now >= automation.next_run:
			_run_automation(office, automation)
	_repeat(office, now)


func _run_automation(office: RefCounted, automation: RefCounted) -> void:
	automation.next_run = _next_run(office, automation)
	automation.runs += 1
	office.metrics.count("automation_runs")
	var entry: Dictionary = PatchExecutor.run(office, self, automation.proposal, "automation")
	var day: int = office.clock.day
	if entry.outcome == "success" or entry.outcome == "near_miss":
		automation.successes += 1
		automation.clean_days[day] = int(automation.clean_days.get(day, 0)) + 1
	else:
		automation.failed_days[day] = true


func _repeat(office: RefCounted, now: float) -> void:
	if repeat_actions.is_empty() or not office.patch.limited_autonomy():
		return
	var delay: float = Balance.number("patch.repeat_delay_minutes")
	for ticket in office.helpdesk.queue.open_tickets():
		if _repeat_tried.has(ticket.id) or ticket.status == "in_progress" or now - ticket.created < delay:
			continue
		for id in repeat_actions:
			if Catalog.action(id).intents.has(ticket.issue):
				_repeat_tried[ticket.id] = true
				var proposal := Proposal.new()
				proposal.action_id = id
				proposal.ticket_id = ticket.id
				proposal.floor_index = PatchEffects.ticket_floor(office, ticket)
				PatchExecutor.run(office, self, proposal, "repeat")
				if not ticket.is_open():
					say(Catalog.say("patch.repeat", {"ticket": ticket.id}))
				break


## How much enabled automations cut `issue`'s rate on `device`.
func prevention(issue: String, device: RefCounted) -> float:
	var factor: float = 1.0
	for automation in automations:
		if not automation.enabled or not automation.covers_issue(issue) or not automation.covers_floor(device.floor_index):
			continue
		for effect in automation.proposal.action().success:
			if effect.do == "prevent":
				factor *= float(effect.factor)
	return factor


## The lift speed bonus from an enabled optimiser.
func lift_boost() -> float:
	var boost: float = 1.0
	for automation in automations:
		if automation.enabled:
			for effect in automation.proposal.action().success:
				if effect.do == "tune_elevator":
					boost = maxf(boost, float(effect.factor))
	return boost
