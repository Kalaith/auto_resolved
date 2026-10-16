extends RefCounted
## The building's one elevator car as a small state machine, stepped with a
## fixed delta. Calls queue in order (first come, first served); the car opens
## its doors at each stop, dwells, closes, then heads for the next call.
## Riders (the player now, employees later) only call floors and read state.
const Balance = preload("res://addons/hatchery/core/balance.gd")

enum State { IDLE, MOVING, OPENING, OPEN, CLOSING }

var lowest: int = 0
var highest: int = 0
## The car's height in floors: 2.5 is halfway between floors 2 and 3.
var position: float = 0.0
## 0 = doors shut, 1 = fully open.
var door: float = 0.0
var state: State = State.IDLE
var calls: Array[int] = []
var _dwell_left: float = 0.0
var _speed: float = 0.0
var _door_seconds: float = 0.0
var _dwell_seconds: float = 0.0


func _init(low: int, high: int, start: int = 0) -> void:
	lowest = low
	highest = high
	position = float(clampi(start, low, high))
	_speed = Balance.number("elevator.speed_floors_per_second")
	_door_seconds = Balance.number("elevator.door_seconds")
	_dwell_seconds = Balance.number("elevator.dwell_seconds")


## The floor the car is at or passing.
func current_floor() -> int:
	return roundi(position)


func is_open_at(index: int) -> bool:
	return state == State.OPEN and current_floor() == index


func is_moving() -> bool:
	return state == State.MOVING


## Asks the car to stop at `index`. Calling the floor the car stands at with
## its doors open or closing holds or reopens them instead.
func call_to(index: int) -> void:
	index = clampi(index, lowest, highest)
	if state != State.MOVING and current_floor() == index:
		match state:
			State.OPEN:
				_dwell_left = _dwell_seconds
				return
			State.CLOSING, State.IDLE:
				state = State.OPENING
				return
			State.OPENING:
				return
	if not calls.has(index):
		calls.append(index)


## A rider inside has chosen a floor: stop dwelling and go soon.
func hurry() -> void:
	if state == State.OPEN:
		_dwell_left = minf(_dwell_left, 0.35)


func step(delta: float) -> void:
	match state:
		State.IDLE:
			_start_next()
		State.MOVING:
			_move(delta)
		State.OPENING:
			door = minf(door + delta / _door_seconds, 1.0)
			if door >= 1.0:
				state = State.OPEN
				_dwell_left = _dwell_seconds
		State.OPEN:
			_dwell_left -= delta
			if _dwell_left <= 0.0:
				state = State.CLOSING
		State.CLOSING:
			door = maxf(door - delta / _door_seconds, 0.0)
			if door <= 0.0:
				state = State.IDLE


func _start_next() -> void:
	if calls.is_empty():
		return
	if calls[0] == current_floor() and is_equal_approx(position, float(calls[0])):
		calls.pop_front()
		state = State.OPENING
	else:
		state = State.MOVING


func _move(delta: float) -> void:
	var target: float = float(calls[0])
	var travel: float = _speed * delta
	if absf(target - position) <= travel:
		position = target
		calls.pop_front()
		state = State.OPENING
	else:
		position += travel * signf(target - position)
