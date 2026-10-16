extends PanelContainer
## Top-right: the day, the time, the phase, and pause / 1x / 2x / 4x buttons.
## Big enough to tap. The keyboard shortcuts (P, 1, 2, 3) live in main.gd.
signal speed_chosen(scale: float)

const WorkClock = preload("res://scripts/sim/work_clock.gd")

const SPEEDS: Array[float] = [0.0, 1.0, 2.0, 4.0]
const SPEED_TEXT: Array[String] = ["||", "1x", "2x", "4x"]

var ui: RefCounted
var _time: Label
var _phase: Label
var _buttons: Array[Button] = []


func build(kit: RefCounted) -> void:
	ui = kit
	add_theme_stylebox_override("panel", ui.panel_box(0.88, 10))
	var column: VBoxContainer = ui.vbox(4)
	add_child(column)
	var top: HBoxContainer = ui.hbox(10)
	column.add_child(top)
	_time = ui.utility("", 22)
	top.add_child(_time)
	_phase = ui.label("", 15, ui.palette.muted)
	_phase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_phase)
	var row: HBoxContainer = ui.hbox(4)
	column.add_child(row)
	for i in range(SPEEDS.size()):
		var speed: float = SPEEDS[i]
		var button: Button = ui.button(SPEED_TEXT[i], func() -> void: speed_chosen.emit(speed), false, 15)
		button.custom_minimum_size = Vector2(52, 40)
		button.focus_mode = Control.FOCUS_NONE
		row.add_child(button)
		_buttons.append(button)


func show_clock(clock: RefCounted, running: bool) -> void:
	_time.text = "Day %d  %s" % [clock.day, WorkClock.hhmm(clock.minute)]
	_phase.text = clock.phase().capitalize() if running else "After hours"


func show_speed(scale: float) -> void:
	for i in range(_buttons.size()):
		var chosen: bool = is_equal_approx(SPEEDS[i], scale)
		_buttons[i].add_theme_stylebox_override("normal", ui.button_box("normal", chosen))
