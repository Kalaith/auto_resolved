extends Node2D
## Owns the current job: builds its building, elevator and views, steps the
## simulation, and routes input that is not the player's own (clicks, overview,
## the debug job switch). Career flow (offers, firing, quitting, PATCH
## upgrades) arrives in later milestones; see docs/IMPLEMENTATION_GUIDE.md.
const Catalog = preload("res://scripts/core/catalog.gd")
const Job = preload("res://scripts/sim/job.gd")
const BuildingPlan = preload("res://scripts/sim/building_plan.gd")
const Elevator = preload("res://scripts/sim/elevator.gd")
const BuildingView = preload("res://scripts/world/building_view.gd")
const ElevatorView = preload("res://scripts/world/elevator_view.gd")
const Player = preload("res://scripts/world/player.gd")
const OfficeCamera = preload("res://scripts/world/office_camera.gd")
const Hud = preload("res://scripts/ui/hud.gd")

const Z_CAR: int = 1
const Z_DOORS: int = 3

@export var start_archetype: String = "family_business"
## Nonzero gives a reproducible first job (captures, bug reports).
@export var fixed_seed: int = 0

var job: RefCounted
var plan: RefCounted
var elevator: RefCounted
var player: Node2D
var camera: Camera2D
var hud: CanvasLayer
var _world: Node2D
var _seeds := RandomNumberGenerator.new()


func _ready() -> void:
	_seeds.randomize()
	hud = Hud.new()
	add_child(hud)
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
	plan = BuildingPlan.generate(job)
	elevator = Elevator.new(plan.lowest, plan.highest, 0)
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	var building: Node2D = BuildingView.new()
	building.setup(plan, job.seed_value)
	_world.add_child(building)
	_world.add_child(_elevator_layer(ElevatorView.Layer.CAR, Z_CAR))
	_world.add_child(_elevator_layer(ElevatorView.Layer.DOORS, Z_DOORS))
	player = Player.new()
	var lobby: Array = plan.find_rooms("lobby")
	var start_x: float = lobby[0].x + lobby[0].width * 0.5 if not lobby.is_empty() else plan.shaft_center()
	player.setup(plan, elevator, 0, start_x)
	_world.add_child(player)
	camera.setup(player, building.shell_rect())
	hud.show_job(job, plan)
	RenderingServer.set_default_clear_color(plan.colours.sky)


func _elevator_layer(which: ElevatorView.Layer, depth: int) -> Node2D:
	var view: Node2D = ElevatorView.new()
	view.setup(plan, elevator, which)
	view.z_index = depth
	return view


func _physics_process(delta: float) -> void:
	if elevator != null:
		elevator.step(delta)


func _process(_delta: float) -> void:
	if player != null:
		hud.show_position(player, elevator)


func _unhandled_input(event: InputEvent) -> void:
	if plan == null:
		return
	if event.is_action_pressed("toggle_overview"):
		camera.overview = not camera.overview
	elif event.is_action_pressed("debug_next_job"):
		var ids: Array[String] = Catalog.archetype_ids
		start_job(ids[(ids.find(job.archetype_id) + 1) % ids.size()], _fresh_seed())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = get_global_mouse_position()
		player.go_to(plan.floor_at_y(at.y), at.x)


func _fresh_seed() -> int:
	return _seeds.randi_range(1, 2147483646)
