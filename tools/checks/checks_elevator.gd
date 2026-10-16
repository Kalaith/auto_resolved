extends RefCounted
## The elevator sweeps calls in its direction of travel, opens at each stop and closes again.
const Elevator = preload("res://scripts/sim/elevator.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")

const STEP: float = 1.0 / 60.0


func check_car_reaches_called_floor_and_opens() -> String:
	var car: RefCounted = Elevator.new(-1, 4, 0)
	car.call_to(3)
	var opened: bool = _run_until(car, func() -> bool: return car.is_open_at(3), 10.0)
	return Expect.all([
		Expect.truthy(opened, "car opens at floor 3"),
		Expect.equal(car.current_floor(), 3, "car stopped at 3"),
		Expect.empty(car.calls(), "call served"),
	])


func check_car_sweeps_one_way_before_turning() -> String:
	var car: RefCounted = Elevator.new(-1, 4, 0)
	car.call_to(2)
	var stops: Array[int] = []
	for i in range(60 * 30):
		if i == 10:
			car.call_to(-1)
			car.call_to(3)
		car.step(STEP)
		if car.state == Elevator.State.OPENING and (stops.is_empty() or stops[-1] != car.current_floor()):
			stops.append(car.current_floor())
	return Expect.equal(stops, [2, 3, -1] as Array[int], "stops ahead first, then turns round")


func check_doors_close_after_dwell() -> String:
	var car: RefCounted = Elevator.new(0, 3, 0)
	car.call_to(0)
	var closed_again: bool = _run_until(car, func() -> bool: return car.state == Elevator.State.IDLE and car.door == 0.0, 6.0)
	return Expect.truthy(closed_again, "doors open on the spot and close again")


func check_calling_an_open_floor_holds_the_doors() -> String:
	var car: RefCounted = Elevator.new(0, 3, 0)
	car.call_to(0)
	_run_until(car, func() -> bool: return car.is_open_at(0), 3.0)
	car.call_to(0)
	return Expect.all([Expect.empty(car.calls(), "no new trip queued"), Expect.truthy(car.is_open_at(0), "still open")])


func _run_until(car: RefCounted, done: Callable, limit: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < limit:
		car.step(STEP)
		elapsed += STEP
		if done.call():
			return true
	return false
