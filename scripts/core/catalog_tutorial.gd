extends RefCounted
## The day-1 tutorial's steps, in order, and their text
## (data/text_tutorial.json). Which event finishes each step is code
## (scripts/tutorial.gd); this keeps the ids and checks every line exists.
const TextCatalog = preload("res://addons/hatchery/core/text_catalog.gd")

const STEPS: Array[String] = ["welcome", "go_to_it", "first_ticket", "capacity", "patch", "automate", "needs", "end"]

static var text: TextCatalog = TextCatalog.new(["res://data/text_tutorial.json"])


static func check(errors: Array[String]) -> void:
	text.reload()
	errors.append_array(text.problems())
	var required: Array = []
	for step in STEPS:
		required.append("tutorial.%s.title" % step)
		required.append("tutorial.%s.body" % step)
	for key in text.missing(required):
		errors.append("text_tutorial.json: missing label " + key)
