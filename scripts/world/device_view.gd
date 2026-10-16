extends Node2D
## Draws what is wrong with the office's devices, over the furniture the
## building view drew: a padlock on a locked-out PC, a red light on an
## offline printer, a floor of dead network screens, a blinking lift
## controller, plus a "!" bubble over anything with an open ticket and a
## progress ring while the player works. Reads the office sim every frame.
const FaultArt = preload("res://scripts/world/fault_art.gd")

const PICK_RADIUS: float = 40.0

var office: RefCounted
## The device the player is working at and how far along (0..1), or "".
var work_device: String = ""
var work_progress: float = 0.0
## Where the player is eating (progress ring there), or INF.
var eat_at: Vector2 = Vector2.INF
var _time: float = 0.0
var _font: Font


func setup(sim: RefCounted) -> void:
	office = sim
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func floor_line(device: RefCounted) -> float:
	return office.plan.floor_y(device.floor_index) - 10.0


func _draw() -> void:
	if office == null:
		return
	var now: float = office.clock.stamp()
	for device in office.devices:
		var at := Vector2(device.x, floor_line(device))
		if device.kind == "elevator":
			FaultArt.lift_panel(self, at, device.has_fault("confused"), _time)
		for fault in device.faults:
			FaultArt.draw_fault(self, device.kind, str(fault), at, _time)
		if device.kind == "workstation":
			_draw_area_faults(device, at)
	for ticket in office.helpdesk.queue.open_tickets():
		var device: RefCounted = office.device(ticket.device_id)
		if device != null:
			_bubble(Vector2(device.x, floor_line(device)) + _bubble_offset(device), ticket, now)
	if eat_at != Vector2.INF:
		_ring(eat_at + Vector2(0, -140), work_progress)
	if not work_device.is_empty():
		var device: RefCounted = office.device(work_device)
		if device != null:
			_ring(Vector2(device.x, floor_line(device)) + Vector2(0, -140), work_progress)


## Floor-wide outages show on every PC of the floor they cover.
func _draw_area_faults(device: RefCounted, at: Vector2) -> void:
	for fault in ["no_network", "dark"]:
		if office.floor_has(fault, device.floor_index):
			FaultArt.draw_fault(self, "workstation", fault, at, _time)


func _bubble_offset(device: RefCounted) -> Vector2:
	match device.kind:
		"server", "network_core":
			return Vector2(0, -150)
		"elevator":
			return Vector2(0, -110)
	return Vector2(10, -100)


func _bubble(at: Vector2, ticket: RefCounted, now: float) -> void:
	var tint: Color = Color("#f2c94c")
	if ticket.is_overdue(now):
		tint = Color("#e0483e") if fmod(_time, 0.8) < 0.5 else Color("#a8322b")
	elif ticket.minutes_left(now) < (ticket.deadline - ticket.created) * 0.35:
		tint = Color("#f08a30")
	if ticket.status == "in_progress":
		tint = Color("#5ec4e8")
	draw_circle(at, 13.0, Color(0, 0, 0, 0.35))
	draw_circle(at, 11.0, tint)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-5, 8), at + Vector2(5, 8), at + Vector2(0, 16)]), tint)
	draw_string(_font, at + Vector2(-4, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#1c1c22"))


func _ring(at: Vector2, progress: float) -> void:
	draw_circle(at, 18.0, Color(0, 0, 0, 0.45))
	draw_arc(at, 14.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 32, Color("#5ee07a"), 5.0)


## The device whose body covers world point `at`, or null.
func device_at(at: Vector2) -> RefCounted:
	var best: RefCounted = null
	var best_distance: float = PICK_RADIUS
	for device in office.devices:
		var centre := Vector2(device.x, floor_line(device) - _height(device) * 0.5)
		var distance: float = Vector2(at.x - centre.x, (at.y - centre.y) * 0.5).length()
		if distance < best_distance and absf(at.y - centre.y) < _height(device) * 0.6 + 10.0:
			best_distance = distance
			best = device
	return best


static func _height(device: RefCounted) -> float:
	match device.kind:
		"server", "network_core":
			return 118.0
		"printer":
			return 64.0
		"elevator":
			return 90.0
	return 70.0
