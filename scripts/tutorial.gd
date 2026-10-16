extends Node
## The day-1 tutorial on a career's first job. Each step explains one thing
## and finishes when the player does it (or taps "Got it" where that makes
## sense); the whole thing can be skipped. It only reads the office and the
## events main.gd passes on; it never changes the simulation.
const CatalogTutorial = preload("res://scripts/core/catalog_tutorial.gd")
const BuildingPlan = preload("res://scripts/sim/building_plan.gd")

## Steps the player can wave through with "Got it"; the rest wait for play.
const ACKNOWLEDGE: Array[String] = ["welcome", "capacity", "patch", "automate", "needs", "end"]

var main: Node
var panel: Control
var active: bool = false
var _index: int = 0
var _start_floor: int = 0


func start() -> void:
	active = true
	_index = -1
	_start_floor = main.player.floor_index
	_advance()


func stop() -> void:
	active = false
	panel.visible = false


func step_id() -> String:
	return CatalogTutorial.STEPS[_index] if active and _index >= 0 and _index < CatalogTutorial.STEPS.size() else ""


func _advance() -> void:
	_index += 1
	if _index >= CatalogTutorial.STEPS.size():
		stop()
		return
	var id: String = step_id()
	var office: RefCounted = main.office
	var desks: Array = office.devices_of("it_desk")
	var args: Dictionary = {"company": office.job.company_name,
		"it_floor": BuildingPlan.floor_name(desks[0].floor_index) if not desks.is_empty() else "?"}
	var text: RefCounted = CatalogTutorial.text
	panel.show_step(text.format("tutorial.%s.title" % id, args), text.format("tutorial.%s.body" % id, args),
		_index, CatalogTutorial.STEPS.size(), ACKNOWLEDGE.has(id))


func acknowledge() -> void:
	if active:
		_advance()


## Checks each frame whether the current step is done.
func update() -> void:
	if not active or main.office == null:
		return
	match step_id():
		"welcome":
			if main.player.floor_index != _start_floor:
				_advance()
		"go_to_it":
			if main.office.worker.at_it():
				_advance()
		"needs":
			if main.office.worker.hunger <= 0.5:
				_advance()


func on_event(event: Dictionary) -> void:
	if not active:
		return
	match step_id():
		"first_ticket":
			if event.type == "ticket_resolved" and event.by == "player":
				_advance()
		"patch":
			if event.type == "patch_executed":
				_advance()
		"automate":
			if event.type == "automation_installed":
				_advance()
		"end":
			if event.type == "day_ended":
				stop()
