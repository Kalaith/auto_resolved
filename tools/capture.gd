extends "res://addons/hatchery/testing/capture_runner.gd"
## Screenshots of one building per archetype, close up and in overview:
##   godot --path . --script res://tools/capture.gd -- [output dir] [--size=1280x720]
const Catalog = preload("res://scripts/core/catalog.gd")


func tour() -> void:
	var main: Node = await open_scene("res://scenes/main.tscn")
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
