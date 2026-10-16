extends CanvasLayer
## The small persistent HUD: who you work for and what they pay, where you are,
## the clock and speed, and the controls; plus the cards that open over the
## office (an employee, the end of a day). Data problems found at startup
## replace it with a readable list. UI text stays ASCII for the web font.
const Palette = preload("res://addons/hatchery/ui/palette.gd")
const UiKit = preload("res://addons/hatchery/ui/ui_kit.gd")
const BuildingView = preload("res://scripts/world/building_view.gd")
const ClockBar = preload("res://scripts/ui/clock_bar.gd")
const PersonCard = preload("res://scripts/ui/person_card.gd")
const NoticePanel = preload("res://scripts/ui/notice_panel.gd")

const HINT: String = "A/D walk   E use / call / go   W/S pick floor   Click to send   Tab overview   P pause   1-3 speed"

var ui: UiKit
var root: Control
var clock_bar: ClockBar
var person_card: PersonCard
var notice: NoticePanel
var _company: Label
var _details: Label
var _where: Label
var _hint: Label
var _top: PanelContainer


func _ready() -> void:
	ui = UiKit.new(Palette.new())
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ui.theme()
	add_child(root)
	_top = ui.panel(0.88)
	_top.position = Vector2(16, 16)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_top)
	var column: VBoxContainer = ui.vbox(4)
	_top.add_child(column)
	_company = ui.heading("", 22)
	_details = ui.label("", 15, ui.palette.muted)
	_where = ui.label("", 15)
	for label in [_company, _details, _where]:
		column.add_child(label)
	_hint = ui.label(HINT, 13, ui.palette.muted)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 16.0
	_hint.offset_top = -34.0
	_hint.offset_bottom = -12.0
	root.add_child(_hint)
	clock_bar = ClockBar.new()
	clock_bar.build(ui)
	clock_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	clock_bar.offset_right = -16.0
	clock_bar.offset_top = 16.0
	root.add_child(clock_bar)
	person_card = PersonCard.new()
	person_card.build(ui)
	person_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	person_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	person_card.offset_left = 16.0
	person_card.offset_bottom = -48.0
	root.add_child(person_card)
	notice = NoticePanel.new()
	notice.build(ui)
	root.add_child(notice)


func show_job(job: RefCounted, plan: RefCounted) -> void:
	_company.text = job.company_name
	var floors: String = "%d floors%s" % [plan.highest + 1, " + basement" if plan.lowest < 0 else ""]
	_details.text = "%s   Tier %d   $%d / day   %s" % [job.label(), job.tier, job.pay_per_day, floors]
	_top.add_theme_stylebox_override("panel", _accent_box(plan.colours.accent))
	person_card.close_card()


func show_position(player: Node2D, elevator: RefCounted) -> void:
	var floor_text: String = BuildingView.floor_name(player.floor_index)
	if player.riding:
		var heading: String = "riding" if elevator.is_moving() else "in the car"
		_where.text = "Floor %s - %s - send to %s with E" % [floor_text, heading, BuildingView.floor_name(player.selected_floor)]
	else:
		_where.text = "Floor %s%s" % [floor_text, " - at the elevator" if player.at_shaft() else ""]


func show_problems(problems: Array[String]) -> void:
	_company.text = "Data problems"
	_details.text = "\n".join(problems.slice(0, 12))
	_where.text = "See the console for the full list."


## True when a point on screen is over a visible HUD control, so a click
## there does not also send the player walking.
func covers(screen_point: Vector2) -> bool:
	for control in _blocking_controls():
		if control.visible and control.get_global_rect().has_point(screen_point):
			return true
	return false


func _blocking_controls() -> Array[Control]:
	return [clock_bar, person_card, notice]


func _accent_box(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = ui.panel_box(0.88)
	style.border_color = accent
	style.set_border_width_all(0)
	style.border_width_left = 5
	return style
