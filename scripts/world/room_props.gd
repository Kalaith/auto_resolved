extends RefCounted
## Placeholder furniture drawn from shapes, coloured from the job's theme, so a
## new company reads differently before any sprite art exists. Each prop is
## drawn with its feet at `at` (a point on the floor line). Swap a function's
## body for a sprite later; the prop ids and layout stay.
const RoomLayout = preload("res://scripts/sim/room_layout.gd")

const WINDOW_SIZE := Vector2(64.0, 74.0)


## Draws one room's props where RoomLayout puts them: windows high on the back
## wall, everything else standing on the floor. Basements have no windows.
static func draw_room(canvas: CanvasItem, room: Dictionary, floor_line: float, colours: Dictionary) -> void:
	for x in RoomLayout.windows(room):
		draw_prop(canvas, "window", Vector2(x, floor_line - 112.0), colours, room.wall)
	for item in RoomLayout.standing(room):
		draw_prop(canvas, str(item.prop), Vector2(float(item.x), floor_line), colours, room.wall)


static func draw_prop(canvas: CanvasItem, prop: String, at: Vector2, colours: Dictionary, wall: Color) -> void:
	var wood: Color = colours.furniture
	var accent: Color = colours.accent
	match prop:
		"window": _window(canvas, at, colours)
		"reception_desk":
			_box(canvas, at, Vector2(96, 42), wood)
			_box(canvas, at + Vector2(0, -30), Vector2(96, 8), accent)
		"plant": _plant(canvas, at)
		"couch":
			_box(canvas, at, Vector2(84, 22), accent.darkened(0.15))
			_box(canvas, at + Vector2(0, -20), Vector2(84, 22), accent)
			_box(canvas, at + Vector2(-38, -6), Vector2(10, 30), accent.darkened(0.3))
			_box(canvas, at + Vector2(38, -6), Vector2(10, 30), accent.darkened(0.3))
		"desk_pc": _desk(canvas, at, wood, accent)
		"server_rack": _rack(canvas, at)
		"whiteboard":
			_box(canvas, at + Vector2(0, -92), Vector2(76, 48), Color("#9aa3ad"))
			_box(canvas, at + Vector2(0, -96), Vector2(70, 40), Color("#f7f8fa"))
			canvas.draw_line(at + Vector2(-24, -116), at + Vector2(10, -110), accent, 2.0)
		"table":
			_box(canvas, at + Vector2(0, -34), Vector2(76, 7), wood)
			_box(canvas, at + Vector2(-30, 0), Vector2(5, 34), wood.darkened(0.2))
			_box(canvas, at + Vector2(30, 0), Vector2(5, 34), wood.darkened(0.2))
		"fridge":
			_box(canvas, at, Vector2(38, 86), Color("#dfe4ea"))
			canvas.draw_line(at + Vector2(-19, -56), at + Vector2(19, -56), Color("#aab3bd"), 2.0)
		"water_cooler":
			_box(canvas, at, Vector2(22, 44), Color("#e8ecef"))
			_box(canvas, at + Vector2(0, -44), Vector2(18, 24), Color("#7cc4f2", 0.85))
		"printer": _printer(canvas, at, wood)
		"bookshelf": _shelf(canvas, at, wood, accent, wall)
		"vending":
			_box(canvas, at, Vector2(50, 100), accent.darkened(0.2))
			_box(canvas, at + Vector2(-6, -24), Vector2(28, 64), Color("#2a3140"))
			for row in range(4):
				_box(canvas, at + Vector2(-6, -30 - row * 15), Vector2(24, 4), Color.from_hsv(0.08 * row, 0.6, 0.95))


## A rectangle standing on `feet` (bottom centre).
static func _box(canvas: CanvasItem, feet: Vector2, size: Vector2, colour: Color) -> void:
	canvas.draw_rect(Rect2(feet.x - size.x * 0.5, feet.y - size.y, size.x, size.y), colour)


static func _window(canvas: CanvasItem, centre: Vector2, colours: Dictionary) -> void:
	var rect := Rect2(centre - WINDOW_SIZE * 0.5, WINDOW_SIZE)
	canvas.draw_rect(rect.grow(5.0), colours.trim)
	canvas.draw_rect(rect, Color(colours.sky).lightened(0.2))
	canvas.draw_line(Vector2(rect.position.x + 10, rect.end.y - 10), Vector2(rect.position.x + 30, rect.position.y + 12), Color(1, 1, 1, 0.35), 3.0)
	canvas.draw_line(Vector2(centre.x, rect.position.y), Vector2(centre.x, rect.end.y), colours.trim, 3.0)
	canvas.draw_line(Vector2(rect.position.x, centre.y), Vector2(rect.end.x, centre.y), colours.trim, 3.0)


static func _plant(canvas: CanvasItem, at: Vector2) -> void:
	_box(canvas, at, Vector2(20, 22), Color("#b5693f"))
	var leaf := Color("#4f9a52")
	for offset in [Vector2(0, -40), Vector2(-10, -32), Vector2(10, -32), Vector2(-5, -48), Vector2(6, -46)]:
		canvas.draw_circle(at + offset, 9.0, leaf)
	canvas.draw_circle(at + Vector2(-2, -38), 6.0, leaf.lightened(0.2))


static func _desk(canvas: CanvasItem, at: Vector2, wood: Color, accent: Color) -> void:
	# Chair behind the desk edge, then desk, then monitor.
	_box(canvas, at + Vector2(-14, -2), Vector2(20, 30), Color("#30343f"))
	_box(canvas, at + Vector2(-14, -2), Vector2(4, 8), Color("#1d2028"))
	_box(canvas, at + Vector2(0, -36), Vector2(74, 6), wood)
	_box(canvas, at + Vector2(-32, 0), Vector2(5, 36), wood.darkened(0.25))
	_box(canvas, at + Vector2(32, 0), Vector2(5, 36), wood.darkened(0.25))
	_box(canvas, at + Vector2(10, -42), Vector2(6, 8), Color("#22252d"))
	_box(canvas, at + Vector2(10, -48), Vector2(34, 22), Color("#22252d"))
	_box(canvas, at + Vector2(10, -51), Vector2(28, 16), accent.lightened(0.45))


static func _rack(canvas: CanvasItem, at: Vector2) -> void:
	_box(canvas, at, Vector2(44, 118), Color("#1f232b"))
	for row in range(7):
		var y: float = at.y - 14.0 - row * 15.0
		canvas.draw_rect(Rect2(at.x - 18, y - 9, 36, 10), Color("#2e3440"))
		canvas.draw_circle(Vector2(at.x + 13, y - 4), 2.0, Color("#5ee07a") if row % 3 != 1 else Color("#f2b84b"))


static func _printer(canvas: CanvasItem, at: Vector2, wood: Color) -> void:
	_box(canvas, at, Vector2(46, 34), wood.darkened(0.1))
	_box(canvas, at + Vector2(0, -34), Vector2(52, 30), Color("#d9dde3"))
	_box(canvas, at + Vector2(0, -64), Vector2(40, 6), Color("#bfc5cd"))
	_box(canvas, at + Vector2(0, -42), Vector2(30, 3), Color("#f8f8f8"))
	canvas.draw_circle(at + Vector2(18, -54), 2.5, Color("#5ee07a"))


static func _shelf(canvas: CanvasItem, at: Vector2, wood: Color, accent: Color, wall: Color) -> void:
	_box(canvas, at, Vector2(56, 112), wood)
	for row in range(3):
		var base: float = at.y - 8.0 - row * 34.0
		canvas.draw_rect(Rect2(at.x - 24, base - 28, 48, 28), wall.darkened(0.35))
		for book in range(5):
			var tint: Color = accent if (row + book) % 3 == 0 else wall.darkened(0.15 + 0.1 * (book % 2))
			canvas.draw_rect(Rect2(at.x - 22 + book * 9, base - 24 + (book % 2) * 3, 7, 24 - (book % 2) * 3), tint)
