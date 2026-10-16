extends "res://addons/hatchery/testing/capture_runner.gd"
## Screenshots of one building per archetype, close up and in overview, a
## ride, and the office through a day:
##   godot --path . --script res://tools/capture.gd -- [output dir] [--size=1280x720] [--only=<part>]
const Catalog = preload("res://scripts/core/catalog.gd")

var only: String = ""


func tour() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	var main: Node = await open_scene("res://scenes/main.tscn")
	if only.is_empty() or only == "buildings":
		await _buildings(main)
	if only.is_empty() or only == "day":
		await _day(main)


func _buildings(main: Node) -> void:
	for id in Catalog.archetype_ids:
		main.start_job(id, 1234)
		await seconds(0.6)
		await shot("%s_close" % id)
		main.camera.overview = true
		await seconds(1.2)
		await shot("%s_overview" % id)
		main.camera.overview = false
	main.start_job("startup", 99)
	main.player.go_to(main.plan.highest, main.plan.width - 60.0)
	await seconds(4.0)
	await shot("route_riding")
	await seconds(5.0)
	await shot("route_arrived")


## The office through a day at high speed: arrival, a working morning, lunch.
func _day(main: Node) -> void:
	main.start_job("accounting_firm", 4321)
	main.camera.overview = true
	Engine.time_scale = 4.0
	main.set_speed(4.0)
	await _until(main, 505.0)
	await shot("day_morning_arrival")
	main.camera.overview = false
	await _until(main, 530.0)
	var open: Array = main.office.helpdesk.queue.by_urgency()
	if not open.is_empty():
		main.work.request(open[0].id)
	await _until(main, 560.0)
	await shot("day_ticket_fix")
	await _until(main, 620.0)
	await shot("day_working_close")
	main.camera.overview = true
	await _until(main, 735.0)
	await shot("day_lunch_crowd")
	Engine.time_scale = 1.0


func _until(main: Node, minute: float) -> void:
	while main.office.clock.minute < minute and main.office.day_running:
		await frames(5)
