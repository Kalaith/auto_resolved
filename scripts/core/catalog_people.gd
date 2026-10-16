extends RefCounted
## Loads and validates data/people.json: name parts, departments with their
## shirt colours, and the trait ranges staff are rolled from.
const JsonIO = preload("res://addons/hatchery/core/json_io.gd")
const DataRules = preload("res://addons/hatchery/core/data_rules.gd")
const TextCatalog = preload("res://addons/hatchery/core/text_catalog.gd")

const PATH: String = "res://data/people.json"
const TRAITS: Array[String] = ["tech_confidence", "patience"]

## What staff say (scripts/world/bubble_view.gd): "|"-separated variants.
static var staff_text: TextCatalog = TextCatalog.new(["res://data/text_staff.json"])


## Every line the staff will be asked for exists: one per issue, one per
## failure archetype (reaction and memory) and the fixed ones.
static func check_staff_text(errors: Array[String], issue_ids: Array[String], archetypes: Array) -> void:
	staff_text.reload()
	errors.append_array(staff_text.problems())
	var required: Array = ["staff.thanks.player", "staff.thanks.patch", "staff.late", "staff.manager_visit"]
	for id in issue_ids:
		required.append("staff.ticket." + id)
	for id in archetypes:
		required.append("staff.incident." + str(id))
		required.append("staff.remember." + str(id))
	for key in staff_text.missing(required):
		errors.append("text_staff.json: missing label " + key)


## The validated catalog, or {} with the problems appended to `errors`.
static func load_into(errors: Array[String], schema: int) -> Dictionary:
	var data: Dictionary = JsonIO.read_object(PATH, errors, schema)
	if data.is_empty():
		return {}
	var before: int = errors.size()
	var rules := DataRules.new(errors, "people.json")
	for key in ["first_names", "last_names"]:
		if not data.get(key) is Array or data[key].size() < 8 or not data[key].all(Callable(DataRules, "nonempty")):
			rules.fail("%s must list at least eight names" % key)
	if rules.list(data, "departments", false):
		rules.unique_ids(data.departments)
		for entry in data.departments:
			_check_department(rules.at("departments[%s]" % str(entry.get("id", "?")) if entry is Dictionary else "departments"), entry)
	if rules.object(data, "management"):
		_check_department(rules.at("management"), data.management)
	if rules.object(data, "traits"):
		for key in TRAITS:
			var span: Variant = data.traits.get(key)
			if not span is Array or span.size() != 2 or not DataRules.fraction(span[0]) or not DataRules.fraction(span[1]) \
					or float(span[0]) > float(span[1]):
				rules.fail("traits.%s must be [min, max] fractions" % key)
	return data if errors.size() == before else {}


static func _check_department(check: RefCounted, entry: Variant) -> void:
	if not entry is Dictionary:
		check.fail("must be an object")
		return
	check.text(entry, "id")
	check.text(entry, "label")
	if not entry.get("colour") is String or not Color.html_is_valid(entry.get("colour")):
		check.fail("colour must be a hex colour")
