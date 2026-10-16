extends RefCounted
## Loads and validates data/issues.json: what breaks, on which kind of device,
## how often, how badly, how long people wait, how it is fixed by hand, and
## what it does to the people it hits.
const JsonIO = preload("res://addons/hatchery/core/json_io.gd")
const DataRules = preload("res://addons/hatchery/core/data_rules.gd")

const PATH: String = "res://data/issues.json"
## Device kinds the sim generates (scripts/sim/device_factory.gd).
const DEVICE_KINDS: Array = ["workstation", "printer", "server", "network_core", "elevator", "it_desk"]
## Where a manual fix happens: at the device, or also from the IT desk.
const FIX_PLACES: Array = ["device", "desk_or_device"]
## Who an open ticket hurts: the device's owner, everyone on its floor, or
## everyone in the building.
const SPREADS: Array = ["device", "floor", "building"]
## Fault states the world knows how to draw (scripts/world/fault_art.gd), for
## issues here and for PATCH's backfires.
const FAULTS: Array = [
	"locked", "offline", "install", "slow", "no_account", "no_network", "confused", "crashed",
	"dark", "admin", "paper_flood", "wiped", "bricked",
]


## id -> issue entry, in file order through `order`; problems go to `errors`.
static func load_into(errors: Array[String], schema: int, order: Array[String]) -> Dictionary:
	var data: Dictionary = JsonIO.read_object(PATH, errors, schema)
	var result: Dictionary = {}
	if data.is_empty():
		return result
	var rules := DataRules.new(errors, "issues.json")
	if not rules.list(data, "issues", false):
		return result
	rules.unique_ids(data.issues)
	for entry in data.issues:
		if not entry is Dictionary:
			continue
		var check: RefCounted = rules.at("issues[%s]" % str(entry.get("id", "?")))
		if _check(check, entry):
			result[entry.id] = entry
			order.append(str(entry.id))
	return result


static func _check(check: RefCounted, entry: Dictionary) -> bool:
	var ok: bool = check.text(entry, "id") and check.text(entry, "label") and check.text(entry, "title")
	ok = check.number_between(entry, "per_device_per_day", 0.001, 10.0) and ok
	ok = check.integer_between(entry, "min_tier", 1, 9) and ok
	ok = check.integer_between(entry, "severity", 1, 3) and ok
	ok = check.integer_between(entry, "patience_minutes", 10, 600) and ok
	ok = check.one_of(entry, "fault", FAULTS) and ok
	ok = check.number_between(entry, "blocks", 0.0, 1.0) and ok
	ok = check.one_of(entry, "spread", SPREADS) and ok
	var devices: Variant = entry.get("devices")
	if not devices is Array or devices.is_empty() or not devices.all(func(kind: Variant) -> bool: return DEVICE_KINDS.has(kind)):
		ok = check.fail("devices must list known device kinds")
	var manual: Variant = entry.get("manual")
	if not manual is Dictionary:
		return check.fail("manual must be an object")
	ok = check.one_of(manual, "at", FIX_PLACES) and check.number_between(manual, "seconds", 0.5, 30.0) and ok
	return ok
