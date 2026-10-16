extends Node
## The player's hands. A task is either a ticket fix or an incident recovery;
## each can be done at certain devices (the broken one, or the IT desk). This
## sends the player to the nearest such place, starts the task on arrival (or
## when interact is pressed beside a broken device), and counts its seconds
## while they stay. Walking off abandons it. Task time is real time: it does
## not depend on the office clock or speed. The sim only hears "started" and
## "done here".
signal message(text: String)

const Balance = preload("res://addons/hatchery/core/balance.gd")
const RoomLayout = preload("res://scripts/sim/room_layout.gd")

## Rooms where the IT worker can eat, and the props they eat at.
const EAT_ROOMS: Array[String] = ["kitchen", "break_room"]
const EAT_PROPS: Array[String] = ["fridge", "vending", "table"]

var office: RefCounted
var player: Node2D
var device_view: Node2D
## The task in hand: {"kind": "ticket"|"recovery"|"eat", "ticket",
## "incident", "recovery", "device" (or "floor" and "x" for eating),
## "seconds"}; empty when idle.
var task: Dictionary = {}
var progress: float = 0.0
## Office minutes the current task has used up since main.gd last collected
## them; the office clock runs through a task's effort while it is worked.
var spent_minutes: float = 0.0
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


## Sends the player to the nearest place to eat (a kitchen or break room,
## same floor first) and eats there on arrival.
func request_eat() -> void:
	var spot: Dictionary = _nearest_eat_spot()
	if spot.is_empty():
		message.emit("There is nowhere to eat in this building. Classic.")
		return
	_cancel()
	var wanted: Dictionary = {"kind": "eat", "floor": int(spot.floor), "x": float(spot.x), "seconds": Balance.number("worker.eat_seconds")}
	if _is_at(wanted):
		_start(wanted)
	else:
		_pending = wanted
		player.go_to(int(spot.floor), float(spot.x))


## The eating spot whose prop covers world point `at`, or {}.
func eat_spot_at(at: Vector2) -> Dictionary:
	for spot in _eat_spots():
		var feet := Vector2(float(spot.x), office.plan.floor_y(int(spot.floor)))
		if absf(at.x - feet.x) < 34.0 and at.y < feet.y and at.y > feet.y - 110.0:
			return spot
	return {}


func _eat_spots() -> Array:
	var spots: Array = []
	for index in office.plan.floor_indices():
		for room in office.plan.rooms_on(index):
			if not EAT_ROOMS.has(room.type):
				continue
			for item in RoomLayout.standing(room):
				if EAT_PROPS.has(str(item.prop)):
					spots.append({"floor": index, "x": float(item.x)})
	return spots


func _nearest_eat_spot() -> Dictionary:
	var best: Dictionary = {}
	var best_cost: float = INF
	for spot in _eat_spots():
		var cost: float = absf(float(int(spot.floor) - player.floor_index)) * 700.0 + absf(float(spot.x) - player.world_x())
		if cost < best_cost:
			best_cost = cost
			best = spot
	return best


func _is_at(wanted: Dictionary) -> bool:
	if wanted.kind == "eat":
		return not player.riding and player.floor_index == int(wanted.floor) and absf(player.world_x() - float(wanted.x)) <= _reach
	var place: RefCounted = office.device(wanted.device)
	return place != null and _is_beside(place)


## Plays games at the IT desk (the player must be standing at it).
func play_games() -> bool:
	for desk in office.devices_of("it_desk"):
		if _is_beside(desk):
			_cancel()
			_start({"kind": "games", "device": desk.id, "seconds": Balance.number("worker.games_seconds")})
			return true
	message.emit("Games are on the IT desk's PC. Head to the IT office first.")
	return false


func is_playing() -> bool:
	return task.get("kind") == "games"


func has_pending() -> bool:
	return not _pending.is_empty()


func is_eating() -> bool:
	return task.get("kind") == "eat"


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


## Interact pressed with nothing else to do: fix something here, or eat
## when standing at a kitchen or break room spot. True when it started a task.
func interact_here() -> bool:
	for spot in _eat_spots():
		var wanted: Dictionary = {"kind": "eat", "floor": int(spot.floor), "x": float(spot.x), "seconds": Balance.number("worker.eat_seconds")}
		if _is_at(wanted):
			_start(wanted)
			return true
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
	wanted.effort = _effort(wanted)
	task = wanted
	progress = 0.0
	_pending = {}
	if task.kind == "ticket":
		office.helpdesk.begin_manual(office, task.ticket)


## The office minutes a task takes (its "story points").
func _effort(wanted: Dictionary) -> float:
	match str(wanted.kind):
		"ticket":
			return office.helpdesk.fix_effort(wanted.ticket)
		"games":
			return Balance.number("worker.games_minutes")
		"recovery":
			return office.patch_desk.recovery_effort(str(wanted.recovery))
	return Balance.number("worker.eat_minutes")


## Hands over the office minutes worked since the last call.
func take_spent_minutes() -> float:
	var minutes: float = spent_minutes
	spent_minutes = 0.0
	return minutes


func _cancel() -> void:
	if task.get("kind") == "ticket":
		office.helpdesk.abandon_manual(task.ticket)
	task = {}
	progress = 0.0


func _still_wanted(wanted: Dictionary) -> bool:
	if wanted.kind == "eat" or wanted.kind == "games":
		return true
	if wanted.kind == "ticket":
		return wanted.ticket.is_open()
	return wanted.incident.is_active()


func _process(delta: float) -> void:
	if office == null or player == null:
		return
	if not _pending.is_empty() and not player.is_routing():
		if _is_at(_pending) and _still_wanted(_pending):
			_start(_pending)
		_pending = {}
	if not task.is_empty():
		_work(delta)
	device_view.work_device = str(task.get("device", "")) if not task.is_empty() else ""
	device_view.work_progress = progress
	device_view.eat_at = Vector2(float(task.x), office.plan.floor_y(int(task.floor)) - 10.0) if is_eating() else Vector2.INF


func _work(delta: float) -> void:
	if not _still_wanted(task):
		task = {}
		return
	if not _is_at(task) or player.is_routing():
		_cancel()
		return
	var scale: float = 1.0 if task.kind == "eat" or task.kind == "games" else office.worker.fix_time_scale()
	var step: float = minf(delta / (float(task.seconds) * scale), 1.0 - progress)
	progress += step
	spent_minutes += float(task.effort) * step
	if progress < 1.0:
		return
	var done: Dictionary = task
	task = {}
	progress = 0.0
	if done.kind == "eat":
		office.worker.ate()
		message.emit("Lunch. Hunger gone, and you feel calmer.")
		return
	if done.kind == "games":
		office.worker.played_games()
		message.emit("One more round... Stress down, half an hour gone.")
		return
	var place: RefCounted = office.device(done.device)
	if done.kind == "ticket":
		if office.helpdesk.complete_manual(office, done.ticket, place.id):
			message.emit("Fixed #%d: %s" % [done.ticket.id, done.ticket.title])
	elif office.patch_desk.recovery_places(office, done.incident, done.recovery).has(place.id):
		if office.patch_desk.recover(office, done.incident, done.recovery):
			message.emit("Recovered: %s" % office.patch_desk.recovery_label(done.recovery))
