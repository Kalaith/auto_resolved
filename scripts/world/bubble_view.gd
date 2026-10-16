extends Node2D
## Speech bubbles over the staff: complaints when something breaks or runs
## late, thanks when it is fixed, reactions to PATCH's incidents, and
## callbacks to incidents they remember ("Is PATCH printing again?"). Lines
## come from data/text_staff.json; which variant is picked is presentation
## only, so it uses its own generator. A bubble follows its speaker.
const CatalogPeople = preload("res://scripts/core/catalog_people.gd")
const Det = preload("res://addons/hatchery/core/det.gd")

const SECONDS: float = 3.6
const MAX_BUBBLES: int = 7
const WIDTH: float = 190.0

var office: RefCounted
## [{"who": employee id, "line": String, "left": seconds}]
var bubbles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _font: Font
var _late_said: Dictionary = {}
var _next_late_check: float = 0.0


func setup(sim: RefCounted) -> void:
	office = sim
	bubbles.clear()
	_late_said.clear()
	_rng.seed = hash(sim.job.seed_value)
	_font = ThemeDB.fallback_font
	z_index = 6


## Turns one office event into whatever people say about it.
func on_event(event: Dictionary) -> void:
	match str(event.type):
		"ticket_opened":
			var ticket: RefCounted = office.helpdesk.queue.get_ticket(int(event.ticket))
			if ticket != null:
				_ticket_opened(ticket)
		"ticket_resolved":
			var ticket: RefCounted = office.helpdesk.queue.get_ticket(int(event.ticket))
			if ticket != null and not ticket.reporter.is_empty():
				say(ticket.reporter, "staff.thanks.player" if event.by == "player" else "staff.thanks.patch")
		"incident_opened":
			for id in event.get("people", []).slice(0, 3):
				say(str(id), "staff.incident." + str(event.archetype))
		"manager_visit":
			say(str(event.employee), "staff.manager_visit")


func _ticket_opened(ticket: RefCounted) -> void:
	var person: RefCounted = office.employee(ticket.reporter)
	if person == null:
		var nearby: Array = office.present_staff().filter(func(item: RefCounted) -> bool: return item.desk_floor == ticket.floor_index)
		if not nearby.is_empty():
			say(Det.pick(_rng, nearby).id, "staff.ticket." + ticket.issue)
		return
	for note in person.history:
		if note.begins_with("incident:") and _rng.randf() < 0.5:
			say(person.id, "staff.remember." + note.trim_prefix("incident:"))
			return
	say(person.id, "staff.ticket." + ticket.issue)


## Shows a line from `key` (variants split by "|") over `who`.
func say(who: String, key: String) -> void:
	var text: RefCounted = CatalogPeople.staff_text
	if not text.has(key):
		return
	var person: RefCounted = office.employee(who)
	if person == null or not person.present:
		return
	var variants: PackedStringArray = text.label(key).split("|")
	var line: String = variants[_rng.randi_range(0, variants.size() - 1)]
	bubbles = bubbles.filter(func(item: Dictionary) -> bool: return item.who != who)
	bubbles.append({"who": who, "line": line, "left": SECONDS})
	while bubbles.size() > MAX_BUBBLES:
		bubbles.pop_front()


func _process(delta: float) -> void:
	if office == null:
		return
	for bubble in bubbles:
		bubble.left = float(bubble.left) - delta
	bubbles = bubbles.filter(func(item: Dictionary) -> bool: return float(item.left) > 0.0)
	_next_late_check -= delta
	if _next_late_check <= 0.0:
		_next_late_check = 4.0
		_complain_about_late()
	queue_redraw()


## Someone whose ticket has just gone overdue says so, once.
func _complain_about_late() -> void:
	var now: float = office.clock.stamp()
	for ticket in office.helpdesk.queue.open_tickets():
		if ticket.is_overdue(now) and not _late_said.has(ticket.id) and not ticket.reporter.is_empty():
			_late_said[ticket.id] = true
			say(ticket.reporter, "staff.late")
			return


func _draw() -> void:
	for bubble in bubbles:
		var person: RefCounted = office.employee(str(bubble.who))
		if person == null or not person.present:
			continue
		var head: Vector2 = person.walker.feet(office.plan, office.elevator) + Vector2(0.0, -118.0 if not person.at_desk() else -100.0)
		_bubble(head, str(bubble.line), clampf(float(bubble.left) / 0.4, 0.0, 1.0))


func _bubble(anchor: Vector2, line: String, alpha: float) -> void:
	var size: int = 13
	var lines: PackedStringArray = _wrap(line, size)
	var height: float = float(lines.size()) * 16.0 + 10.0
	var width: float = 0.0
	for part in lines:
		width = maxf(width, _font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	width += 16.0
	var box := Rect2(anchor.x - width * 0.5, anchor.y - height, width, height)
	var paper := Color(1.0, 1.0, 0.98, 0.95 * alpha)
	draw_rect(box.grow(1.5), Color(0.1, 0.1, 0.14, 0.6 * alpha))
	draw_rect(box, paper)
	draw_colored_polygon(PackedVector2Array([anchor + Vector2(-6, 0), anchor + Vector2(6, 0), anchor + Vector2(0, 9)]), paper)
	for i in range(lines.size()):
		draw_string(_font, Vector2(box.position.x + 8.0, box.position.y + 17.0 + i * 16.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.12, 0.12, 0.16, alpha))


func _wrap(line: String, size: int) -> PackedStringArray:
	var result: PackedStringArray = []
	var current: String = ""
	for word in line.split(" "):
		var trial: String = word if current.is_empty() else current + " " + word
		if _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > WIDTH and not current.is_empty():
			result.append(current)
			current = word
		else:
			current = trial
	if not current.is_empty():
		result.append(current)
	return result
