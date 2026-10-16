extends Node
## The player's hands. Sends the player to the nearest place a ticket can be
## fixed, starts a fix when they arrive (or press interact beside a broken
## device), and counts the fix's seconds while they stand still. Walking off
## abandons it. Fix time is real time: it does not depend on the office clock
## or speed. The sim only hears "started" and "held long enough here".
signal message(text: String)

var office: RefCounted
var player: Node2D
var device_view: Node2D
var ticket: RefCounted = null
var device_id: String = ""
var progress: float = 0.0
## A ticket the player is walking to; its fix starts on arrival.
var _pending: RefCounted = null
var _pending_device: String = ""
var _reach: float = 52.0


func setup(sim: RefCounted, walker_node: Node2D, view: Node2D) -> void:
	office = sim
	player = walker_node
	device_view = view
	ticket = null
	_pending = null
	device_id = ""


## Routes the player to the nearest fix place for `ticket_id`.
func request(ticket_id: int) -> void:
	var target: RefCounted = office.helpdesk.queue.get_ticket(ticket_id)
	if target == null or not target.is_open():
		return
	var place: RefCounted = _nearest_place(target)
	if place == null:
		return
	_cancel_work()
	_pending = target
	_pending_device = place.id
	if _is_beside(place):
		_start(target, place.id)
	else:
		player.go_to(place.floor_index, stand_x(place))


## Interact pressed with nothing else to do: fix something here if possible.
## True when it started a fix.
func interact_here() -> bool:
	for place in office.devices:
		if not _is_beside(place):
			continue
		for candidate in office.helpdesk.queue.by_urgency():
			if office.helpdesk.fix_places(office, candidate).has(place.id):
				_start(candidate, place.id)
				return true
	return false


func is_working() -> bool:
	return ticket != null


## Where to stand to work on `device`: beside it, not on top of it.
func stand_x(device: RefCounted) -> float:
	if device.kind == "elevator":
		return device.x + 18.0
	return device.x + (34.0 if device.kind != "workstation" else 40.0)


func _nearest_place(target: RefCounted) -> RefCounted:
	var best: RefCounted = null
	var best_cost: float = INF
	for id in office.helpdesk.fix_places(office, target):
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


func _start(target: RefCounted, at_device: String) -> void:
	ticket = target
	device_id = at_device
	progress = 0.0
	_pending = null
	office.helpdesk.begin_manual(office, ticket)


func _cancel_work() -> void:
	if ticket != null:
		office.helpdesk.abandon_manual(ticket)
	ticket = null
	device_id = ""
	progress = 0.0


func _process(delta: float) -> void:
	if office == null or player == null:
		return
	if _pending != null and not player.is_routing():
		var place: RefCounted = office.device(_pending_device)
		if place != null and _is_beside(place) and _pending.is_open():
			_start(_pending, place.id)
		_pending = null
	if ticket != null:
		_work(delta)
	device_view.work_device = device_id if ticket != null else ""
	device_view.work_progress = progress


func _work(delta: float) -> void:
	var place: RefCounted = office.device(device_id)
	if not ticket.is_open():
		ticket = null
		device_id = ""
		return
	if place == null or not _is_beside(place) or player.is_routing():
		_cancel_work()
		return
	progress += delta / office.helpdesk.fix_seconds(ticket)
	if progress >= 1.0:
		var done: RefCounted = ticket
		ticket = null
		device_id = ""
		progress = 0.0
		if office.helpdesk.complete_manual(office, done, place.id):
			message.emit("Fixed #%d: %s" % [done.id, done.title])
