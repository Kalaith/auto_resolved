extends Camera2D
## Follows the player at working zoom, or pulls back to frame the whole
## building (the overview). Eases between the two so a job change or a toggle
## never snaps.
const Balance = preload("res://addons/hatchery/core/balance.gd")

var target: Node2D
var overview: bool = false
var bounds: Rect2 = Rect2()
var _rate: float = 6.0
var _margin: float = 80.0


func setup(follow: Node2D, building_bounds: Rect2) -> void:
	target = follow
	bounds = building_bounds
	_rate = Balance.number("camera.follow_rate")
	_margin = Balance.number("camera.overview_margin")
	position = _wanted_position()
	zoom = _wanted_zoom()


func _process(delta: float) -> void:
	if target == null:
		return
	var blend: float = minf(1.0, delta * _rate)
	position = position.lerp(_wanted_position(), blend)
	zoom = zoom.lerp(_wanted_zoom(), blend)


func _wanted_position() -> Vector2:
	if overview:
		return bounds.get_center()
	return target.position + Vector2(0.0, -60.0)


func _wanted_zoom() -> Vector2:
	if not overview:
		return Vector2.ONE
	var view: Vector2 = get_viewport_rect().size
	var fit: float = minf(view.x / (bounds.size.x + _margin * 2.0), view.y / (bounds.size.y + _margin * 2.0))
	return Vector2.ONE * minf(fit, 1.0)
