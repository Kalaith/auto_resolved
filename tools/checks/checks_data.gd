extends RefCounted
## The shipped catalogs load without a single reported problem.
const Catalog = preload("res://scripts/core/catalog.gd")
const Expect = preload("res://addons/hatchery/testing/expect.gd")


func check_catalogs_load_cleanly() -> String:
	var problems: Array[String] = Catalog.problems()
	return Expect.all([
		Expect.empty(problems, "data problems " + str(problems)),
		Expect.truthy(Catalog.archetype_ids.size() >= 2, "at least two company archetypes"),
		Expect.truthy(Catalog.rooms.has("lobby") and Catalog.rooms.has("it_office"), "core rooms exist"),
	])
