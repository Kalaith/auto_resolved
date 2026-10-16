extends RefCounted
## Placeholder people drawn from shapes, about a third of a floor tall, feet at
## the given point. Every look (skin, hair, trousers) is derived from the
## person's id, so the same employee always looks the same; the shirt is their
## department colour.

const SKINS: Array[String] = ["#f1c7a5", "#e9b996", "#c98f65", "#a86f4a", "#7a4e33", "#5a3a26"]
const HAIRS: Array[String] = ["#2b1d14", "#3b2a20", "#6b4a2a", "#b8863b", "#d9c27a", "#8a8a8a", "#a33b2a", "#1c1c22"]
const TROUSERS: Array[String] = ["#2f3442", "#3d3a36", "#24324a", "#4a4038", "#5b5f6b"]


static func look_for(id: String, shirt: Color) -> Dictionary:
	var h: int = absi(hash(id))
	return {
		"shirt": shirt,
		"skin": Color(SKINS[h % SKINS.size()]),
		"hair": Color(HAIRS[(h / 7) % HAIRS.size()]),
		"trousers": Color(TROUSERS[(h / 61) % TROUSERS.size()]),
		"long_hair": (h / 13) % 3 == 0,
		"glasses": (h / 29) % 4 == 0,
	}


## `walk_time` < 0 stands still; otherwise legs swing with it.
static func draw_standing(canvas: CanvasItem, feet: Vector2, look: Dictionary, facing: float, walk_time: float) -> void:
	var swing: float = sin(walk_time * 11.0) * 6.0 if walk_time >= 0.0 else 0.0
	var bob: float = absf(sin(walk_time * 11.0)) * 2.0 if walk_time >= 0.0 else 0.0
	var trousers: Color = look.trousers
	canvas.draw_line(feet + Vector2(-5, -30 - bob), feet + Vector2(-5 + swing, 0), trousers, 7.0)
	canvas.draw_line(feet + Vector2(5, -30 - bob), feet + Vector2(5 - swing, 0), trousers, 7.0)
	canvas.draw_rect(Rect2(feet + Vector2(-12, -62 - bob), Vector2(24, 34)), look.shirt)
	canvas.draw_rect(Rect2(feet + Vector2(-12, -62 - bob), Vector2(24, 4)), Color(look.shirt).darkened(0.2))
	_head(canvas, feet + Vector2(0, -74 - bob), look, facing)


static func draw_seated(canvas: CanvasItem, feet: Vector2, look: Dictionary, facing: float) -> void:
	var seat: Vector2 = feet + Vector2(0, -30)
	canvas.draw_line(seat + Vector2(-4 * facing, 0), seat + Vector2(16 * facing, 0), look.trousers, 8.0)
	canvas.draw_line(seat + Vector2(16 * facing, 0), feet + Vector2(16 * facing, 0), look.trousers, 6.0)
	canvas.draw_rect(Rect2(seat + Vector2(-12, -32), Vector2(24, 32)), look.shirt)
	_head(canvas, seat + Vector2(0, -44), look, facing)


static func _head(canvas: CanvasItem, centre: Vector2, look: Dictionary, facing: float) -> void:
	# Hair is a slightly larger circle behind the face, showing as a fringe on
	# top and, for long hair, a fall at the back.
	canvas.draw_circle(centre + Vector2(-2.0 * facing, -2.0), 11.5, look.hair)
	if look.long_hair:
		canvas.draw_rect(Rect2(centre + Vector2(-12 if facing > 0 else 4, -4), Vector2(8, 16)), look.hair)
	canvas.draw_circle(centre + Vector2(1.0 * facing, 1.5), 10.0, look.skin)
	if look.glasses:
		canvas.draw_line(centre + Vector2(-1 * facing, -1), centre + Vector2(9 * facing, -1), Color("#1c1c1c"), 2.0)
	else:
		canvas.draw_circle(centre + Vector2(5 * facing, -2), 1.5, Color("#1c1c1c"))
