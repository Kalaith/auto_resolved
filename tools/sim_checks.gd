extends "res://addons/hatchery/testing/check_runner.gd"
## Auto-Resolved's headless checks:
##   godot --headless --path . --script res://tools/sim_checks.gd [-- --only=<text>]


func modules() -> Array[String]:
	return [
		"res://tools/checks/checks_data.gd",
		"res://tools/checks/checks_building.gd",
		"res://tools/checks/checks_elevator.gd",
	]
