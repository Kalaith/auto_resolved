extends PanelContainer
## The incident view (GDD 13): what PATCH was asked, the plan and scope, the
## roll, what was observed and how it was recovered, as a short timeline; the
## recoveries on offer (each says where it is done and how long it takes);
## and the lesson: a guardrail against this failure archetype for this job.
signal recovery_chosen(incident: RefCounted, recovery_id: String)

const Catalog = preload("res://scripts/core/catalog.gd")
const WorkClock = preload("res://scripts/sim/work_clock.gd")

var ui: RefCounted
var office: RefCounted
var _list: VBoxContainer
var _detail: VBoxContainer
var _selected: int = -1
var _signature: String = ""


func build(kit: RefCounted) -> void:
	ui = kit
	add_theme_stylebox_override("panel", ui.panel_box(0.95, 12))
	custom_minimum_size = Vector2(440, 0)
	var column: VBoxContainer = ui.vbox(8)
	add_child(column)
	var top: HBoxContainer = ui.hbox(8)
	column.add_child(top)
	var title: Label = ui.heading("Incidents", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close: Button = ui.button("X", func() -> void: visible = false, false, 14)
	close.custom_minimum_size = Vector2(40, 36)
	close.focus_mode = Control.FOCUS_NONE
	top.add_child(close)
	_list = ui.vbox(4)
	column.add_child(_list)
	column.add_child(HSeparator.new())
	_detail = ui.vbox(5)
	column.add_child(_detail)
	visible = false


func open_for(sim: RefCounted, incident_id: int = -1) -> void:
	office = sim
	visible = true
	var shown: Array = _shown()
	_selected = incident_id if incident_id >= 0 else (shown[0].id if not shown.is_empty() else -1)
	_signature = ""


func _shown() -> Array:
	var active: Array = office.patch_desk.active_incidents()
	var done: Array = office.patch_desk.incidents.filter(func(item: RefCounted) -> bool: return item.revealed and not item.is_active())
	return active + done.slice(-3)


func _process(_delta: float) -> void:
	if not visible or office == null:
		return
	var shown: Array = _shown()
	var signature: String = str(_selected) + "|" + ",".join(shown.map(func(item: RefCounted) -> String: return "%d%s%d" % [item.id, item.status, item.timeline.size()]))
	signature += "|" + ",".join(office.patch_desk.job_guardrails)
	if signature != _signature:
		_signature = signature
		_rebuild(shown)


func _rebuild(shown: Array) -> void:
	for child in _list.get_children():
		child.queue_free()
	for child in _detail.get_children():
		child.queue_free()
	if shown.is_empty():
		_list.add_child(ui.label("No incidents. PATCH is either careful or lucky.", 14, ui.palette.muted))
		return
	for item in shown:
		var incident: RefCounted = item
		var text: String = "#%d %s%s" % [incident.id, _title(incident), "" if incident.is_active() else "  (recovered)"]
		var button: Button = ui.button(text, func() -> void: _select(incident.id), incident.id == _selected, 14)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(416, 38)
		button.add_theme_color_override("font_color", ui.palette.bad if incident.is_active() else ui.palette.muted)
		_list.add_child(button)
	var selected: RefCounted = office.patch_desk.incident(_selected)
	if selected != null:
		_show_detail(selected)


func _select(id: int) -> void:
	_selected = id
	_signature = ""


func _title(incident: RefCounted) -> String:
	return "PATCH managed to " + Catalog.say("backfire.%s.label" % incident.backfire_id)


func _show_detail(incident: RefCounted) -> void:
	for step in incident.timeline:
		var line: Label = ui.wrapped("%s  %s" % [WorkClock.hhmm(fmod(float(step.at), 1440.0)), step.text], 13, ui.palette.text)
		line.custom_minimum_size.x = 416
		_detail.add_child(line)
	if not incident.is_active():
		return
	_detail.add_child(ui.label("Recover:", 14, ui.palette.accent))
	for id in office.patch_desk.recovery_ids(incident):
		var recovery_id: String = id
		var spec: Dictionary = Catalog.recoveries[recovery_id]
		var where: String = "at the IT desk" if spec.at == "desk" else "on site"
		var seconds: float = office.patch_desk.recovery_seconds(office, recovery_id)
		var text: String = "%s (%s, %ds)" % [spec.label, where, ceili(seconds)]
		var button: Button = ui.button(text, func() -> void: recovery_chosen.emit(incident, recovery_id), true, 14)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(416, 40)
		_detail.add_child(button)
	for missing in office.patch_desk.locked_recoveries(incident):
		_detail.add_child(ui.wrapped("Not available: %s (needs %s)." % [Catalog.recoveries[missing].label,
			"the Backup safeguard" if Catalog.recoveries[missing].requires == "backup" else "a reversible action"], 13, ui.palette.muted))
	var archetype: Dictionary = Catalog.failure_archetypes[incident.archetype]
	if office.patch_desk.guarded_archetypes(office).has(incident.archetype):
		_detail.add_child(ui.wrapped("Guardrail in place: %s." % archetype.guardrail, 13, ui.palette.good))
	else:
		var guard: Button = ui.button("Add guardrail: %s" % archetype.guardrail, func() -> void: office.patch_desk.add_guardrail(incident.archetype), false, 13)
		guard.alignment = HORIZONTAL_ALIGNMENT_LEFT
		guard.clip_text = true
		guard.focus_mode = Control.FOCUS_NONE
		guard.custom_minimum_size = Vector2(416, 38)
		_detail.add_child(guard)
