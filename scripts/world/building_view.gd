extends Node2D
## Draws a BuildingPlan as a cutaway: sky and skyline, ground, the building
## shell, every floor's rooms with their walls, props and labels, slabs, and
## the elevator shaft with its landing frames. The car and its doors are drawn
## by elevator_view.gd so they can sit either side of the player.
const RoomProps = preload("res://scripts/world/room_props.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")
const BuildingPlan = preload("res://scripts/sim/building_plan.gd")

const SHELL: float = 18.0
const ROOF: float = 26.0
const DOOR_HEIGHT: float = 92.0
const LANDING_HEIGHT: float = 112.0
const DIVIDER: float = 8.0

var plan: RefCounted
var job_seed: int = 0
var _slab: float = 14.0
var _font: Font


func setup(building: RefCounted, seed_value: int) -> void:
	plan = building
	job_seed = seed_value
	_slab = Balance.number("building.slab")
	_font = ThemeDB.fallback_font
	queue_redraw()


static func floor_name(index: int) -> String:
	return BuildingPlan.floor_name(index)


## The outer rectangle of the building, roof and basement included.
func shell_rect() -> Rect2:
	var top: float = plan.floor_y(plan.highest) - plan.floor_height - ROOF
	var bottom: float = plan.floor_y(plan.lowest) + _slab
	return Rect2(-SHELL, top, plan.width + SHELL * 2.0, bottom - top)


func _draw() -> void:
	if plan == null:
		return
	_draw_backdrop()
	var shell: Rect2 = shell_rect()
	draw_rect(shell, plan.colours.exterior)
	for index in plan.floor_indices():
		_draw_floor(index)
	_draw_shaft()
	_draw_roof(shell)


func _draw_backdrop() -> void:
	var sky: Color = plan.colours.sky
	var reach: float = maxf(plan.width, 2000.0) * 2.0
	var top: float = plan.floor_y(plan.highest) - plan.floor_height * 4.0
	draw_rect(Rect2(-reach, top - 2000.0, plan.width + reach * 2.0, 2000.0 - top), sky)
	# Distant skyline: blocks a shade off the sky, seeded by the job.
	var rng: RandomNumberGenerator = Det.fork(job_seed, "skyline")
	var x: float = -reach
	while x < plan.width + reach:
		var block_width: float = rng.randf_range(80.0, 220.0)
		var height: float = rng.randf_range(120.0, plan.floor_height * float(plan.highest + 2))
		draw_rect(Rect2(x, -height, block_width - 10.0, height), sky.darkened(0.12 + rng.randf() * 0.1))
		x += block_width
	var ground: Color = Color(plan.colours.exterior).darkened(0.45)
	var depth: float = Balance.number("building.ground_depth") + plan.floor_height * float(1 - plan.lowest) + 600.0
	draw_rect(Rect2(-reach, 0.0, plan.width + reach * 2.0, depth), ground)
	draw_rect(Rect2(-reach, 0.0, plan.width + reach * 2.0, 10.0), ground.lightened(0.2))


func _draw_floor(index: int) -> void:
	var line: float = plan.floor_y(index)
	var top: float = line - plan.floor_height + _slab
	for room in plan.rooms_on(index):
		var rect := Rect2(room.x, top, room.width, line - top)
		draw_rect(rect, room.wall)
		# Skirting and floor covering.
		draw_rect(Rect2(room.x, line - 10.0, room.width, 10.0), plan.colours.floor)
		draw_rect(Rect2(room.x, line - 12.0, room.width, 2.0), Color(plan.colours.trim).darkened(0.2))
		RoomProps.draw_room(self, room, line - 10.0, plan.colours)
		_draw_label(room, top)
	for room in plan.rooms_on(index):
		_draw_dividers(room, top, line)
	# The slab under this floor, carrying the floor below's ceiling.
	draw_rect(Rect2(0.0, line, plan.width, _slab), plan.colours.slab)


## Each room's outer edges get a wall stub that stops above head height, so
## people visibly walk through doorways between rooms.
func _draw_dividers(room: Dictionary, top: float, line: float) -> void:
	var trim: Color = plan.colours.trim
	for edge in [room.x, room.x + room.width]:
		if edge <= 0.5 or edge >= plan.width - 0.5:
			continue
		if absf(edge - plan.shaft_x) < 1.0 or absf(edge - plan.shaft_x - plan.shaft_width) < 1.0:
			continue
		draw_rect(Rect2(edge - DIVIDER * 0.5, top, DIVIDER, line - top - DOOR_HEIGHT - 10.0), trim)
		draw_rect(Rect2(edge - DIVIDER * 0.5 - 3.0, line - DOOR_HEIGHT - 16.0, DIVIDER + 6.0, 6.0), trim.darkened(0.2))


func _draw_label(room: Dictionary, top: float) -> void:
	var ink: Color = room.wall.darkened(0.55) if room.wall.get_luminance() > 0.45 else room.wall.lightened(0.6)
	draw_string(_font, Vector2(room.x + 10.0, top + 20.0), str(room.label).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)


func _draw_shaft() -> void:
	var top: float = plan.floor_y(plan.highest) - plan.floor_height
	var bottom: float = plan.floor_y(plan.lowest)
	var shaft := Rect2(plan.shaft_x, top, plan.shaft_width, bottom - top)
	draw_rect(shaft, Color(plan.colours.slab).darkened(0.35))
	var trim: Color = plan.colours.trim
	for index in plan.floor_indices():
		var line: float = plan.floor_y(index)
		# Landing floor across the shaft front and the door frame.
		draw_rect(Rect2(plan.shaft_x, line - 10.0, plan.shaft_width, 10.0), Color(plan.colours.floor).darkened(0.15))
		var frame := Rect2(plan.shaft_x + 6.0, line - LANDING_HEIGHT - 8.0, plan.shaft_width - 12.0, LANDING_HEIGHT - 2.0)
		draw_rect(frame, trim, false, 4.0)
		var badge := Vector2(plan.shaft_center(), line - LANDING_HEIGHT - 26.0)
		draw_circle(badge, 12.0, Color(plan.colours.accent).darkened(0.1))
		draw_string(_font, badge + Vector2(-12.0, 5.0), floor_name(index), HORIZONTAL_ALIGNMENT_CENTER, 24, 14, Color.WHITE)
		draw_rect(Rect2(plan.shaft_x, line, plan.shaft_width, _slab), plan.colours.slab)


func _draw_roof(shell: Rect2) -> void:
	var roof := Rect2(shell.position.x - 10.0, shell.position.y, shell.size.x + 20.0, ROOF)
	draw_rect(roof, Color(plan.colours.slab).darkened(0.2))
	draw_rect(Rect2(roof.position.x, roof.end.y - 4.0, roof.size.x, 4.0), plan.colours.trim)
