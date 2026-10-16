extends RefCounted
## Anyone who moves through the building: walks left and right along a floor
## and changes floor only by riding the elevator. A route is the legs "walk to
## the landing, wait for the car, ride, walk on", taken one at a time from the
## goal, so the player and every employee share this one path.
##
## Feet are at (x, floor line). While riding, the floor follows the car.

var id: String = ""
var floor_index: int = 0
var x: float = 0.0
var speed: float = 100.0
var riding: bool = false
var has_goal: bool = false
var goal_floor: int = 0
var goal_x: float = 0.0
## Where this walker stands at a landing and inside the car, relative to the
## shaft centre, so a crowd spreads out instead of stacking on one pixel.
var wait_offset: float = 30.0
var ride_offset: float = 0.0
## Set each step: whether the feet moved, which way they face, and whether the
## walker is standing at a landing waiting for the car.
var moving: bool = false
var facing: float = 1.0
var waiting: bool = false
## The player may squeeze into a full car; staff wait for the next one.
var squeeze: bool = false


func _init(walker_id: String, start_floor: int, start_x: float, walk_speed: float) -> void:
	id = walker_id
	floor_index = start_floor
	x = start_x
	speed = walk_speed


## Walk (and ride) to `to_x` on floor `index`.
func go_to(index: int, to_x: float) -> void:
	has_goal = true
	goal_floor = index
	goal_x = to_x


func stop() -> void:
	has_goal = false


func arrived() -> bool:
	return not has_goal and not riding


## Where the walker's feet are drawn, in world units, given the building.
func feet(plan: RefCounted, elevator: RefCounted) -> Vector2:
	var line: float = -elevator.position * plan.floor_height if riding else plan.floor_y(floor_index)
	return Vector2(x, line)


func step(delta: float, elevator: RefCounted, plan: RefCounted) -> void:
	moving = false
	waiting = false
	if riding:
		_ride(elevator, plan)
		return
	if not has_goal:
		return
	if goal_floor == floor_index:
		if walk_toward(goal_x, delta):
			has_goal = false
		return
	if walk_toward(plan.shaft_center() + wait_offset, delta):
		_at_landing(elevator)


## Moves toward `target`; true once standing on it.
func walk_toward(target: float, delta: float) -> bool:
	var remaining: float = target - x
	var travel: float = speed * delta
	if absf(remaining) <= travel:
		moving = absf(remaining) > 0.01
		x = target
		return true
	facing = signf(remaining)
	x += travel * facing
	moving = true
	return false


## Steps into the car when it is open here with room, otherwise presses the
## landing button, except while a full car is still standing at this floor
## (pressing then would only hold its doors open).
func _at_landing(elevator: RefCounted) -> void:
	waiting = true
	if elevator.is_open_at(floor_index):
		if elevator.board(id, floor_index, squeeze):
			riding = true
			elevator.press(goal_floor)
			elevator.hurry()
		return
	var car_here: bool = elevator.current_floor() == floor_index and not elevator.is_moving()
	if car_here and not elevator.has_room() and not squeeze:
		return
	if not elevator.hall_calls.has(floor_index):
		elevator.call_to(floor_index)


func _ride(elevator: RefCounted, plan: RefCounted) -> void:
	x = plan.shaft_center() + ride_offset
	if elevator.is_moving():
		return
	var here: int = elevator.current_floor()
	floor_index = here
	if not has_goal:
		# A rider with no goal (the player steering by hand) stays put.
		return
	if here == goal_floor:
		if elevator.is_open_at(here):
			elevator.leave(id)
			riding = false
		elif not elevator.is_called(here):
			elevator.press(here)
	elif not elevator.car_calls.has(goal_floor):
		elevator.press(goal_floor)
