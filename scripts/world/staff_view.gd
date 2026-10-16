extends Node2D
## Draws the staff from the office sim. Two instances share this script, like
## the elevator: RIDING draws people inside the car (behind its doors) and
## WALKING everyone else (in front of the building). People at their desks are
## drawn seated; a dot over the head shows their mood.
const FigureArt = preload("res://scripts/world/figure_art.gd")

enum Layer { RIDING, WALKING }

const PICK_RADIUS: float = 26.0

var layer: Layer = Layer.WALKING
var office: RefCounted
var _time: float = 0.0


func setup(sim: RefCounted, which: Layer) -> void:
	office = sim
	layer = which


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if office == null:
		return
	for person in office.staff:
		if not person.present or person.walker.riding != (layer == Layer.RIDING):
			continue
		var feet: Vector2 = person.walker.feet(office.plan, office.elevator) + Vector2(0.0, -10.0)
		var look: Dictionary = FigureArt.look_for(person.id, person.colour)
		if person.at_desk():
			FigureArt.draw_seated(self, feet, look, 1.0)
		else:
			FigureArt.draw_standing(self, feet, look, person.walker.facing, _time if person.walker.moving else -1.0)
		if layer == Layer.WALKING:
			_draw_mood(person, feet + Vector2(0.0, -96.0 if not person.at_desk() else -78.0))


func _draw_mood(person: RefCounted, at: Vector2) -> void:
	var tint: Color = Color("#5ec46a")
	if person.mood < 0.25:
		tint = Color("#e0483e")
	elif person.mood < 0.45:
		tint = Color("#f0a030")
	elif person.mood < 0.7:
		tint = Color("#d8d36a")
	draw_circle(at, 4.0, Color(0, 0, 0, 0.5))
	draw_circle(at, 3.0, tint)


## The present employee whose figure covers world point `at`, or null.
func employee_at(at: Vector2) -> RefCounted:
	var best: RefCounted = null
	var best_distance: float = PICK_RADIUS
	for person in office.staff:
		if not person.present:
			continue
		var feet: Vector2 = person.walker.feet(office.plan, office.elevator)
		var centre: Vector2 = feet + Vector2(0.0, -48.0 if not person.at_desk() else -40.0)
		var distance: float = Vector2((at.x - centre.x) * 1.6, (at.y - centre.y) * 0.6).length()
		if distance < best_distance:
			best_distance = distance
			best = person
	return best
