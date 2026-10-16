extends RefCounted
## The building's one elevator car as a small state machine, stepped with a
## fixed delta. Collective control: the car keeps travelling in one direction
## while any call (from a landing or from inside) lies ahead, stopping at each,
## then turns round. It carries at most `capacity` riders, known by id, so the
## simulation moves people and the player through the same calls.
##
## The car is also an IT system: `speed_scale` and `stop_everywhere` are set by
## the office when PATCH tunes or breaks the building management controller.
const Balance = preload("res://addons/hatchery/core/balance.gd")

enum State { IDLE, MOVING, OPENING, OPEN, CLOSING }

var lowest: int = 0
var highest: int = 0
## The car's height in floors: 2.5 is halfway between floors 2 and 3.
var position: float = 0.0
## 0 = doors shut, 1 = fully open.
var door: float = 0.0
var state: State = State.IDLE
## +1 travelling up, -1 down, 0 no direction yet.
var direction: int = 0
## Floors where someone pressed the landing button.
var hall_calls: Array[int] = []
## Floors chosen by riders inside the car.
var car_calls: Array[int] = []
## Ids of everyone inside, in boarding order.
var riders: Array[String] = []
var capacity: int = 8
## 1 is normal; PATCH's tuning raises it, a broken controller lowers it.
var speed_scale: float = 1.0
## A confused controller opens the doors at every floor it passes.
var stop_everywhere: bool = false
var _dwell_left: float = 0.0
var _speed: float = 0.0
var _door_seconds: float = 0.0
var _dwell_seconds: float = 0.0
var _last_stop: int = 0


func _init(low: int, high: int, start: int = 0) -> void:
	lowest = low
	highest = high
	position = float(clampi(start, low, high))
	_last_stop = clampi(start, low, high)
	_speed = Balance.number("elevator.speed_floors_per_second")
	_door_seconds = Balance.number("elevator.door_seconds")
	_dwell_seconds = Balance.number("elevator.dwell_seconds")
	capacity = Balance.integer("elevator.capacity")


## The floor the car is at or passing.
func current_floor() -> int:
	return roundi(position)


func is_open_at(index: int) -> bool:
	return state == State.OPEN and current_floor() == index


func is_moving() -> bool:
	return state == State.MOVING


func has_room() -> bool:
	return riders.size() < capacity


func is_called(index: int) -> bool:
	return hall_calls.has(index) or car_calls.has(index)


## Every floor with a pending stop, for views and the HUD.
func calls() -> Array[int]:
	var result: Array[int] = hall_calls.duplicate()
	for index in car_calls:
		if not result.has(index):
			result.append(index)
	return result


## A landing button: asks the car to stop at `index`. Pressing it where the
## car stands with its doors open or closing holds or reopens them instead.
func call_to(index: int) -> void:
	index = clampi(index, lowest, highest)
	if _hold_here(index):
		return
	if not hall_calls.has(index):
		hall_calls.append(index)


## A button inside the car.
func press(index: int) -> void:
	index = clampi(index, lowest, highest)
	if _hold_here(index):
		return
	if not car_calls.has(index):
		car_calls.append(index)


## Steps inside if the doors are open at `index` and there is room; one who
## may `squeeze` (the IT worker, who always fits) ignores the capacity.
func board(id: String, index: int, squeeze: bool = false) -> bool:
	if not is_open_at(index) or riders.has(id):
		return riders.has(id)
	if not has_room() and not squeeze:
		return false
	riders.append(id)
	_dwell_left = maxf(_dwell_left, 0.5)
	return true


## Steps out; the doors stay open a little longer for whoever follows.
func leave(id: String) -> void:
	riders.erase(id)
	if state == State.OPEN:
		_dwell_left = maxf(_dwell_left, 0.35)


## A rider inside has chosen a floor: stop dwelling and go soon.
func hurry() -> void:
	if state == State.OPEN:
		_dwell_left = minf(_dwell_left, 0.35)


## Empties the car and every call: the office closing for the night.
func reset_to(index: int) -> void:
	riders.clear()
	hall_calls.clear()
	car_calls.clear()
	position = float(clampi(index, lowest, highest))
	_last_stop = current_floor()
	state = State.IDLE
	door = 0.0
	direction = 0


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


func _hold_here(index: int) -> bool:
	if state == State.MOVING or current_floor() != index:
		return false
	match state:
		State.OPEN:
			_dwell_left = maxf(_dwell_left, _dwell_seconds * 0.6)
		State.CLOSING, State.IDLE:
			state = State.OPENING
	return true


func _start_next() -> void:
	var target: int = _next_stop()
	if target == current_floor() and is_equal_approx(position, float(target)) and is_called(target):
		_arrive(target)
	elif is_called(target) or target != current_floor():
		state = State.MOVING


## The nearest call ahead in the travel direction; when none lies ahead the
## car turns round. With no calls at all it stays where it is.
func _next_stop() -> int:
	var pending: Array[int] = calls()
	if pending.is_empty():
		direction = 0
		return current_floor()
	var ahead: Array[int] = _calls_ahead(pending, direction)
	if ahead.is_empty():
		var nearest: int = pending[0]
		for index in pending:
			if absf(float(index) - position) < absf(float(nearest) - position):
				nearest = index
		direction = signi(nearest - current_floor()) if not is_equal_approx(float(nearest), position) else 0
		return nearest
	var best: int = ahead[0]
	for index in ahead:
		if absf(float(index) - position) < absf(float(best) - position):
			best = index
	return best


func _calls_ahead(pending: Array[int], heading: int) -> Array[int]:
	var result: Array[int] = []
	if heading == 0:
		return result
	for index in pending:
		if (heading > 0 and float(index) >= position - 0.001) or (heading < 0 and float(index) <= position + 0.001):
			result.append(index)
	return result


func _move(delta: float) -> void:
	var target: int = _next_stop()
	if direction == 0:
		direction = signi(target - current_floor())
	var travel: float = _speed * speed_scale * delta
	var passing: int = _passing_floor(travel)
	if passing != 9999:
		position = float(passing)
		_arrive(passing)
		return
	if absf(float(target) - position) <= travel:
		position = float(target)
		_arrive(target)
	else:
		position += travel * signf(float(target) - position)


## A confused controller stops at the next floor it reaches, called or not.
func _passing_floor(travel: float) -> int:
	if not stop_everywhere:
		return 9999
	var next_floor: float = floorf(position) + 1.0 if direction > 0 else ceilf(position) - 1.0
	if is_equal_approx(position, roundf(position)):
		next_floor = position + float(direction)
	if absf(next_floor - position) <= travel and int(next_floor) != _last_stop:
		return int(next_floor)
	return 9999


func _arrive(index: int) -> void:
	hall_calls.erase(index)
	car_calls.erase(index)
	_last_stop = index
	state = State.OPENING
	if calls().is_empty():
		direction = 0
