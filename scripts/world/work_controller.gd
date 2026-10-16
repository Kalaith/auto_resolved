extends Node
## The player's hands. A task is either a ticket fix or an incident recovery;
## each can be done at certain devices (the broken one, or the IT desk). This
## sends the player to the nearest such place, starts the task on arrival (or
## when interact is pressed beside a broken device), and counts its seconds
## while they stay. Walking off abandons it. Task time is real time: it does
## not depend on the office clock or speed. The sim only hears "started" and
## "done here".
signal message(text: String)

var office: RefCounted
var player: Node2D
var device_view: Node2D
## The task in hand: {"kind": "ticket"|"recovery", "ticket", "incident",
## "recovery", "device", "seconds"}; empty when idle.
var task: Dictionary = {}
var progress: float = 0.0
## A task the player is walking to; it starts on arrival.
var _pending: Dictionary = {}
var _reach: float = 52.0


func setup(sim: RefCounted, walker_node: Node2D, view: Node2D) -> void:
	office = sim
	player = walker_node
	device_view = view
	task = {}
	_pending = {}
	progress = 0.0


## Routes the player to the nearest fix place for `ticket_id`.
func request(ticket_id: int) -> void:
	var ticket: RefCounted = office.helpdesk.queue.get_ticket(ticket_id)
	if ticket == null or not ticket.is_open():
		return
	_go({"kind": "ticket", "ticket": ticket, "seconds": office.helpdesk.fix_seconds(ticket)},
		office.helpdesk.fix_places(office, ticket))


## Routes the player to where `recovery_id` for `incident` is done.
func request_recovery(incident: RefCounted, recovery_id: String) -> void:
	if incident == null or not incident.is_active():
		return
	var places: Array[String] = office.patch_desk.recovery_places(office, incident, recovery_id)
	_go({"kind": "recovery", "incident": incident, "recovery": recovery_id,
		"seconds": office.patch_desk.recovery_seconds(office, recovery_id)}, places)
	message.emit("Recovery: %s" % office.patch_desk.recovery_label(recovery_id))


func _go(wanted: Dictionary, places: Array[String]) -> void:
	var place: RefCounted = _nearest(places)
	if place == null:
		return
	_cancel()
	wanted.device = place.id
	if _is_beside(place):
		_start(wanted)
	else:
		_pending = wanted
		player.go_to(place.floor_index, stand_x(place))


## Interact pressed with nothing else to do: fix something here if possible.
## True when it started a task.
func interact_here() -> bool:
	for place in office.devices:
		if not _is_beside(place):
			continue
		for candidate in office.helpdesk.queue.by_urgency():
			if office.helpdesk.fix_places(office, candidate).has(place.id):
				_start({"kind": "ticket", "ticket": candidate, "device": place.id, "seconds": office.helpdesk.fix_seconds(candidate)})
				return true
	return false


func is_working() -> bool:
	return not task.is_empty()


## Whether the player stands at the IT desk (for the desk's own panel).
func at_it_desk() -> bool:
	for desk in office.devices_of("it_desk"):
		if _is_beside(desk):
			return true
	return false


## Where to stand to work on `device`: beside it, not on top of it.
func stand_x(device: RefCounted) -> float:
	if device.kind == "elevator":
		return device.x + 18.0
	return device.x + (34.0 if device.kind != "workstation" and device.kind != "it_desk" else 40.0)


func _nearest(places: Array[String]) -> RefCounted:
	var best: RefCounted = null
	var best_cost: float = INF
	for id in places:
		var place: RefCounted = office.device(id)
		if place == null:
			continue
		var cost: float = absf(float(place.floor_index - player.floor_index)) * 700.0 + absf(place.x - player.world_x())
		if cost < best_cost:
			best_cost = cost
			best = place
	return best


func _is_beside(place: RefCounted) -> bool:
	return not player.riding and player.floor_index == place.floor_index and absf(player.world_x() - stand_x(place)) <= _reach


func _start(wanted: Dictionary) -> void:
	task = wanted
	progress = 0.0
	_pending = {}
	if task.kind == "ticket":
		office.helpdesk.begin_manual(office, task.ticket)


func _cancel() -> void:
	if task.get("kind") == "ticket":
		office.helpdesk.abandon_manual(task.ticket)
	task = {}
	progress = 0.0


func _still_wanted(wanted: Dictionary) -> bool:
	if wanted.kind == "ticket":
		return wanted.ticket.is_open()
	return wanted.incident.is_active()


func _process(delta: float) -> void:
	if office == null or player == null:
		return
	if not _pending.is_empty() and not player.is_routing():
		var place: RefCounted = office.device(_pending.device)
		if place != null and _is_beside(place) and _still_wanted(_pending):
			_start(_pending)
		_pending = {}
	if not task.is_empty():
		_work(delta)
	device_view.work_device = str(task.device) if not task.is_empty() else ""
	device_view.work_progress = progress


func _work(delta: float) -> void:
	var place: RefCounted = office.device(task.device)
	if not _still_wanted(task):
		task = {}
		return
	if place == null or not _is_beside(place) or player.is_routing():
		_cancel()
		return
	progress += delta / float(task.seconds)
	if progress < 1.0:
		return
	var done: Dictionary = task
	task = {}
	progress = 0.0
	if done.kind == "ticket":
		if office.helpdesk.complete_manual(office, done.ticket, place.id):
			message.emit("Fixed #%d: %s" % [done.ticket.id, done.ticket.title])
	elif office.patch_desk.recovery_places(office, done.incident, done.recovery).has(place.id):
		if office.patch_desk.recover(office, done.incident, done.recovery):
			message.emit("Recovered: %s" % office.patch_desk.recovery_label(done.recovery))
