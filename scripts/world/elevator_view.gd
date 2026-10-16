extends Node2D
## Draws the elevator from its simulation. Two instances share this script:
## the CAR layer sits behind the player and the DOORS layer in front of a
## riding player (main.gd sets z_index), so a rider vanishes behind shut doors
## while someone walking past the landing stays in front of them.
const BuildingView = preload("res://scripts/world/building_view.gd")

enum Layer { CAR, DOORS }

var layer: Layer = Layer.CAR
var plan: RefCounted
var elevator: RefCounted


func setup(building: RefCounted, car: RefCounted, which: Layer) -> void:
	plan = building
	elevator = car
	layer = which


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if plan == null or elevator == null:
		return
	if layer == Layer.CAR:
		_draw_car()
	else:
		_draw_doors()


## The car's floor line in world y, following its fractional position.
func car_floor_y() -> float:
	return -elevator.position * plan.floor_height


func _opening(line: float) -> Rect2:
	var inset: float = 10.0
	var height: float = BuildingView.LANDING_HEIGHT - 6.0
	return Rect2(plan.shaft_x + inset, line - height - 10.0, plan.shaft_width - inset * 2.0, height)


func _draw_car() -> void:
	var line: float = car_floor_y()
	var top: float = plan.floor_y(plan.highest) - plan.floor_height
	draw_line(Vector2(plan.shaft_center(), top), Vector2(plan.shaft_center(), line - BuildingView.LANDING_HEIGHT - 10.0), Color(0.1, 0.1, 0.12), 3.0)
	var car: Rect2 = _opening(line).grow(2.0)
	draw_rect(car, Color(plan.colours.trim).lightened(0.55))
	draw_rect(Rect2(car.position.x, car.end.y - 6.0, car.size.x, 6.0), Color(plan.colours.floor).darkened(0.1))
	draw_rect(Rect2(car.position.x + 6.0, car.position.y + 4.0, car.size.x - 12.0, 4.0), Color(1.0, 0.96, 0.8, 0.9))


func _draw_doors() -> void:
	var metal: Color = Color(plan.colours.trim).lerp(Color("#c9d0d8"), 0.6)
	for index in plan.floor_indices():
		var line: float = plan.floor_y(index)
		var opening: Rect2 = _opening(line)
		var open: float = elevator.door if elevator.current_floor() == index and not elevator.is_moving() else 0.0
		var half: float = opening.size.x * 0.5 * (1.0 - open)
		draw_rect(Rect2(opening.position, Vector2(half, opening.size.y)), metal)
		draw_rect(Rect2(opening.end.x - half, opening.position.y, half, opening.size.y), metal)
		if open < 0.05:
			draw_line(Vector2(opening.get_center().x, opening.position.y), Vector2(opening.get_center().x, opening.end.y), metal.darkened(0.3), 2.0)
		# Hall lamp: lit while the car is called to this floor.
		var lamp := Vector2(plan.shaft_x + plan.shaft_width - 14.0, line - 50.0)
		draw_circle(lamp, 4.0, Color("#f2b84b") if elevator.calls.has(index) else Color(0.2, 0.2, 0.22))
