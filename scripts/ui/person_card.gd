extends PanelContainer
## A small card about one employee, opened by clicking them: name, department,
## what they are doing, how they feel, and their IT history. It refreshes while
## open and never blocks movement.

var ui: RefCounted
var person: RefCounted
var _name: Label
var _body: Label


func build(kit: RefCounted) -> void:
	ui = kit
	add_theme_stylebox_override("panel", ui.panel_box(0.92, 12))
	custom_minimum_size = Vector2(300, 0)
	var column: VBoxContainer = ui.vbox(6)
	add_child(column)
	var top: HBoxContainer = ui.hbox(8)
	column.add_child(top)
	_name = ui.heading("", 20)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name)
	var close: Button = ui.button("X", func() -> void: close_card(), false, 14)
	close.custom_minimum_size = Vector2(40, 36)
	close.focus_mode = Control.FOCUS_NONE
	top.add_child(close)
	_body = ui.wrapped("", 14, ui.palette.text)
	_body.custom_minimum_size.x = 276
	column.add_child(_body)
	visible = false


func open_for(who: RefCounted) -> void:
	person = who
	visible = true
	refresh(null)


func close_card() -> void:
	person = null
	visible = false


## `office` may be null; with it, the card can name open tickets.
func refresh(office: RefCounted) -> void:
	if person == null:
		return
	_name.text = person.full_name()
	var lines: Array[String] = []
	lines.append("%s - %s" % [person.department_label, "manager" if person.role == "manager" else "staff"])
	lines.append("Now: %s" % _doing())
	lines.append("Mood: %s   Productivity: %d%%" % [person.mood_word(), roundi(person.productivity * 100.0)])
	lines.append("Tech confidence: %s   Patience: %s" % [_grade(person.tech_confidence), _grade(person.patience)])
	if office != null and office.has_method("tickets_for_person"):
		for ticket in office.tickets_for_person(person.id):
			lines.append("Waiting on: #%d %s" % [ticket.id, ticket.title])
	if not person.history.is_empty():
		lines.append("Remembers: " + ", ".join(person.history.slice(-3)))
	_body.text = "\n".join(lines)


func _doing() -> String:
	match person.activity:
		"home":
			return "not in the building"
		"arriving":
			return "arriving"
		"working":
			return "working at their desk"
		"walking", "visiting":
			return {"printer": "at the printer", "meeting": "in a meeting", "kitchen": "in the kitchen", "break": "on a break", "visit_it": "having a word with IT about confidence"}.get(person.errand, "on an errand")
		"returning":
			return "heading back to their desk"
		"leaving":
			return "going home"
	return person.activity


static func _grade(value: float) -> String:
	if value >= 0.7:
		return "high"
	if value >= 0.4:
		return "medium"
	return "low"
