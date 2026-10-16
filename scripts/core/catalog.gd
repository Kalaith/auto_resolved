extends RefCounted
## Loads and validates the content catalogs (rooms, company archetypes, and
## through catalog_<topic>.gd the rest) once.
## Balance numbers are read through the toolkit's Balance facade instead.
## Anything missing or mistyped is reported by `problems()` at startup; code
## never invents a default for it.
const JsonIO = preload("res://addons/hatchery/core/json_io.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")
const DataRules = preload("res://addons/hatchery/core/data_rules.gd")
const CatalogPeople = preload("res://scripts/core/catalog_people.gd")
const CatalogIssues = preload("res://scripts/core/catalog_issues.gd")
const CatalogPatch = preload("res://scripts/core/catalog_patch.gd")

const SCHEMA_VERSION: int = 1
const ROOMS_PATH: String = "res://data/rooms.json"
const COMPANIES_PATH: String = "res://data/companies.json"
## Props the world view knows how to draw (scripts/world/room_props.gd).
const PROPS: Array = [
	"window", "reception_desk", "plant", "couch", "desk_pc", "server_rack", "whiteboard",
	"table", "fridge", "water_cooler", "printer", "bookshelf", "vending",
]
const FLOOR_RULES: Array = ["ground", "top", "basement", "any"]
## Every balance number the code reads, checked once so a missing one is a
## startup report rather than a crash mid-job.
const BALANCE_NUMBERS: Array[String] = [
	"building.floor_height", "building.slab", "building.shaft_width",
	"building.ground_depth", "elevator.speed_floors_per_second", "elevator.door_seconds",
	"elevator.dwell_seconds", "player.walk_speed", "player.interact_reach",
	"camera.follow_rate", "camera.overview_margin", "elevator.capacity",
	"day.real_seconds", "day.start_minute", "day.end_minute", "day.arrival_end_minute",
	"day.lunch_start_minute", "day.lunch_end_minute", "day.leaving_start_minute",
	"staff.walk_speed_min", "staff.walk_speed_max", "staff.arrive_first_minute", "staff.arrive_last_minute",
	"staff.leave_last_minute", "staff.lunch_out_chance", "staff.lunch_minutes_min", "staff.lunch_minutes_max",
	"staff.trip_chance_per_hour", "staff.trip_minutes_min", "staff.trip_minutes_max", "staff.decide_every_minutes",
	"issues.roll_every_minutes", "issues.tier_scale", "issues.day_scale", "issues.max_open",
	"metrics.confidence_start", "metrics.overdue_drain_per_hour", "metrics.fix_gain", "metrics.fast_fix_gain",
	"metrics.mood_drop_per_hour", "metrics.mood_recover_per_hour", "metrics.mood_rest",
	"metrics.overdue_cap", "metrics.calm_gain_per_hour",
	"risk.base.diagnosis", "risk.base.simple", "risk.base.multi", "risk.base.destructive",
	"risk.scope.ticket", "risk.scope.floor", "risk.scope.building", "risk.staged", "risk.dry_run",
	"risk.confirm_delete", "risk.guardrail", "risk.tier_step", "risk.minimum", "risk.maximum",
	"risk.band_low", "risk.band_high", "risk.band_precise_low", "risk.band_precise_high",
	"patch.dry_run_minutes", "patch.repeat_delay_minutes", "patch.daily_run_minute", "patch.cascade_cap_per_day",
	"patch.change_cap", "patch.discover_grace_minutes",
	"career.warning_confidence", "career.recover_confidence", "career.points_ticket", "career.points_ticket_extra",
	"career.points_ticket_full_per_issue_day", "career.points_automation_day", "career.points_recovery",
	"career.points_first_archetype", "career.points_clean_day", "career.points_coverage_day", "career.coverage_share",
	"career.coverage_min_resolved", "career.clean_day_min_resolved", "career.fired_keep", "career.quit_minimum_points",
	"career.fired_minimum_points", "career.grade_a", "career.grade_b", "career.grade_c", "career.reputation.A",
	"career.reputation.B", "career.reputation.C", "career.reputation.D", "career.reputation_fired_loss",
	"career.tier_reputation.2", "career.tier_reputation.3", "career.tier_reputation.4",
	"career.summon_minute", "career.summon_minutes",
]
const THEME_COLOURS: Array = ["sky", "exterior", "slab", "trim", "floor", "furniture", "accent"]

static var rooms: Dictionary = {}
static var archetypes: Dictionary = {}
## Archetype ids in file order, which is also the order of tiers.
static var archetype_ids: Array[String] = []
## data/people.json: name parts, departments, trait ranges.
static var people: Dictionary = {}
## data/issues.json by id, and the ids in file order.
static var issues: Dictionary = {}
static var issue_ids: Array[String] = []
## PATCH: actions, backfire pools, failure archetypes, recoveries, upgrades.
static var actions: Dictionary = {}
static var action_ids: Array = []
static var pools: Dictionary = {}
static var failure_archetypes: Dictionary = {}
static var recoveries: Dictionary = {}
static var upgrades: Dictionary = {}
static var upgrade_ids: Array = []
static var _errors: Array[String] = []
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_errors.clear()
	rooms.clear()
	archetypes.clear()
	archetype_ids.clear()
	_check_balance()
	_load_rooms()
	_load_archetypes()
	people = CatalogPeople.load_into(_errors, SCHEMA_VERSION)
	issue_ids.clear()
	issues = CatalogIssues.load_into(_errors, SCHEMA_VERSION, issue_ids)
	var patch: Dictionary = CatalogPatch.load_into(_errors, SCHEMA_VERSION, issues)
	actions = patch.actions
	action_ids = patch.action_ids
	pools = patch.pools
	failure_archetypes = patch.archetypes
	recoveries = patch.recoveries
	upgrades = patch.upgrades
	upgrade_ids = patch.upgrade_ids


## Every data problem found while loading; empty means the catalogs are usable.
static func problems() -> Array[String]:
	ensure_loaded()
	return _errors.duplicate()


static func room(id: String) -> Dictionary:
	ensure_loaded()
	return rooms[id]


static func archetype(id: String) -> Dictionary:
	ensure_loaded()
	return archetypes[id]


static func issue(id: String) -> Dictionary:
	ensure_loaded()
	return issues[id]


static func action(id: String) -> Dictionary:
	ensure_loaded()
	return actions[id]


static func upgrade(id: String) -> Dictionary:
	ensure_loaded()
	return upgrades[id]


## A backfire entry by id, searching every pool.
static func backfire(id: String) -> Dictionary:
	ensure_loaded()
	for pool_id in pools:
		for entry in pools[pool_id]:
			if entry.id == id:
				return entry
	return {}


## PATCH's line for `key`, with {placeholders} filled from `args`.
static func say(key: String, args: Dictionary = {}) -> String:
	return CatalogPatch.text.format(key, args)


static func _check_balance() -> void:
	var data: Variant = JsonIO.read(Balance.path)
	if not data is Dictionary or not DataRules.whole(data.get("schema_version")) or int(data.schema_version) != SCHEMA_VERSION:
		_errors.append("%s: missing, not an object, or schema_version is not %d" % [Balance.path, SCHEMA_VERSION])
		return
	for key in BALANCE_NUMBERS:
		if not Balance.has(key) or not DataRules.finite(Balance.value(key)) or float(Balance.value(key)) <= 0.0:
			_errors.append("balance.json: %s must be a positive number" % key)


static func _load_rooms() -> void:
	var data: Dictionary = JsonIO.read_object(ROOMS_PATH, _errors, SCHEMA_VERSION)
	if data.is_empty():
		return
	var rules := DataRules.new(_errors, "rooms.json")
	if not rules.list(data, "rooms", false):
		return
	rules.unique_ids(data.rooms)
	for entry in data.rooms:
		if not entry is Dictionary:
			continue
		var check: RefCounted = rules.at("rooms[%s]" % str(entry.get("id", "?")))
		var ok: bool = check.text(entry, "id") and check.text(entry, "label")
		ok = check.integer_between(entry, "min_width", 80, 2000) and ok
		ok = check.integer_between(entry, "max_width", 80, 2000) and ok
		ok = check.number_between(entry, "wall_shift", -1.0, 1.0) and ok
		ok = _check_props(check, entry.get("props")) and ok
		if entry.has("fill"):
			ok = check.one_of(entry, "fill", PROPS) and check.integer_between(entry, "fill_spacing", 40, 400) and ok
		if ok and int(entry.min_width) > int(entry.max_width):
			ok = check.fail("min_width is larger than max_width")
		if ok:
			rooms[entry.id] = entry


static func _check_props(check: RefCounted, props: Variant) -> bool:
	if not props is Array:
		return check.fail("props must be a list")
	for prop in props:
		if not PROPS.has(prop):
			return check.fail("unknown prop %s" % str(prop))
	return true


static func _load_archetypes() -> void:
	var data: Dictionary = JsonIO.read_object(COMPANIES_PATH, _errors, SCHEMA_VERSION)
	if data.is_empty():
		return
	var rules := DataRules.new(_errors, "companies.json")
	if not rules.list(data, "archetypes", false):
		return
	rules.unique_ids(data.archetypes)
	for entry in data.archetypes:
		if not entry is Dictionary:
			continue
		var check: RefCounted = rules.at("archetypes[%s]" % str(entry.get("id", "?")))
		if _check_archetype(check, entry):
			archetypes[entry.id] = entry
			archetype_ids.append(entry.id)


static func _check_archetype(check: RefCounted, entry: Dictionary) -> bool:
	var ok: bool = check.text(entry, "id") and check.text(entry, "label")
	ok = check.integer_between(entry, "tier", 1, 9) and ok
	ok = check.integer_between(entry, "pay_per_day", 1, 100000) and ok
	ok = check.boolean(entry, "basement") and ok
	ok = _int_range(check, entry, "floors", 2, 10) and ok
	ok = _int_range(check, entry, "width", 600, 6000) and ok
	ok = _fraction_range(check, entry, "elevator_position") and ok
	ok = _check_names(check, entry.get("names")) and ok
	ok = _check_required(check, entry) and ok
	ok = _check_weights(check, entry.get("room_weights")) and ok
	ok = _check_theme(check, entry.get("theme")) and ok
	return ok


static func _int_range(check: RefCounted, entry: Dictionary, key: String, low: int, high: int) -> bool:
	var value: Variant = entry.get(key)
	if not value is Array or value.size() != 2 or not DataRules.integer_in(value[0], low, high) \
			or not DataRules.integer_in(value[1], low, high) or float(value[0]) > float(value[1]):
		return check.fail("%s must be [min, max] whole numbers from %d to %d" % [key, low, high])
	return true


static func _fraction_range(check: RefCounted, entry: Dictionary, key: String) -> bool:
	var value: Variant = entry.get(key)
	if not value is Array or value.size() != 2 or not DataRules.fraction(value[0]) \
			or not DataRules.fraction(value[1]) or float(value[0]) > float(value[1]):
		return check.fail("%s must be [min, max] fractions" % key)
	return true


static func _check_names(check: RefCounted, names: Variant) -> bool:
	if not names is Dictionary:
		return check.fail("names must be an object")
	for part in ["first", "second"]:
		var words: Variant = names.get(part)
		if not words is Array or words.is_empty() or not words.all(Callable(DataRules, "nonempty")):
			return check.fail("names.%s must be a nonempty list of text" % part)
	return true


static func _check_required(check: RefCounted, entry: Dictionary) -> bool:
	var required: Variant = entry.get("required")
	if not required is Array:
		return check.fail("required must be a list")
	var has_lobby: bool = false
	for item in required:
		if not item is Dictionary or not rooms.has(item.get("room")) or not FLOOR_RULES.has(item.get("floor")):
			return check.fail("required entries need a known room and floor rule")
		if item.floor == "basement" and not entry.get("basement", false):
			return check.fail("%s is required in a basement the building does not have" % item.room)
		has_lobby = has_lobby or (item.room == "lobby" and item.floor == "ground")
	if not has_lobby:
		return check.fail("every building needs a lobby on the ground floor")
	return true


static func _check_weights(check: RefCounted, weights: Variant) -> bool:
	if not weights is Dictionary or weights.is_empty():
		return check.fail("room_weights must be a nonempty object")
	for key in weights:
		if not rooms.has(key) or not DataRules.finite(weights[key]) or float(weights[key]) <= 0.0:
			return check.fail("room_weights.%s must name a room with a positive weight" % str(key))
	return true


static func _check_theme(check: RefCounted, theme: Variant) -> bool:
	if not theme is Dictionary:
		return check.fail("theme must be an object")
	for key in THEME_COLOURS:
		if not theme.get(key) is String or not Color.html_is_valid(theme.get(key)):
			return check.fail("theme.%s must be a hex colour" % key)
	var walls: Variant = theme.get("walls")
	if not walls is Array or walls.is_empty():
		return check.fail("theme.walls must be a nonempty list of hex colours")
	for wall in walls:
		if not wall is String or not Color.html_is_valid(wall):
			return check.fail("theme.walls must be a nonempty list of hex colours")
	if not DataRules.finite(theme.get("hue_jitter")) \
			or float(theme.hue_jitter) < 0.0 or float(theme.hue_jitter) > 0.2:
		return check.fail("theme.hue_jitter must be a number from 0 to 0.2")
	return true
