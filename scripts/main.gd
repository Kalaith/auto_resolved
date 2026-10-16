extends Node2D
## Owns the current job: builds its office sim and views, steps the sim at a
## fixed rate under the chosen speed, drains its events to the HUD, and routes
## input that is not the player's own (clicks, overview, speed, the debug job
## switch). Career flow (offers, firing, quitting, PATCH upgrades) arrives in
## later milestones; see docs/IMPLEMENTATION_GUIDE.md.
const Catalog = preload("res://scripts/core/catalog.gd")
const Job = preload("res://scripts/sim/job.gd")
const OfficeSim = preload("res://scripts/sim/office_sim.gd")
const BuildingView = preload("res://scripts/world/building_view.gd")
const ElevatorView = preload("res://scripts/world/elevator_view.gd")
const StaffView = preload("res://scripts/world/staff_view.gd")
const Player = preload("res://scripts/world/player.gd")
const OfficeCamera = preload("res://scripts/world/office_camera.gd")
const Hud = preload("res://scripts/ui/hud.gd")

const Z_CAR: int = 1
const Z_RIDERS: int = 2
const Z_DOORS: int = 3
const Z_STAFF: int = 4
## The most sim ticks one frame may run, so a slow frame cannot snowball.
const MAX_TICKS_PER_FRAME: int = 12

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
## 0 pauses the office; the player and the elevator still move.
var time_scale: float = 1.0
var _world: Node2D
var _seeds := RandomNumberGenerator.new()
var _accumulator: float = 0.0


func _ready() -> void:
	_seeds.randomize()
	hud = Hud.new()
	add_child(hud)
	hud.clock_bar.speed_chosen.connect(set_speed)
	camera = OfficeCamera.new()
	add_child(camera)
	var problems: Array[String] = Catalog.problems()
	if not problems.is_empty():
		for problem in problems:
			push_error(problem)
		hud.show_problems(problems)
		return
	start_job(start_archetype, fixed_seed if fixed_seed != 0 else _fresh_seed())


## Replaces the whole office with the building for a new job.
func start_job(archetype: String, job_seed: int) -> void:
	if _world != null:
		_world.queue_free()
	job = Job.create(archetype, job_seed)
	office = OfficeSim.create(job)
	plan = office.plan
	elevator = office.elevator
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	var building: Node2D = BuildingView.new()
	building.setup(plan, job.seed_value)
	_world.add_child(building)
	_world.add_child(_elevator_layer(ElevatorView.Layer.CAR, Z_CAR))
	_world.add_child(_staff_layer(StaffView.Layer.RIDING, Z_RIDERS))
	_world.add_child(_elevator_layer(ElevatorView.Layer.DOORS, Z_DOORS))
	staff_view = _staff_layer(StaffView.Layer.WALKING, Z_STAFF)
	_world.add_child(staff_view)
	player = Player.new()
	player.setup(plan, elevator, 0, office.entrance_x() + (40.0 if office.entrance_x() < plan.shaft_x else -40.0))
	_world.add_child(player)
	camera.setup(player, building.shell_rect())
	hud.show_job(job, plan)
	RenderingServer.set_default_clear_color(plan.colours.sky)
	_accumulator = 0.0
	office.begin_day(1)
	set_speed(1.0)


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


func _physics_process(delta: float) -> void:
	if office == null:
		return
	if time_scale <= 0.0 or not office.day_running:
		office.step_paused(delta)
		_accumulator = 0.0
	else:
		_accumulator += delta * time_scale
		var ticks: int = 0
		while _accumulator >= OfficeSim.TICK and ticks < MAX_TICKS_PER_FRAME:
			office.step(OfficeSim.TICK)
			_accumulator -= OfficeSim.TICK
			ticks += 1
		_accumulator = minf(_accumulator, OfficeSim.TICK * 2.0)
	for event in office.drain_events():
		_on_event(event)


func _process(_delta: float) -> void:
	if player == null:
		return
	hud.show_position(player, elevator)
	hud.clock_bar.show_clock(office.clock, office.day_running)
	hud.person_card.refresh(office)


func _on_event(event: Dictionary) -> void:
	match str(event.type):
		"day_ended":
			_show_day_summary(int(event.day))


func _show_day_summary(day: int) -> void:
	var body: String = "Everyone has gone home. %d staff work here across %d floors." % [office.staff.size(), plan.floor_count()]
	hud.notice.open("Day %d is over" % day, body, [["Start day %d" % (day + 1), func() -> void: office.begin_day(day + 1), true]])


func _unhandled_input(event: InputEvent) -> void:
	if plan == null:
		return
	if event.is_action_pressed("toggle_overview"):
		camera.overview = not camera.overview
	elif event.is_action_pressed("pause"):
		set_speed(1.0 if time_scale <= 0.0 else 0.0)
	elif event.is_action_pressed("speed_1"):
		set_speed(1.0)
	elif event.is_action_pressed("speed_2"):
		set_speed(2.0)
	elif event.is_action_pressed("speed_3"):
		set_speed(4.0)
	elif event.is_action_pressed("debug_next_job"):
		var ids: Array[String] = Catalog.archetype_ids
		start_job(ids[(ids.find(job.archetype_id) + 1) % ids.size()], _fresh_seed())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(get_global_mouse_position())


func _click(at: Vector2) -> void:
	var person: RefCounted = staff_view.employee_at(at)
	if person != null:
		hud.person_card.open_for(person)
		return
	player.go_to(plan.floor_at_y(at.y), at.x)


func _fresh_seed() -> int:
	return _seeds.randi_range(1, 2147483646)
