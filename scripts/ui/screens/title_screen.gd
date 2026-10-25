extends "res://scripts/ui/screens/screen_base.gd"
## The title: the premise in two lines, Continue career (with where it
## stands), New career, and Settings.
const TitleBackdrop = preload("res://scripts/ui/screens/title_backdrop.gd")

signal continue_chosen
signal new_chosen
signal settings_chosen

## A short line about the saved career, or "" when there is none.
var saved: String = ""
var problem: String = ""


func build_page() -> void:
	column.add_child(ui.heading("AUTO-RESOLVED", 44))
	column.add_child(text("It is your first week in IT, and the same week PATCH v1.0 ships: \"your new IT colleague\". " +
		"Keep the building running, decide how much to trust PATCH, and carry it from job to job.", 18, ui.palette.muted, 470.0))
	var buttons: VBoxContainer = ui.vbox(10)
	buttons.custom_minimum_size.x = 360
	column.add_child(buttons)
	if not saved.is_empty():
		buttons.add_child(ui.button("Continue career", func() -> void: continue_chosen.emit(), true))
		column.add_child(text(saved, 15, ui.palette.muted, 470.0))
	buttons.add_child(ui.button("New career", func() -> void: new_chosen.emit(), saved.is_empty()))
	buttons.add_child(ui.button("Settings", func() -> void: settings_chosen.emit()))
	if not problem.is_empty():
		column.add_child(text(problem, 14, ui.palette.warn, 470.0))
	column.add_child(text("Mouse or touch: tap to walk and to use things. Keyboard: A/D walk, E use, W/S pick a floor in the lift, P pause, Tab overview.", 13, ui.palette.muted, 470.0))


func setup(kit: RefCounted) -> void:
	super.setup(kit)
	var art: Control = TitleBackdrop.mount(self)
	move_child(art, _scroll.get_index())
	_scroll.anchor_right = 0.46
	column.custom_minimum_size.x = 470
