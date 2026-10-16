extends Node2D
## Behind the building: the sky, the job's seeded skyline and the ground,
## tinted by the time of day (a warm morning, a plain midday, a dusky
## evening). Redraws only when the light has visibly changed.
const Det = preload("res://addons/hatchery/core/det.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")

const MORNING := Color(1.0, 0.9, 0.82)
const EVENING := Color(0.62, 0.5, 0.66)

var plan: RefCounted
var job_seed: int = 0
## The tint applied to everything outside, from `light_at`.
var tint: Color = Color.WHITE


func setup(building: RefCounted, seed_value: int) -> void:
	plan = building
	job_seed = seed_value
	z_index = -1
	queue_redraw()


## The outside light at `progress` through the workday (0 start, 1 end).
static func light_at(progress: float) -> Color:
	if progress < 0.25:
		return MORNING.lerp(Color.WHITE, progress / 0.25)
	if progress < 0.7:
		return Color.WHITE
	return Color.WHITE.lerp(EVENING, (progress - 0.7) / 0.3)


func set_progress(progress: float) -> void:
	var wanted: Color = light_at(progress)
	if absf(wanted.r - tint.r) + absf(wanted.g - tint.g) + absf(wanted.b - tint.b) > 0.015:
		tint = wanted
		queue_redraw()


func _draw() -> void:
	if plan == null:
		return
	var sky: Color = Color(plan.colours.sky) * tint
	var reach: float = maxf(plan.width, 2000.0) * 2.0
	var top: float = plan.floor_y(plan.highest) - plan.floor_height * 4.0
	draw_rect(Rect2(-reach, top - 2000.0, plan.width + reach * 2.0, 2000.0 - top), sky)
	# Distant skyline: blocks a shade off the sky, seeded by the job; some
	# windows light up as the evening comes in.
	var rng: RandomNumberGenerator = Det.fork(job_seed, "skyline")
	var dusk: float = clampf((1.0 - tint.g) / 0.5, 0.0, 1.0)
	var x: float = -reach
	while x < plan.width + reach:
		var block_width: float = rng.randf_range(80.0, 220.0)
		var height: float = rng.randf_range(120.0, plan.floor_height * float(plan.highest + 2))
		var block := Rect2(x, -height, block_width - 10.0, height)
		draw_rect(block, sky.darkened(0.12 + rng.randf() * 0.1))
		var lit: int = rng.randi_range(0, 9)
		if dusk > 0.05:
			for row in range(int(height / 40.0)):
				if (row + lit) % 3 == 0:
					draw_rect(Rect2(x + 12.0, -height + 16.0 + row * 40.0, 14.0, 10.0), Color(1.0, 0.86, 0.5, dusk * 0.8))
		x += block_width
	var ground: Color = Color(plan.colours.exterior).darkened(0.45) * tint
	var depth: float = Balance.number("building.ground_depth") + plan.floor_height * float(1 - plan.lowest) + 600.0
	draw_rect(Rect2(-reach, 0.0, plan.width + reach * 2.0, depth), ground)
	draw_rect(Rect2(-reach, 0.0, plan.width + reach * 2.0, 10.0), ground.lightened(0.2))
