extends VBoxContainer
## The proposal card (GDD 13): what PATCH will do, who is affected, the
## benefit, what could go wrong (a risk band, never a hidden number) and the
## protections, with scope and safeguard switches and the four answers:
## Approve, Test safely, Ask for a safer plan, Cancel.
signal finished

const Catalog = preload("res://scripts/core/catalog.gd")
const BuildingPlan = preload("res://scripts/sim/building_plan.gd")

const SAFEGUARD_NAMES: Dictionary = {
	"staged": "Staged rollout", "dry_run": "Dry run first", "backup": "Backup first",
	"confirm_delete": "Confirm deletes", "change_cap": "Change cap (2 devices)",
}

var ui: RefCounted
var office: RefCounted
var proposal: RefCounted
var _answers: VBoxContainer
var _options: VBoxContainer
## The four answers, kept outside the card so the panel can pin them below
## its scrolling area.
var buttons: HBoxContainer
var _let_repeat: bool = false
var _shown_risk: float = -1.0


func build(kit: RefCounted) -> void:
	ui = kit
	add_theme_constant_override("separation", 6)
	_answers = ui.vbox(4)
	add_child(_answers)
	_options = ui.vbox(4)
	add_child(_options)
	buttons = ui.hbox(6)
	var row: HBoxContainer = buttons
	var specs: Array = [["Approve", func() -> void: _approve(false), true], ["Test safely", func() -> void: _approve(true), false],
		["Safer?", func() -> void: _safer(), false], ["Cancel", func() -> void: _cancel(), false]]
	for spec in specs:
		var button: Button = ui.button(str(spec[0]), spec[1], bool(spec[2]), 14)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(98, 42)
		row.add_child(button)


func show_proposal(sim: RefCounted, shown: RefCounted) -> void:
	office = sim
	proposal = shown
	_let_repeat = false
	_rebuild()


## Keeps the risk band honest as the office changes under an open card.
func refresh_risk() -> void:
	if proposal == null:
		return
	proposal.refresh(office)
	if not is_equal_approx(proposal.shown_risk, _shown_risk):
		_rebuild()


func _rebuild() -> void:
	proposal.refresh(office)
	_shown_risk = proposal.shown_risk
	for child in _answers.get_children():
		child.queue_free()
	for child in _options.get_children():
		child.queue_free()
	for answer in proposal.card(office):
		var heading: Label = ui.label(str(answer[0]), 13, ui.palette.accent)
		_answers.add_child(heading)
		var text: Label = ui.wrapped(str(answer[1]), 14, ui.palette.text)
		text.custom_minimum_size.x = 420
		_answers.add_child(text)
	_build_scope()
	_build_safeguards()


func _build_scope() -> void:
	var scopes: Array = proposal.action().scopes
	if scopes.size() < 2:
		return
	var row: HBoxContainer = ui.hbox(6)
	_options.add_child(row)
	row.add_child(ui.label("Scope:", 14))
	var floor_button: Button = ui.button("Floor %s" % BuildingPlan.floor_name(proposal.floor_index), func() -> void: _set_scope("floor"), proposal.scope == "floor", 13)
	var building_button: Button = ui.button("Whole building", func() -> void: _set_scope("building"), proposal.scope == "building", 13)
	var next_floor: Button = ui.button("Next floor", func() -> void: _cycle_floor(), false, 13)
	for button in [floor_button, building_button, next_floor]:
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = 36
		row.add_child(button)


func _build_safeguards() -> void:
	var available: Array[String] = office.patch.safeguards()
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	_options.add_child(flow)
	for safeguard in available:
		if not _applies(safeguard):
			continue
		var name: String = safeguard
		var toggle: CheckButton = ui.toggle(SAFEGUARD_NAMES[name], func(on: bool) -> void: _set_safeguard(name, on), 13)
		toggle.set_pressed_no_signal(proposal.safeguards.has(name))
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.custom_minimum_size.y = 36
		flow.add_child(toggle)
	if office.patch.limited_autonomy() and not proposal.is_automation() and proposal.ticket_id >= 0:
		var repeat: CheckButton = ui.toggle("Let PATCH repeat this", func(on: bool) -> void: _let_repeat = on, 13)
		repeat.set_pressed_no_signal(_let_repeat)
		repeat.focus_mode = Control.FOCUS_NONE
		flow.add_child(repeat)


func _applies(safeguard: String) -> bool:
	match safeguard:
		"staged":
			return proposal.scope != "ticket"
		"dry_run":
			return proposal.scope == "ticket"
		"confirm_delete":
			return proposal.action().risk_class == "destructive"
	return true


func _set_scope(scope: String) -> void:
	proposal.scope = scope
	_rebuild()


func _cycle_floor() -> void:
	var floors: Array[int] = office.staffed_floors()
	if floors.is_empty():
		return
	var at: int = floors.find(proposal.floor_index)
	proposal.floor_index = floors[(at + 1) % floors.size()]
	if proposal.scope != "building":
		proposal.scope = "floor"
	_rebuild()


func _set_safeguard(safeguard: String, on: bool) -> void:
	if on and not proposal.safeguards.has(safeguard):
		proposal.safeguards.append(safeguard)
	elif not on:
		proposal.safeguards.erase(safeguard)
	_rebuild()


func _approve(safely: bool) -> void:
	if safely:
		var careful: String = "dry_run" if proposal.scope == "ticket" else "staged"
		if not proposal.safeguards.has(careful):
			proposal.safeguards.append(careful)
	office.patch_desk.approve(office, proposal, _let_repeat)
	proposal = null
	finished.emit()


func _safer() -> void:
	var result: Array = office.patch_desk.alternative(office, proposal)
	if result[0] != null:
		proposal = result[0]
		_rebuild()


func _cancel() -> void:
	office.patch_desk.you("Not now.")
	office.patch_desk.say(Catalog.say("patch.cancel"))
	proposal = null
	finished.emit()
