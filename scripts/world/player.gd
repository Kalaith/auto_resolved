extends Node2D
## The IT worker. Walks left and right along a floor, calls and rides the
## elevator, and can be sent anywhere in the building with a click: the route
## walks to the shaft, calls the car, rides, gets out and walks on. Feet are at
## the node's origin. Movement never depends on tickets, PATCH or the clock.
signal floor_changed(index: int)

const Balance = preload("res://addons/hatchery/core/balance.gd")

const Z_WALKING: int = 4
const Z_RIDING: int = 2

var plan: RefCounted
var elevator: RefCounted
var floor_index: int = 0
var riding: bool = false
## The floor a rider will send the car to when they press interact.
var selected_floor: int = 0
var facing: float = 1.0
var _x: float = 0.0
var _speed: float = 0.0
var _reach: float = 0.0
var _walk_time: float = 0.0
var _moving: bool = false
var _has_goal: bool = false
var _goal_floor: int = 0
var _goal_x: float = 0.0


func setup(building: RefCounted, car: RefCounted, start_floor: int, start_x: float) -> void:
	plan = building
	elevator = car
	floor_index = start_floor
	selected_floor = start_floor
	_x = start_x
	_speed = Balance.number("player.walk_speed")
	_reach = Balance.number("player.interact_reach")
	_place()


## Click-to-move: walk (and ride) to `x` on floor `index`.
func go_to(index: int, x: float) -> void:
	_has_goal = true
	_goal_floor = clampi(index, plan.lowest, plan.highest)
	_goal_x = clampf(x, 12.0, plan.width - 12.0)


func at_shaft() -> bool:
	return absf(_x - plan.shaft_center()) <= _reach


func world_x() -> float:
	return _x


func _physics_process(delta: float) -> void:
	if plan == null:
		return
	var axis: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(axis):
		_has_goal = false
	_moving = false
	if riding:
		_ride(axis)
	else:
		_walk(axis, delta)
	if _moving:
		_walk_time += delta
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if plan == null:
		return
	if event.is_action_pressed("interact"):
		_interact()
	elif riding and event.is_action_pressed("floor_up"):
		selected_floor = mini(selected_floor + 1, plan.highest)
	elif riding and event.is_action_pressed("floor_down"):
		selected_floor = maxi(selected_floor - 1, plan.lowest)


func _interact() -> void:
	_has_goal = false
	if riding:
		elevator.call_to(selected_floor)
		elevator.hurry()
	elif at_shaft():
		if elevator.is_open_at(floor_index):
			_board()
		else:
			elevator.call_to(floor_index)


func _walk(axis: float, delta: float) -> void:
	var direction: float = axis
	if _has_goal:
		var target: float = _goal_x if _goal_floor == floor_index else plan.shaft_center()
		var remaining: float = target - _x
		if absf(remaining) <= 2.0:
			_x = target
			direction = 0.0
			if _goal_floor == floor_index:
				_has_goal = false
			elif elevator.is_open_at(floor_index):
				_board()
				return
			else:
				elevator.call_to(floor_index)
		else:
			direction = signf(remaining) * minf(1.0, absf(remaining) / (_speed * delta))
	if not is_zero_approx(direction):
		_x = clampf(_x + direction * _speed * delta, 12.0, plan.width - 12.0)
		facing = signf(direction)
		_moving = true


func _board() -> void:
	riding = true
	_x = plan.shaft_center()
	selected_floor = _goal_floor if _has_goal else floor_index
	if _has_goal:
		elevator.call_to(_goal_floor)
		elevator.hurry()


func _ride(axis: float) -> void:
	_x = plan.shaft_center()
	if elevator.is_moving():
		return
	var here: int = elevator.current_floor()
	if here != floor_index:
		floor_index = here
		floor_changed.emit(here)
	if not elevator.is_open_at(here):
		return
	var leaving: bool = not is_zero_approx(axis) or (_has_goal and _goal_floor == here)
	if leaving:
		riding = false


func _place() -> void:
	z_index = Z_RIDING if riding else Z_WALKING
	var line: float = -elevator.position * plan.floor_height if riding else plan.floor_y(floor_index)
	position = Vector2(_x, line - 10.0)
	queue_redraw()


func _draw() -> void:
	# A placeholder figure about a third of a floor tall: trousers, polo,
	# lanyard, head and glasses. Legs swing while walking.
	var swing: float = sin(_walk_time * 12.0) * 6.0 if _moving else 0.0
	var bob: float = absf(sin(_walk_time * 12.0)) * 2.0 if _moving else 0.0
	var trousers := Color("#2f3442")
	draw_line(Vector2(-5, -30 - bob), Vector2(-5 + swing, 0), trousers, 7.0)
	draw_line(Vector2(5, -30 - bob), Vector2(5 - swing, 0), trousers, 7.0)
	draw_rect(Rect2(-13, -62 - bob, 26, 34), Color("#3a7bd5"))
	draw_line(Vector2(-6, -62 - bob), Vector2(0, -46 - bob), Color("#e8c547"), 2.0)
	draw_line(Vector2(6, -62 - bob), Vector2(0, -46 - bob), Color("#e8c547"), 2.0)
	draw_rect(Rect2(-3, -46 - bob, 6, 8), Color.WHITE)
	draw_circle(Vector2(0, -74 - bob), 11.0, Color("#e9b996"))
	draw_rect(Rect2(-11, -87 - bob, 22, 7), Color("#3b2a20"))
	draw_line(Vector2(-1 * facing, -75 - bob), Vector2(9 * facing, -75 - bob), Color("#1c1c1c"), 2.0)
