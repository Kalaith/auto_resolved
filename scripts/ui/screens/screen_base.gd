extends Control
## A whole-screen page between jobs: the backdrop and a centred, scrolling
## column to build into. Subclasses fill `column` in `build_page`.

var ui: RefCounted
var column: VBoxContainer
var _scroll: ScrollContainer


func setup(kit: RefCounted) -> void:
	ui = kit
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ui.theme()
	ui.backdrop(self, Color("141a26"))
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(centre)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	centre.add_child(margin)
	column = ui.vbox(12)
	column.custom_minimum_size.x = 900
	margin.add_child(column)
	build_page()


## Override: add the page's content to `column`.
func build_page() -> void:
	pass


func rebuild() -> void:
	for child in column.get_children():
		child.queue_free()
	build_page()


func card(width: float = 0.0) -> VBoxContainer:
	var panel: PanelContainer = ui.panel(0.95, 14)
	if width > 0.0:
		panel.custom_minimum_size.x = width
	var inner: VBoxContainer = ui.vbox(6)
	panel.add_child(inner)
	return inner


func text(value: String, size: int = 16, color: Variant = null, width: float = 860.0) -> Label:
	var label: Label = ui.wrapped(value, size, ui.palette.text if color == null else color)
	label.custom_minimum_size.x = width
	return label
