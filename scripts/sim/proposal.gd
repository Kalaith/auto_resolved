extends RefCounted
## One PATCH proposal: an action, what it is aimed at and the protections
## switched on, plus the five answers the card shows (GDD 13): what PATCH will
## do, who is affected, the benefit, what could go wrong, and the protections.
const Catalog = preload("res://scripts/core/catalog.gd")
const Risk = preload("res://scripts/sim/risk.gd")
const BuildingPlan = preload("res://scripts/sim/building_plan.gd")

var action_id: String = ""
## ticket, floor or building
var scope: String = "ticket"
## The floor a floor-scoped action covers (and a staged rollout starts on).
var floor_index: int = 0
## The ticket a one-off fixes (-1 for queue actions and automations).
var ticket_id: int = -1
var safeguards: Array[String] = []
## The chance shown on the card, and the chance the roll actually uses.
var shown_risk: float = 0.0
var raw_risk: float = 0.0


func action() -> Dictionary:
	return Catalog.action(action_id)


func is_automation() -> bool:
	return action().kind == "automation"


func refresh(office: RefCounted) -> void:
	raw_risk = Risk.raw(action_id, scope, safeguards, office.patch, office.job.tier)
	shown_risk = Risk.shown(action_id, scope, safeguards, office.patch, office.job.tier, office.patch_desk.guarded_archetypes(office))


func duplicate_proposal() -> RefCounted:
	var copy: RefCounted = load("res://scripts/sim/proposal.gd").new()
	copy.action_id = action_id
	copy.scope = scope
	copy.floor_index = floor_index
	copy.ticket_id = ticket_id
	copy.safeguards = safeguards.duplicate()
	return copy


## "Floor 2 (6 PCs)", "Edie Archer's PC", "the whole building (24 PCs)".
func target_text(office: RefCounted) -> String:
	if scope == "ticket":
		var ticket: RefCounted = office.helpdesk.queue.get_ticket(ticket_id)
		if ticket == null:
			return "the ticket"
		var person: RefCounted = office.employee(ticket.reporter)
		if person != null:
			return person.name
		if ticket.issue == "network":
			return "floor " + BuildingPlan.floor_name(ticket.floor_index)
		return "floor " + BuildingPlan.floor_name(office.device(ticket.device_id).floor_index)
	return scope_text(office)


func scope_text(office: RefCounted) -> String:
	if action().intents.has("queue"):
		return "every ticket in the queue (%d open)" % office.helpdesk.queue.open_count()
	var count: int = office.patch_desk.scope_devices(office, self).size()
	var noun: String = _device_noun()
	if scope == "floor":
		return "floor %s (%d %s)" % [BuildingPlan.floor_name(floor_index), count, noun]
	if scope == "building":
		return "the whole building (%d %s)" % [count, noun]
	return target_text(office)


func _device_noun() -> String:
	var kinds: Array = []
	for intent in action().intents:
		if Catalog.issues.has(intent):
			for kind in Catalog.issue(intent).devices:
				if not kinds.has(kind):
					kinds.append(kind)
	if kinds.has("workstation"):
		return "PCs"
	if kinds.has("printer"):
		return "printers"
	return "systems"


## The five card answers, in order, as {heading: text}.
func card(office: RefCounted) -> Array:
	var what: String = Catalog.say("action.%s.propose" % action_id, {"target": target_text(office), "scope": scope_text(office)})
	var who: String = scope_text(office)
	if is_automation():
		who += ", every %s" % ("morning" if action().cadence == "daily" else _hourly_text(office))
	var benefit: String = Catalog.say("action.%s.benefit" % action_id)
	var could: Array[String] = []
	for entry in Catalog.pools[action().backfires]:
		could.append(Catalog.say("backfire.%s.label" % entry.id))
	var wrong: String = "Risk %s per run. It could %s." % [Risk.band(shown_risk, office.patch.precise_risk()), " or ".join(could)]
	return [["What PATCH will do", what], ["Who is affected", who], ["Expected benefit", benefit],
		["What could go wrong", wrong], ["Protections", protections_text()]]


func _hourly_text(office: RefCounted) -> String:
	return "half hour" if office.patch.cadence_scale() < 0.75 else "hour"


func protections_text() -> String:
	var names: Array[String] = []
	for safeguard in safeguards:
		names.append({"staged": "staged rollout", "dry_run": "dry run first", "backup": "backup first",
			"confirm_delete": "confirm deletes", "change_cap": "change cap"}.get(safeguard, safeguard))
	var rollback: String = "Can be rolled back." if action().rollback else "No rollback for this one."
	return ("None switched on. " if names.is_empty() else ", ".join(names).capitalize() + ". ") + rollback
