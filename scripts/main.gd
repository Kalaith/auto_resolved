extends Node2D
## Owns the office while a job runs: builds the job's sim and views, steps the
## sim at a fixed rate under the chosen speed, drains its events to the HUD,
## and routes input that is not the player's own (clicks, overview, speed,
## the menu). The career around jobs (title, exit interview, upgrades, job
## board) is career_flow.gd; preferences are settings_flow.gd.
const Catalog = preload("res://scripts/core/catalog.gd")
const Job = preload("res://scripts/sim/job.gd")
const OfficeSim = preload("res://scripts/sim/office_sim.gd")
const OfficeSnapshot = preload("res://scripts/sim/office_snapshot.gd")
const BuildingView = preload("res://scripts/world/building_view.gd")
const ElevatorView = preload("res://scripts/world/elevator_view.gd")
const StaffView = preload("res://scripts/world/staff_view.gd")
const DeviceView = preload("res://scripts/world/device_view.gd")
const SkyView = preload("res://scripts/world/sky_view.gd")
const WindowShade = preload("res://scripts/world/window_shade.gd")
const BubbleView = preload("res://scripts/world/bubble_view.gd")
const WorkController = preload("res://scripts/world/work_controller.gd")
const Player = preload("res://scripts/world/player.gd")
const OfficeCamera = preload("res://scripts/world/office_camera.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const DebugKeys = preload("res://scripts/debug_keys.gd")
const CareerFlow = preload("res://scripts/career_flow.gd")
const SettingsFlow = preload("res://scripts/settings_flow.gd")
const AudioDirector = preload("res://scripts/audio_director.gd")

const Z_CAR: int = 1
const Z_RIDERS: int = 2
const Z_DOORS: int = 3
const Z_STAFF: int = 4
## The most sim ticks one frame may run, so a slow frame cannot snowball.
const MAX_TICKS_PER_FRAME: int = 12

## True opens straight into a job (captures, quick tests) instead of the title.
@export var skip_title: bool = false
@export var start_archetype: String = "family_business"
## Nonzero gives a reproducible first job (captures, bug reports).
@export var fixed_seed: int = 0

var job: RefCounted
var office: RefCounted
var plan: RefCounted
var elevator: RefCounted
var player: Node2D
var camera: Camera2D
var hud: CanvasLayer
var staff_view: Node2D
var device_view: Node2D
var sky_view: Node2D
var window_shade: Node2D
var bubbles: Node2D
var work: Node
var flow: Node
var settings: Node
var audio: Node
## 0 pauses the office; the player and the elevator still move.
var time_scale: float = 1.0
var _world: Node2D
var _seeds := RandomNumberGenerator.new()
var _accumulator: float = 0.0


func _ready() -> void:
	_seeds.randomize()
	hud = Hud.new()
	add_child(hud)
	settings = SettingsFlow.new()
	add_child(settings)
	settings.palette = hud.ui.palette
	settings.apply("colour_safe")
	camera = OfficeCamera.new()
	add_child(camera)
	work = WorkController.new()
	add_child(work)
	var debug: Node = DebugKeys.new()
	debug.main = self
	add_child(debug)
	flow = CareerFlow.new()
	flow.main = self
	add_child(flow)
	audio = AudioDirector.new()
	audio.main = self
	add_child(audio)
	_connect_hud()
	var problems: Array[String] = Catalog.problems()
	if not problems.is_empty():
		for problem in problems:
			push_error(problem)
		hud.show_problems(problems)
		return
	settings.title_requested.connect(func() -> void: flow.show_title())
	if skip_title:
		start_job(start_archetype, fixed_seed if fixed_seed != 0 else _fresh_seed())
	else:
		flow.show_title()


func _connect_hud() -> void:
	hud.clock_bar.speed_chosen.connect(set_speed)
	work.message.connect(func(text: String) -> void: hud.toast(text))
	hud.tickets.ticket_chosen.connect(func(id: int) -> void: work.request(id))
	hud.tickets.patch_asked.connect(func(id: int) -> void: hud.open_patch(office, id))
	hud.patch_button.pressed.connect(func() -> void: hud.open_patch(office))
	hud.alert.pressed.connect(func() -> void: hud.incidents.open_for(office))
	hud.incidents.recovery_chosen.connect(func(incident: RefCounted, recovery: String) -> void: work.request_recovery(incident, recovery))
	hud.menu_button.pressed.connect(open_menu)


## Replaces the whole office with the building for a job. A saved `state`
## from an earlier day is laid back over it, and the office opens on `day`.
func start_job(archetype: String, job_seed: int, patch: RefCounted = null, state: Dictionary = {}, day: int = 1) -> void:
	end_job()
	flow.clear_screen()
	job = Job.create(archetype, job_seed)
	office = OfficeSim.create(job, patch)
	if not state.is_empty():
		OfficeSnapshot.restore(office, state)
	plan = office.plan
	elevator = office.elevator
	_build_world()
	hud.visible = true
	hud.show_job(job, plan)
	hud.patch_panel.close_panel()
	hud.incidents.visible = false
	RenderingServer.set_default_clear_color(plan.colours.sky)
	_accumulator = 0.0
	office.begin_day(day)
	set_speed(1.0)


func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	sky_view = SkyView.new()
	sky_view.setup(plan, job.seed_value)
	_world.add_child(sky_view)
	var building: Node2D = BuildingView.new()
	building.setup(plan, job.seed_value, job.company_name)
	_world.add_child(building)
	window_shade = WindowShade.new()
	window_shade.setup(plan)
	_world.add_child(window_shade)
	device_view = DeviceView.new()
	device_view.setup(office)
	_world.add_child(device_view)
	_world.add_child(_elevator_layer(ElevatorView.Layer.CAR, Z_CAR))
	_world.add_child(_staff_layer(StaffView.Layer.RIDING, Z_RIDERS))
	_world.add_child(_elevator_layer(ElevatorView.Layer.DOORS, Z_DOORS))
	staff_view = _staff_layer(StaffView.Layer.WALKING, Z_STAFF)
	_world.add_child(staff_view)
	bubbles = BubbleView.new()
	bubbles.setup(office)
	_world.add_child(bubbles)
	player = Player.new()
	var entrance: float = office.entrance_x()
	player.setup(plan, elevator, 0, entrance + (40.0 if entrance < plan.shaft_x else -40.0))
	_world.add_child(player)
	camera.setup(player, building.shell_rect())
	work.setup(office, player, device_view)


## Takes the office down (between jobs, at the title).
func end_job() -> void:
	if _world != null:
		_world.queue_free()
		_world = null
	office = null
	player = null
	plan = null
	hud.visible = false
	hud.notice.visible = false
	camera.target = null
	work.office = null


func _elevator_layer(which: ElevatorView.Layer, depth: int) -> Node2D:
	var view: Node2D = ElevatorView.new()
	view.setup(plan, elevator, which)
	view.z_index = depth
	return view


func _staff_layer(which: StaffView.Layer, depth: int) -> Node2D:
	var view: Node2D = StaffView.new()
	view.setup(office, which)
	view.z_index = depth
	return view


func set_speed(scale: float) -> void:
	time_scale = scale
	hud.clock_bar.show_speed(scale)


func open_settings() -> void:
	settings.open(hud.ui, office != null)


## The job menu: hand in notice, settings, or leave for the title.
func open_menu() -> void:
	if office == null:
		return
	var choices: Array = []
	if flow.career != null and not office.notice_given:
		choices.append(["Hand in notice", func() -> void: flow.hand_in_notice(office)])
	choices.append(["Settings", open_settings])
	choices.append(["Quit to title", func() -> void: flow.show_title()])
	choices.append(["Back", func() -> void: pass, true])
	var body: String = "Handing in notice finishes today, then comes the exit interview: quitting keeps all your PATCH Points.\n" + \
		"The career saves at the end of each workday; quitting to the title now loses today."
	if office.notice_given:
		body = "You have handed in your notice: today is your last day.\n" + body
	hud.notice.open("%s - day %d" % [job.company_name, office.clock.day], body, choices)


func _physics_process(delta: float) -> void:
	if office == null:
		return
	if time_scale <= 0.0 or not office.day_running:
		office.step_paused(delta)
		_accumulator = 0.0
	else:
		_accumulator += delta * time_scale
		var ticks: int = 0
		while _accumulator >= OfficeSim.TICK and ticks < MAX_TICKS_PER_FRAME and office.day_running:
			office.step(OfficeSim.TICK)
			_accumulator -= OfficeSim.TICK
			ticks += 1
		_accumulator = minf(_accumulator, OfficeSim.TICK * 2.0)
	for event in office.drain_events():
		_on_event(event)
		if office == null:
			return


func _process(delta: float) -> void:
	if office == null or player == null:
		return
	hud.show_points(office, delta, flow.career != null)
	hud.show_position(player, elevator)
	hud.clock_bar.show_clock(office.clock, office.day_running)
	hud.person_card.refresh(office)
	hud.tickets.show_office(office)
	hud.show_alert(office)
	sky_view.set_progress(office.clock.progress())
	window_shade.set_light(sky_view.tint)


func _on_event(event: Dictionary) -> void:
	bubbles.on_event(event)
	audio.on_event(event)
	match str(event.type):
		"day_ended":
			hud.patch_panel.close_panel()
			flow.on_day_ended(office, int(event.day))
		"incident_opened":
			hud.toast("Something went wrong. PATCH would like a word.")
		"manager_visit":
			hud.toast("A manager is on the way to the IT office.")
		"new_starter":
			hud.toast("A new starter has arrived, and needs an account.")
		"ticket_opened":
			if int(event.ticket) <= 3:
				hud.toast("New ticket: %s" % office.helpdesk.queue.get_ticket(int(event.ticket)).title)


func _unhandled_input(event: InputEvent) -> void:
	if plan == null or office == null:
		return
	if event.is_action_pressed("interact"):
		if not work.interact_here() and work.at_it_desk():
			hud.open_patch(office)
	elif event.is_action_pressed("toggle_overview"):
		camera.overview = not camera.overview
	elif event.is_action_pressed("pause"):
		set_speed(1.0 if time_scale <= 0.0 else 0.0)
	elif event.is_action_pressed("speed_1"):
		set_speed(1.0)
	elif event.is_action_pressed("speed_2"):
		set_speed(2.0)
	elif event.is_action_pressed("speed_3"):
		set_speed(4.0)
	elif event.is_action_pressed("ui_cancel") and not settings.is_open():
		open_menu()
	elif event.is_action_pressed("debug_next_job") and OS.is_debug_build() and flow.career == null:
		var ids: Array[String] = Catalog.archetype_ids
		start_job(ids[(ids.find(job.archetype_id) + 1) % ids.size()], _fresh_seed())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(get_global_mouse_position())


func _click(at: Vector2) -> void:
	var person: RefCounted = staff_view.employee_at(at)
	if person != null:
		hud.person_card.open_for(person)
		return
	var device: RefCounted = device_view.device_at(at)
	if device != null:
		var waiting: Array = office.helpdesk.queue.open_for_device(device.id)
		if not waiting.is_empty():
			work.request(waiting[0].id)
			return
		player.go_to(device.floor_index, work.stand_x(device))
		return
	player.go_to(plan.floor_at_y(at.y), at.x)


func _fresh_seed() -> int:
	return _seeds.randi_range(1, 2147483646)
