extends RefCounted
## What a backfire does to the building, per effect in backfires.json. Every
## effect stays inside the approved action's domain and scope (a staged
## rollout shrinks the scope to its first floor; the change cap limits how
## many devices one effect may touch) and records what it touched on the
## incident, so recovery undoes exactly that. Draws come from `rng`.
const Catalog = preload("res://scripts/core/catalog.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const PatchEffects = preload("res://scripts/sim/patch_effects.gd")


static func apply(office: RefCounted, incident: RefCounted, entry: Dictionary, proposal: RefCounted, rng: RandomNumberGenerator) -> void:
	var scope: Array = office.patch_desk.scope_devices(office, proposal, true)
	var cap: int = Balance.integer("patch.change_cap") if proposal.safeguards.has("change_cap") else 999
	for effect in entry.effects:
		match str(effect.do):
			"device_fault":
				for device in _devices(office, effect, proposal, scope, cap, rng):
					device.add_fault(str(effect.fault), float(effect.block), incident.source())
					_note_device(incident, device)
			"area_fault":
				var floors: Array[int] = _floors(office, str(effect.on), proposal, scope, rng)
				office.add_area_fault(incident.source(), str(effect.fault), float(effect.block), floors)
				for index in floors:
					if not incident.floors.has(index):
						incident.floors.append(index)
			"open_tickets":
				_open_tickets(office, incident, effect, proposal, scope, cap, rng)
			"delete_tickets":
				for ticket in office.helpdesk.queue.open_tickets():
					ticket.status = "deleted"
					incident.deleted_tickets.append(ticket.id)
			"false_close":
				_false_close(office, incident, str(effect.which), proposal)
			"confidence":
				office.metrics.add_confidence(float(effect.amount))
			"mood":
				var people: Array = _devices(office, effect, proposal, scope, cap, rng)
				for device in people:
					var person: RefCounted = office.employee(device.owner)
					if person != null:
						person.mood = clampf(person.mood + float(effect.amount), 0.0, 1.0)
			"lift_fault":
				var lift: RefCounted = office.device("lift")
				if lift != null:
					lift.add_fault("confused", 0.0, incident.source())
					incident.lift = true
					_note_device(incident, lift)


static func _note_device(incident: RefCounted, device: RefCounted) -> void:
	if not incident.devices.has(device.id):
		incident.devices.append(device.id)
	if incident.site_device.is_empty():
		incident.site_device = device.id


## The devices an effect lands on: the target, the whole scope, or a few at
## random from it; never more than the change cap.
static func _devices(office: RefCounted, effect: Dictionary, proposal: RefCounted, scope: Array, cap: int, rng: RandomNumberGenerator) -> Array:
	var chosen: Array = []
	match str(effect.get("on", "target")):
		"target":
			var target: RefCounted = office.patch_desk.target_device(office, proposal)
			if target != null:
				chosen.append(target)
		"random":
			var pool: Array = scope.duplicate()
			Det.shuffle(rng, pool)
			chosen = pool.slice(0, int(effect.count))
		_:
			chosen = scope.duplicate()
	return chosen.slice(0, cap)


static func _floors(office: RefCounted, on: String, proposal: RefCounted, scope: Array, rng: RandomNumberGenerator) -> Array[int]:
	var target: int = office.patch_desk.target_floor(office, proposal)
	var result: Array[int] = []
	match on:
		"target_floor", "target":
			result.append(target)
		"other_floor":
			var others: Array[int] = office.staffed_floors().filter(func(index: int) -> bool: return index != target)
			result.append(int(Det.pick(rng, others, target)))
		_:
			for device in scope:
				if not result.has(device.floor_index):
					result.append(device.floor_index)
			if result.is_empty():
				result.append(target)
	return result


static func _open_tickets(office: RefCounted, incident: RefCounted, effect: Dictionary, proposal: RefCounted, scope: Array, cap: int, rng: RandomNumberGenerator) -> void:
	var issue: Dictionary = Catalog.issue(str(effect.issue))
	var floors: Array[int] = _floors(office, str(effect.on), proposal, scope, rng)
	var target: RefCounted = office.patch_desk.target_device(office, proposal)
	var candidates: Array = []
	for device in office.devices:
		if not issue.devices.has(device.kind) or not floors.has(device.floor_index) or device == target:
			continue
		if not office.helpdesk.queue.open_for_device(device.id).is_empty():
			continue
		var owner: RefCounted = office.employee(device.owner)
		if device.kind == "workstation" and (owner == null or not owner.present):
			continue
		candidates.append(device)
	Det.shuffle(rng, candidates)
	for device in candidates.slice(0, mini(int(effect.count), cap)):
		var ticket: RefCounted = office.helpdesk.open_ticket(office, str(effect.issue), device)
		ticket.incident_id = incident.id
		incident.opened_tickets.append(ticket.id)
		_note_device(incident, device)


## Marks tickets resolved that are not: their faults stay, so people stay
## blocked while the queue looks clean.
static func _false_close(office: RefCounted, incident: RefCounted, which: String, proposal: RefCounted) -> void:
	for ticket in office.helpdesk.queue.open_tickets():
		if which == "intent" and not proposal.action().intents.has(ticket.issue):
			continue
		if which == "intent" and proposal.scope == "floor" and PatchEffects.ticket_floor(office, ticket) != proposal.floor_index:
			continue
		ticket.status = "resolved"
		ticket.resolved_by = "patch"
		ticket.resolved_at = office.clock.stamp()
		ticket.falsely_closed = true
		incident.closed_tickets.append(ticket.id)
