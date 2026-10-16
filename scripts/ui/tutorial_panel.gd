extends PanelContainer
## The tutorial's card, low in the middle of the screen so the building stays
## visible: a title, a line or two, "Got it" (or a hint of what finishes the
## step) and "Skip tutorial". Never blocks movement.
signal acknowledged
signal skipped

var ui: RefCounted
var _title: Label
var _body: Label
var _next: Button
var _step: Label


func build(kit: RefCounted) -> void:
	ui = kit
	add_theme_stylebox_override("panel", _accent_panel())
	custom_minimum_size = Vector2(560, 0)
	var column: VBoxContainer = ui.vbox(6)
	add_child(column)
	var top: HBoxContainer = ui.hbox(8)
	column.add_child(top)
	_title = ui.heading("", 20)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_step = ui.label("", 13, ui.palette.muted)
	top.add_child(_step)
	_body = ui.wrapped("", 15, ui.palette.text)
	_body.custom_minimum_size.x = 536
	column.add_child(_body)
	var row: HBoxContainer = ui.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(row)
	var skip: Button = ui.button("Skip tutorial", func() -> void: skipped.emit(), false, 13)
	skip.focus_mode = Control.FOCUS_NONE
	skip.custom_minimum_size.y = 36
	row.add_child(skip)
	_next = ui.button("Got it", func() -> void: acknowledged.emit(), true, 14)
	_next.focus_mode = Control.FOCUS_NONE
	_next.custom_minimum_size = Vector2(110, 36)
	row.add_child(_next)
	visible = false


func _accent_panel() -> StyleBoxFlat:
	var style: StyleBoxFlat = ui.panel_box(0.95, 14)
	style.border_color = ui.palette.accent
	style.set_border_width_all(2)
	return style


## `can_skip_step` shows "Got it"; otherwise the step waits for the player.
func show_step(title: String, body: String, index: int, count: int, can_skip_step: bool) -> void:
	_title.text = title
	_body.text = body
	_step.text = "%d / %d" % [index + 1, count]
	_next.visible = can_skip_step
	visible = true
	reset_size()
	# Left of centre, so the PATCH panel (bottom right) never covers it.
	offset_left = -size.x * 0.5 - 150.0
	offset_right = size.x * 0.5 - 150.0
	offset_top = -size.y - 60.0
	offset_bottom = -60.0
