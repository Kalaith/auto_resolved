extends Node2D
## The IT worker. Walks left and right along a floor, calls and rides the
## elevator, and can be sent anywhere in the building with a click: the route
## is the same Walker the staff use, stepped here in real time so the player
## moves while the office is paused or panels are open. Movement never depends
## on tickets, PATCH or the clock. Feet are at the node's origin.
signal floor_changed(index: int)
signal arrived

const Balance = preload("res://addons/hatchery/core/balance.gd")
const Walker = preload("res://scripts/sim/walker.gd")
const FigureArt = preload("res://scripts/world/figure_art.gd")

const Z_WALKING: int = 5
const Z_RIDING: int = 2
const ID: String = "player"

var plan: RefCounted
var elevator: RefCounted
var walker: Walker
## The floor a rider will send the car to when they press interact.
var selected_floor: int = 0
var floor_index: int:
	get:
		return walker.floor_index
var riding: bool:
	get:
		return walker.riding
## The walk speed before hunger slows it (main.gd scales walker.speed).
var base_speed: float = 0.0
var _reach: float = 0.0
var _walk_time: float = 0.0
var _look: Dictionary = {}
var _was_routing: bool = false


func setup(building: RefCounted, car: RefCounted, start_floor: int, start_x: float) -> void:
	plan = building
	elevator = car
	walker = Walker.new(ID, start_floor, start_x, Balance.number("player.walk_speed"))
	walker.squeeze = true
	base_speed = walker.speed
	walker.wait_offset = 0.0
	selected_floor = start_floor
	_reach = Balance.number("player.interact_reach")
	_look = FigureArt.look_for(ID, Color("#3a7bd5"))
	_look.skin = Color("#e9b996")
	_look.hair = Color("#3b2a20")
	_look.trousers = Color("#2f3442")
	_look.glasses = true
	_look.long_hair = false
	_place()


## Click-to-move: walk (and ride) to `x` on floor `index`.
func go_to(index: int, x: float) -> void:
	walker.go_to(clampi(index, plan.lowest, plan.highest), clampf(x, 12.0, plan.width - 12.0))
	_was_routing = true


func at_shaft() -> bool:
	return absf(walker.x - plan.shaft_center()) <= _reach


func world_x() -> float:
	return walker.x


func is_routing() -> bool:
	return walker.has_goal or walker.riding


func _physics_process(delta: float) -> void:
	if plan == null:
		return
	var axis: float = Input.get_axis("move_left", "move_right")
	var before: int = walker.floor_index
	if not is_zero_approx(axis):
		walker.stop()
		_was_routing = false
	if walker.riding:
		_ride_by_hand(axis)
		if walker.riding:
			walker.step(delta, elevator, plan)
	elif walker.has_goal:
		walker.step(delta, elevator, plan)
	elif not is_zero_approx(axis):
		walker.walk_toward(clampf(walker.x + axis * walker.speed * delta, 12.0, plan.width - 12.0), delta)
		walker.facing = signf(axis)
	else:
		walker.moving = false
	if walker.floor_index != before:
		floor_changed.emit(walker.floor_index)
	if _was_routing and walker.arrived():
		_was_routing = false
		arrived.emit()
	if walker.moving:
		_walk_time += delta
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if plan == null:
		return
	if event.is_action_pressed("interact") and (walker.riding or at_shaft()):
		_interact()
		get_viewport().set_input_as_handled()
	elif walker.riding and event.is_action_pressed("floor_up"):
		selected_floor = mini(selected_floor + 1, plan.highest)
	elif walker.riding and event.is_action_pressed("floor_down"):
		selected_floor = maxi(selected_floor - 1, plan.lowest)


func _interact() -> void:
	if walker.riding:
		walker.go_to(selected_floor, plan.shaft_center())
		elevator.press(selected_floor)
		elevator.hurry()
		return
	walker.stop()
	if elevator.is_open_at(walker.floor_index):
		if elevator.board(ID, walker.floor_index, true):
			walker.riding = true
			selected_floor = walker.floor_index
	else:
		elevator.call_to(walker.floor_index)


## Steering by hand inside the car: walking left or right steps out when the
## doors are open.
func _ride_by_hand(axis: float) -> void:
	if is_zero_approx(axis) or not elevator.is_open_at(elevator.current_floor()):
		return
	elevator.leave(ID)
	walker.riding = false
	walker.floor_index = elevator.current_floor()
	walker.stop()


func _place() -> void:
	z_index = Z_RIDING if walker.riding else Z_WALKING
	position = walker.feet(plan, elevator) + Vector2(0.0, -10.0)
	queue_redraw()


func _draw() -> void:
	FigureArt.draw_standing(self, Vector2.ZERO, _look, walker.facing, _walk_time if walker.moving else -1.0)
	# The lanyard and badge that mark the IT worker out from the staff.
	draw_line(Vector2(-6, -62), Vector2(0, -46), Color("#e8c547"), 2.0)
	draw_line(Vector2(6, -62), Vector2(0, -46), Color("#e8c547"), 2.0)
	draw_rect(Rect2(-3, -46, 6, 8), Color.WHITE)
