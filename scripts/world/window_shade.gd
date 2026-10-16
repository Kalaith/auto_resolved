extends Node2D
## Over the building's windows: the outside light as the day goes on, so the
## windows go gold in the morning and blue-dark in the evening while the
## rooms inside stay lit.
const RoomLayout = preload("res://scripts/sim/room_layout.gd")
const RoomProps = preload("res://scripts/world/room_props.gd")

var plan: RefCounted
var _windows: Array[Rect2] = []
var _shade: Color = Color(0, 0, 0, 0)


func setup(building: RefCounted) -> void:
	plan = building
	_windows.clear()
	for index in plan.floor_indices():
		for room in plan.rooms_on(index):
			for x in RoomLayout.windows(room):
				var centre := Vector2(x, plan.floor_y(index) - 10.0 - 112.0)
				_windows.append(Rect2(centre - RoomProps.WINDOW_SIZE * 0.5, RoomProps.WINDOW_SIZE))


## `tint` is the outside light (sky_view.gd); white means no shade.
func set_light(tint: Color) -> void:
	var dark: float = clampf((1.0 - tint.g) / 0.5, 0.0, 1.0)
	var warm: float = clampf((1.0 - tint.b) / 0.18, 0.0, 1.0) * (1.0 - dark)
	var wanted: Color = Color(0.12, 0.12, 0.3, dark * 0.6) if dark > 0.0 else Color(1.0, 0.75, 0.4, warm * 0.25)
	if not wanted.is_equal_approx(_shade):
		_shade = wanted
		queue_redraw()


func _draw() -> void:
	if _shade.a <= 0.01:
		return
	for rect in _windows:
		draw_rect(rect, _shade)
