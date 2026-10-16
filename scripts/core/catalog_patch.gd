extends RefCounted
## Loads and validates PATCH's catalogs: actions (what it can propose),
## backfires (what each can do wrong, the failure archetypes and the
## recoveries), upgrades (the persistent tree) and its dialogue. Every "do"
## value is a closed list the sim implements; anything else is rejected.
const JsonIO = preload("res://addons/hatchery/core/json_io.gd")
const DataRules = preload("res://addons/hatchery/core/data_rules.gd")
const TextCatalog = preload("res://addons/hatchery/core/text_catalog.gd")
const CatalogIssues = preload("res://scripts/core/catalog_issues.gd")

const ACTIONS_PATH: String = "res://data/actions.json"
const BACKFIRES_PATH: String = "res://data/backfires.json"
const UPGRADES_PATH: String = "res://data/patch_upgrades.json"
const TEXT_PATH: String = "res://data/text_patch.json"

const ACTION_KINDS: Array = ["one_off", "automation"]
const RISK_CLASSES: Array = ["diagnosis", "simple", "multi", "destructive"]
const SCOPES: Array = ["ticket", "floor", "building"]
const CADENCES: Array = ["hourly", "daily"]
## Success effects (scripts/sim/patch_effects.gd).
const SUCCESS_DO: Array = ["resolve_ticket", "resolve_open", "prevent", "tune_elevator", "triage_queue", "archive"]
## Backfire effects (scripts/sim/backfire_effects.gd) and where they land.
const BACKFIRE_DO: Array = ["device_fault", "area_fault", "open_tickets", "delete_tickets", "false_close", "confidence", "mood", "lift_fault"]
const EFFECT_ON: Array = ["target", "scope", "random", "target_floor", "other_floor", "scope_floors"]
const DELAYS: Array = ["immediate", "delayed", "false_success", "partial"]
const RECOVERY_DOES: Array = ["clear_faults", "close_tickets", "restore_tickets", "reopen_tickets"]
const RECOVERY_AT: Array = ["desk", "site"]
const RECOVERY_REQUIRES: Array = ["", "backup", "rollback"]
const TRACKS: Array = ["reliability", "safety", "understanding", "capability", "autonomy"]
## Safeguards: staged and dry_run come with PATCH v1.0, the rest are bought.
const SAFEGUARDS: Array = ["staged", "dry_run", "backup", "confirm_delete", "change_cap"]
const UPGRADE_DO: Array = [
	"risk_scale", "unlock_safeguard", "recovery_speed", "archetype_scale", "precise_risk",
	"unlock_action", "remote_session", "limited_autonomy", "cadence_scale",
]

static var text: TextCatalog = TextCatalog.new([TEXT_PATH])


## {"actions", "action_ids", "pools", "archetypes", "recoveries", "upgrades",
## "upgrade_ids"}; problems go to `errors`.
static func load_into(errors: Array[String], schema: int, issues: Dictionary) -> Dictionary:
	var result: Dictionary = {"actions": {}, "action_ids": [], "pools": {}, "archetypes": {}, "recoveries": {}, "upgrades": {}, "upgrade_ids": []}
	var backfires: Dictionary = JsonIO.read_object(BACKFIRES_PATH, errors, schema)
	if not backfires.is_empty():
		_load_backfires(errors, backfires, result, issues)
	var upgrades: Dictionary = JsonIO.read_object(UPGRADES_PATH, errors, schema)
	var actions: Dictionary = JsonIO.read_object(ACTIONS_PATH, errors, schema)
	if not actions.is_empty():
		_load_actions(errors, actions, result, issues, upgrades)
	if not upgrades.is_empty():
		_load_upgrades(errors, upgrades, result)
	_check_text(errors, result)
	return result


static func _load_backfires(errors: Array[String], data: Dictionary, result: Dictionary, issues: Dictionary) -> void:
	var rules := DataRules.new(errors, "backfires.json")
	if not rules.object(data, "archetypes") or not rules.object(data, "recoveries") or not rules.object(data, "pools"):
		return
	for id in data.archetypes:
		var entry: Variant = data.archetypes[id]
		if entry is Dictionary and DataRules.nonempty(entry.get("label")) and DataRules.nonempty(entry.get("guardrail")):
			result.archetypes[id] = entry
		else:
			rules.fail("archetypes.%s needs a label and a guardrail" % id)
	for id in data.recoveries:
		var entry: Variant = data.recoveries[id]
		var check: RefCounted = rules.at("recoveries.%s" % id)
		if not entry is Dictionary:
			check.fail("must be an object")
			continue
		var ok: bool = check.text(entry, "label") and check.one_of(entry, "at", RECOVERY_AT)
		ok = check.number_between(entry, "seconds", 0.5, 60.0) and check.one_of(entry, "requires", RECOVERY_REQUIRES) and ok
		ok = check.integer_between(entry, "confidence", -20, 20) and ok
		if not entry.get("does") is Array or entry.does.is_empty() or not entry.does.all(func(item: Variant) -> bool: return RECOVERY_DOES.has(item)):
			ok = check.fail("does must list known recovery steps")
		if ok:
			result.recoveries[id] = entry
	var seen: Dictionary = {}
	for pool_id in data.pools:
		var pool: Variant = data.pools[pool_id]
		if not pool is Array or pool.is_empty():
			rules.fail("pools.%s must be a nonempty list" % pool_id)
			continue
		for entry in pool:
			var check: RefCounted = rules.at("pools.%s[%s]" % [pool_id, str(entry.get("id", "?")) if entry is Dictionary else "?"])
			if entry is Dictionary and seen.has(entry.get("id")):
				check.fail("backfire ids must be unique across pools")
			elif _check_backfire(check, entry, result, issues):
				seen[entry.id] = true
		result.pools[pool_id] = pool


static func _check_backfire(check: RefCounted, entry: Variant, result: Dictionary, issues: Dictionary) -> bool:
	if not entry is Dictionary:
		return check.fail("must be an object")
	var ok: bool = check.text(entry, "id") and check.number_between(entry, "weight", 0.01, 100.0)
	ok = check.integer_between(entry, "severity", 1, 3) and check.one_of(entry, "delay", DELAYS) and ok
	ok = check.integer_between(entry, "delay_minutes", 0, 600) and ok
	if not result.archetypes.has(entry.get("archetype")):
		ok = check.fail("archetype must be one of backfires.archetypes")
	if not entry.get("recoveries") is Array or entry.recoveries.is_empty() \
			or not entry.recoveries.all(func(item: Variant) -> bool: return result.recoveries.has(item)):
		ok = check.fail("recoveries must list known recoveries")
	if not entry.get("effects") is Array or entry.effects.is_empty():
		return check.fail("effects must be a nonempty list")
	for effect in entry.effects:
		ok = _check_effect(check, effect, issues) and ok
	return ok


static func _check_effect(check: RefCounted, effect: Variant, issues: Dictionary) -> bool:
	if not effect is Dictionary or not BACKFIRE_DO.has(effect.get("do")):
		return check.fail("effect do must be one of %s" % str(BACKFIRE_DO))
	match str(effect.do):
		"device_fault", "area_fault":
			var ok: bool = check.one_of(effect, "fault", CatalogIssues.FAULTS) and check.number_between(effect, "block", 0.0, 1.0)
			ok = check.one_of(effect, "on", EFFECT_ON) and ok
			if effect.get("on") == "random":
				ok = check.integer_between(effect, "count", 1, 20) and ok
			return ok
		"open_tickets":
			if not issues.has(effect.get("issue")):
				return check.fail("open_tickets needs a known issue")
			return check.integer_between(effect, "count", 1, 10) and check.one_of(effect, "on", EFFECT_ON)
		"false_close":
			return check.one_of(effect, "which", ["intent", "all"])
		"confidence":
			return check.integer_between(effect, "amount", -30, 0)
		"mood":
			return check.number_between(effect, "amount", -1.0, 0.0) and check.one_of(effect, "on", EFFECT_ON)
	return true


static func _load_actions(errors: Array[String], data: Dictionary, result: Dictionary, issues: Dictionary, upgrades: Dictionary) -> void:
	var rules := DataRules.new(errors, "actions.json")
	if not rules.list(data, "actions", false):
		return
	rules.unique_ids(data.actions)
	var upgrade_ids: Array = []
	for entry in upgrades.get("upgrades", []):
		if entry is Dictionary:
			upgrade_ids.append(entry.get("id"))
	for entry in data.actions:
		if not entry is Dictionary:
			continue
		var check: RefCounted = rules.at("actions[%s]" % str(entry.get("id", "?")))
		var ok: bool = check.text(entry, "id") and check.text(entry, "label") and check.one_of(entry, "kind", ACTION_KINDS)
		ok = check.one_of(entry, "risk_class", RISK_CLASSES) and check.boolean(entry, "rollback") and ok
		if not result.pools.has(entry.get("backfires")):
			ok = check.fail("backfires must name a pool in backfires.json")
		if not entry.get("requires") is String or (entry.requires != "" and not upgrade_ids.has(entry.requires)):
			ok = check.fail("requires must be empty or an upgrade id")
		if not entry.get("intents") is Array or entry.intents.is_empty() \
				or not entry.intents.all(func(item: Variant) -> bool: return item == "queue" or issues.has(item)):
			ok = check.fail("intents must list issue ids or queue")
		if not entry.get("scopes") is Array or entry.scopes.is_empty() or not entry.scopes.all(func(item: Variant) -> bool: return SCOPES.has(item)):
			ok = check.fail("scopes must list known scopes")
		if entry.get("kind") == "automation":
			ok = check.one_of(entry, "cadence", CADENCES) and ok
		if not entry.get("success") is Array or entry.success.is_empty() \
				or not entry.success.all(func(item: Variant) -> bool: return item is Dictionary and SUCCESS_DO.has(item.get("do"))):
			ok = check.fail("success must list known effects")
		if ok:
			result.actions[entry.id] = entry
			result.action_ids.append(entry.id)


static func _load_upgrades(errors: Array[String], data: Dictionary, result: Dictionary) -> void:
	var rules := DataRules.new(errors, "patch_upgrades.json")
	if not rules.list(data, "upgrades", false):
		return
	var ids: Array = rules.unique_ids(data.upgrades)
	for entry in data.upgrades:
		if not entry is Dictionary:
			continue
		var check: RefCounted = rules.at("upgrades[%s]" % str(entry.get("id", "?")))
		var ok: bool = check.text(entry, "id") and check.text(entry, "label") and check.text(entry, "says")
		ok = check.one_of(entry, "track", TRACKS) and check.integer_between(entry, "cost", 1, 20) and ok
		if not entry.get("requires") is Array or not entry.requires.all(func(item: Variant) -> bool: return ids.has(item)):
			ok = check.fail("requires must list upgrade ids")
		if not entry.get("effects") is Array or entry.effects.is_empty():
			ok = check.fail("effects must be a nonempty list")
		else:
			for effect in entry.effects:
				ok = _check_upgrade_effect(check, effect, result) and ok
		if ok:
			result.upgrades[entry.id] = entry
			result.upgrade_ids.append(entry.id)


static func _check_upgrade_effect(check: RefCounted, effect: Variant, result: Dictionary) -> bool:
	if not effect is Dictionary or not UPGRADE_DO.has(effect.get("do")):
		return check.fail("effect do must be one of %s" % str(UPGRADE_DO))
	match str(effect.do):
		"risk_scale", "recovery_speed", "cadence_scale":
			return check.number_between(effect, "value", 0.1, 1.0)
		"unlock_safeguard":
			return check.one_of(effect, "safeguard", SAFEGUARDS)
		"archetype_scale":
			return check.one_of(effect, "archetype", result.archetypes.keys()) and check.number_between(effect, "value", 0.05, 1.0)
		"unlock_action":
			if not result.actions.has(effect.get("action")):
				return check.fail("unlock_action needs a known action")
	return true


## Every line the game will ask PATCH for exists.
static func _check_text(errors: Array[String], result: Dictionary) -> void:
	text.reload()
	errors.append_array(text.problems())
	var required: Array = []
	for id in result.action_ids:
		for part in ["propose", "benefit", "success"]:
			required.append("action.%s.%s" % [id, part])
	for pool_id in result.pools:
		for entry in result.pools[pool_id]:
			if entry is Dictionary:
				for part in ["label", "line", "callback"]:
					required.append("backfire.%s.%s" % [str(entry.get("id")), part])
	for id in result.recoveries:
		required.append("recovery.%s.done" % id)
	for key in text.missing(required):
		errors.append("text_patch.json: missing label " + key)
