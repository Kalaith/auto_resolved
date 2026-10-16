extends RefCounted
## How each fault looks on its device, drawn over room_props.gd's furniture
## at the same anchor (`at` is the device's feet on the floor covering). Every
## fault the catalogs can put on a device has a drawing here, so a PATCH
## mistake is always visible somewhere in the building.

## Where a desk PC's screen sits relative to its desk's feet (room_props.gd).
const SCREEN := Rect2(-4, -67, 28, 16)


static func draw_fault(canvas: CanvasItem, kind: String, fault: String, at: Vector2, time: float) -> void:
	match fault:
		"locked":
			_screen(canvas, at, Color("#2a3140"))
			_padlock(canvas, at + Vector2(10, -59))
		"no_account":
			_screen(canvas, at, Color("#3a3a46"))
			_text(canvas, at + Vector2(6, -54), "?", Color("#f2c94c"))
		"install":
			_screen(canvas, at, Color("#1f3a5a"))
			canvas.draw_rect(Rect2(at + Vector2(-1, -58), Vector2(22, 4)), Color("#14202e"))
			canvas.draw_rect(Rect2(at + Vector2(-1, -58), Vector2(22.0 * fmod(time * 0.15, 1.0), 4)), Color("#5ec4e8"))
		"slow":
			_screen(canvas, at, Color("#5a5f6b"))
			var spin: float = time * 1.5
			canvas.draw_arc(at + Vector2(10, -59), 5.0, spin, spin + PI * 1.4, 10, Color.WHITE, 2.0)
		"no_network":
			if kind == "network_core":
				_rack_alarm(canvas, at, time)
			else:
				_screen(canvas, at, Color("#3a1f24"))
				_cross(canvas, at + Vector2(10, -59), Color("#e0483e"))
		"offline":
			_printer_alarm(canvas, at, time)
		"confused":
			pass
		"crashed":
			_rack_alarm(canvas, at, time)
			_text(canvas, at + Vector2(-16, -124), "1997", Color("#f2c94c"), 12)
		"dark":
			_screen(canvas, at, Color("#08090c"))
		"admin":
			_crown(canvas, at + Vector2(10, -78))
		"paper_flood":
			_paper_flood(canvas, at, time)
		"wiped":
			_screen(canvas, at, Color("#e8e8e8"))
			_text(canvas, at + Vector2(1, -54), "C:\\", Color("#1c1c22"), 10)
		"bricked":
			_printer_alarm(canvas, at, time)
			_text(canvas, at + Vector2(-20, -70), "ERR 0x0", Color("#e0483e"), 11)


## The lift controller on the wall beside the ground-floor landing; amber and
## blinking while it is confused.
static func lift_panel(canvas: CanvasItem, at: Vector2, faulty: bool, time: float) -> void:
	var box := Rect2(at + Vector2(-8, -78), Vector2(16, 26))
	canvas.draw_rect(box, Color("#2a2f3a"))
	canvas.draw_rect(box, Color("#9aa3ad"), false, 1.5)
	var lamp: Color = Color("#5ee07a")
	if faulty:
		lamp = Color("#f2a030") if fmod(time, 0.5) < 0.25 else Color("#5a3a10")
	canvas.draw_circle(at + Vector2(0, -71), 3.0, lamp)
	canvas.draw_rect(Rect2(at + Vector2(-4, -64), Vector2(8, 8)), Color("#4a5160"))


static func _screen(canvas: CanvasItem, at: Vector2, colour: Color) -> void:
	canvas.draw_rect(Rect2(at + SCREEN.position, SCREEN.size), colour)


static func _padlock(canvas: CanvasItem, centre: Vector2) -> void:
	canvas.draw_arc(centre + Vector2(0, -2), 4.0, PI, TAU, 8, Color("#f2c94c"), 2.0)
	canvas.draw_rect(Rect2(centre + Vector2(-5, -2), Vector2(10, 7)), Color("#f2c94c"))


static func _cross(canvas: CanvasItem, centre: Vector2, colour: Color) -> void:
	canvas.draw_line(centre + Vector2(-5, -5), centre + Vector2(5, 5), colour, 2.0)
	canvas.draw_line(centre + Vector2(5, -5), centre + Vector2(-5, 5), colour, 2.0)


static func _crown(canvas: CanvasItem, centre: Vector2) -> void:
	var gold := Color("#f2c94c")
	canvas.draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-8, 4), centre + Vector2(-8, -4), centre + Vector2(-4, 0), centre + Vector2(0, -6),
		centre + Vector2(4, 0), centre + Vector2(8, -4), centre + Vector2(8, 4)]), gold)


static func _printer_alarm(canvas: CanvasItem, at: Vector2, time: float) -> void:
	var lit: bool = fmod(time, 0.7) < 0.4
	canvas.draw_circle(at + Vector2(18, -54), 3.5, Color("#e0483e") if lit else Color("#5a1f1c"))
	canvas.draw_rect(Rect2(at + Vector2(-15, -50), Vector2(30, 3)), Color("#2a2f3a"))


static func _rack_alarm(canvas: CanvasItem, at: Vector2, time: float) -> void:
	var lit: bool = fmod(time, 0.6) < 0.3
	for row in range(7):
		var y: float = at.y - 14.0 - row * 15.0
		canvas.draw_circle(Vector2(at.x + 13, y - 4), 2.5, Color("#e0483e") if lit or row % 2 == 0 else Color("#5a1f1c"))


## Paper spilling from the printer across the floor, growing and settling.
static func _paper_flood(canvas: CanvasItem, at: Vector2, time: float) -> void:
	_printer_alarm(canvas, at, time)
	for i in range(14):
		var drift: float = float(i) * 9.0 - 40.0 + sin(time * 2.0 + float(i)) * 3.0
		var height: float = 4.0 + float((i * 7) % 5) * 2.0
		canvas.draw_rect(Rect2(at + Vector2(drift, -height), Vector2(12, 3)), Color("#f8f8f8"))
	var flutter: float = fmod(time * 40.0, 60.0)
	canvas.draw_rect(Rect2(at + Vector2(-10 + flutter * 0.4, -60 + flutter), Vector2(10, 2)), Color("#ffffff"))


static func _text(canvas: CanvasItem, at: Vector2, value: String, colour: Color, size: int = 14) -> void:
	canvas.draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
