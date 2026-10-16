extends PanelContainer
## The compact queue under the clock: management's confidence, staff
## productivity and the open tickets, most urgent first. Tapping a ticket sends
## the player to the nearest place it can be fixed.
signal ticket_chosen(id: int)
signal patch_asked(id: int)

const Catalog = preload("res://scripts/core/catalog.gd")
const BuildingView = preload("res://scripts/world/building_view.gd")

const ROWS: int = 7

var ui: RefCounted
var _confidence: ProgressBar
var _confidence_text: Label
var _summary: Label
var _rows: VBoxContainer
var _more: Label
var _buttons: Array[Button] = []
var _asks: Array[Button] = []
var _ids: Array[int] = []


func build(kit: RefCounted) -> void:
	ui = kit
	add_theme_stylebox_override("panel", ui.panel_box(0.88, 10))
	custom_minimum_size = Vector2(330, 0)
	var column: VBoxContainer = ui.vbox(6)
	add_child(column)
	var top: HBoxContainer = ui.hbox(8)
	column.add_child(top)
	_confidence_text = ui.label("", 14)
	top.add_child(_confidence_text)
	_confidence = ui.meter(60.0, 100.0, 120.0)
	_confidence.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_confidence)
	_summary = ui.label("", 13, ui.palette.muted)
	column.add_child(_summary)
	_rows = ui.vbox(3)
	column.add_child(_rows)
	for i in range(ROWS):
		var index: int = i
		var line: HBoxContainer = ui.hbox(3)
		_rows.add_child(line)
		var button: Button = ui.button("", func() -> void: _choose(index), false, 13)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(270, 34)
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		line.add_child(button)
		_buttons.append(button)
		var ask: Button = ui.button("AI", func() -> void: _ask(index), false, 12)
		ask.custom_minimum_size = Vector2(38, 34)
		ask.focus_mode = Control.FOCUS_NONE
		ask.tooltip_text = "Ask PATCH about this ticket"
		line.add_child(ask)
		_asks.append(ask)
	_more = ui.label("", 12, ui.palette.muted)
	column.add_child(_more)


func show_office(office: RefCounted) -> void:
	var metrics: RefCounted = office.metrics
	_confidence_text.text = "Confidence %d" % roundi(metrics.confidence)
	_confidence.value = metrics.confidence
	_confidence.add_theme_stylebox_override("fill", ui.box(ui.palette.level_color(metrics.confidence / 100.0), Color(0, 0, 0, 0), 4, 0))
	var tickets: Array = office.helpdesk.queue.by_urgency()
	_summary.text = "%d open   Staff working at %d%%" % [tickets.size(), roundi(metrics.productivity * 100.0)]
	var now: float = office.clock.stamp()
	_ids.clear()
	for i in range(ROWS):
		var button: Button = _buttons[i]
		button.get_parent().visible = i < tickets.size()
		if i >= tickets.size():
			continue
		var ticket: RefCounted = tickets[i]
		_ids.append(ticket.id)
		button.text = _row_text(office, ticket, now)
		button.add_theme_color_override("font_color", _urgency_colour(ticket, now))
	_more.visible = tickets.size() > ROWS
	_more.text = "+%d more" % (tickets.size() - ROWS)


func _row_text(office: RefCounted, ticket: RefCounted, now: float) -> String:
	var device: RefCounted = office.device(ticket.device_id)
	var where: String = BuildingView.floor_name(ticket.floor_index if device == null else device.floor_index)
	var left: float = ticket.minutes_left(now)
	var due: String = "LATE" if left < 0.0 else "%dm" % int(left)
	var who: String = ""
	var reporter: RefCounted = office.employee(ticket.reporter)
	if reporter != null:
		who = " - " + reporter.name.get_slice(" ", 0)
	var state: String = " [fixing]" if ticket.status == "in_progress" else ""
	return "#%d %s  F%s%s  %s%s" % [ticket.id, str(Catalog.issue(ticket.issue).label), where, who, due, state]


func _urgency_colour(ticket: RefCounted, now: float) -> Color:
	if ticket.is_overdue(now):
		return ui.palette.bad
	if ticket.minutes_left(now) < (ticket.deadline - ticket.created) * 0.35:
		return ui.palette.warn
	return ui.palette.text


func _choose(index: int) -> void:
	if index < _ids.size():
		ticket_chosen.emit(_ids[index])


func _ask(index: int) -> void:
	if index < _ids.size():
		patch_asked.emit(_ids[index])
