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
const TicketPanel = preload("res://scripts/ui/ticket_panel.gd")
const PatchPanel = preload("res://scripts/ui/patch_panel.gd")
const IncidentPanel = preload("res://scripts/ui/incident_panel.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

const TOAST_SECONDS: float = 3.5

const HINT: String = "A/D walk   E use / call / go   W/S pick floor   Click to send   Tab overview   P pause   1-3 speed"

var ui: UiKit
var root: Control
var clock_bar: ClockBar
var person_card: PersonCard
var notice: NoticePanel
var tickets: TicketPanel
var patch_panel: PatchPanel
var patch_button: Button
var incidents: IncidentPanel
## The single high-priority alert: an active incident. Tap to open it.
var alert: Button
var _toast: Label
var _toast_left: float = 0.0
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
	tickets = TicketPanel.new()
	tickets.build(ui)
	tickets.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tickets.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tickets.offset_right = -16.0
	tickets.offset_top = 124.0
	root.add_child(tickets)
	_toast = ui.label("", 17)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_top = 20.0
	_toast.visible = false
	root.add_child(_toast)
	person_card = PersonCard.new()
	person_card.build(ui)
	person_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	person_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	person_card.offset_left = 16.0
	person_card.offset_bottom = -48.0
	root.add_child(person_card)
	patch_panel = PatchPanel.new()
	patch_panel.build(ui)
	patch_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	patch_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	patch_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	patch_panel.offset_right = -16.0
	patch_panel.offset_bottom = -16.0
	patch_panel.closed.connect(func() -> void:
		tickets.visible = true
		patch_button.visible = true)
	root.add_child(patch_panel)
	patch_button = ui.button("PATCH", Callable(), true, 18)
	patch_button.custom_minimum_size = Vector2(120, 52)
	patch_button.focus_mode = Control.FOCUS_NONE
	patch_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	patch_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	patch_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	patch_button.offset_right = -16.0
	patch_button.offset_bottom = -16.0
	root.add_child(patch_button)
	incidents = IncidentPanel.new()
	incidents.build(ui)
	incidents.position = Vector2(16, 130)
	root.add_child(incidents)
	alert = ui.button("", Callable(), true, 15)
	alert.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert.grow_horizontal = Control.GROW_DIRECTION_BOTH
	alert.offset_top = 56.0
	alert.focus_mode = Control.FOCUS_NONE
	alert.add_theme_color_override("font_color", ui.palette.bad)
	alert.visible = false
	root.add_child(alert)
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


## A one-line message at the top of the screen that fades on its own.
func toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_left = TOAST_SECONDS


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.6, 0.0, 1.0)
		_toast.visible = _toast_left > 0.0


## Opens PATCH (on a ticket's proposal when `ticket_id` is set); the ticket
## panel steps aside while it is open.
func open_patch(office: RefCounted, ticket_id: int = -1) -> void:
	tickets.visible = false
	patch_button.visible = false
	if ticket_id >= 0:
		patch_panel.ask_about_ticket(office, ticket_id)
	else:
		patch_panel.open_for(office)


## Shows the newest active incident as the one alert, if there is any.
func show_alert(office: RefCounted) -> void:
	var active: Array = office.patch_desk.active_incidents()
	alert.visible = not active.is_empty() and not incidents.visible
	if alert.visible:
		var newest: RefCounted = active[active.size() - 1]
		var more: String = "  (+%d more)" % (active.size() - 1) if active.size() > 1 else ""
		alert.text = "INCIDENT: PATCH managed to %s%s" % [Catalog.say("backfire.%s.label" % newest.backfire_id), more]


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
	return [clock_bar, person_card, notice, tickets, patch_panel, patch_button, incidents, alert]


func _accent_box(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = ui.panel_box(0.88)
	style.border_color = accent
	style.set_border_width_all(0)
	style.border_width_left = 5
	return style
