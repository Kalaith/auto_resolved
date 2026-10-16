extends PanelContainer
## A centred card for moments that need a decision: the end of a workday, a
## warning from management, handing in notice. A title, a body and a row of
## buttons; each button closes the card and runs its callback.

var ui: RefCounted
var _title: Label
var _body: Label
var _buttons: HBoxContainer


func build(kit: RefCounted) -> void:
	ui = kit
	add_theme_stylebox_override("panel", ui.panel_box(0.96, 18))
	custom_minimum_size = Vector2(520, 0)
	set_anchors_preset(Control.PRESET_CENTER)
	var column: VBoxContainer = ui.vbox(12)
	add_child(column)
	_title = ui.heading("", 26)
	column.add_child(_title)
	_body = ui.wrapped("", 16, ui.palette.text)
	_body.custom_minimum_size.x = 480
	column.add_child(_body)
	_buttons = ui.hbox(10)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_buttons)
	visible = false


## `choices` is [[text, Callable, primary?], ...].
func open(title: String, body: String, choices: Array) -> void:
	_title.text = title
	_body.text = body
	for child in _buttons.get_children():
		child.queue_free()
	for choice in choices:
		var callback: Callable = choice[1]
		var primary: bool = choice.size() > 2 and bool(choice[2])
		var button: Button = ui.button(str(choice[0]), func() -> void:
			visible = false
			callback.call(), primary)
		_buttons.add_child(button)
	visible = true
	reset_size()
	call_deferred("_centre")


func _centre() -> void:
	reset_size()
	var view: Vector2 = get_viewport_rect().size
	position = (view - size) * 0.5
