extends RefCounted
## The one career file, user://career.json, through the toolkit's JsonSave:
## staged writes, a .bak, recovery, and validation before anything is
## trusted or written. Saving happens at the end of each workday and at every
## step between jobs, never mid-tick.
const JsonSave = preload("res://addons/hatchery/storage/json_save.gd")
const Career = preload("res://scripts/sim/career.gd")

const PATH: String = "user://career.json"

var file: JsonSave


func _init() -> void:
	file = JsonSave.new(PATH, Career.SCHEMA, func(data: Dictionary) -> bool: return Career.valid(data))
	file.noun = "the career"


func exists() -> bool:
	return file.exists()


## The saved career, or null (with `last_error()` saying why, if anything
## went wrong rather than there simply being no save).
func load_career() -> RefCounted:
	var data: Dictionary = file.load_data()
	if data.is_empty():
		return null
	return Career.from_dict(data)


func save(career: RefCounted) -> bool:
	return file.save_data(career.to_dict())


func last_error() -> String:
	return file.last_error


## Keeps the old career as .previous before a new one replaces it.
func keep_previous() -> bool:
	return file.keep_previous()
