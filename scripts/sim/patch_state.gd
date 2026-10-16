extends RefCounted
## PATCH itself: the one character that carries from job to job. Its bought
## upgrades, the failure archetypes it has met, the guardrails promoted to
## permanent knowledge and the incidents it remembers (for callbacks). Every
## mechanical effect of an upgrade is read through the functions here, so the
## sim never inspects upgrade ids directly.
const Catalog = preload("res://scripts/core/catalog.gd")

## Upgrade ids in the order they were bought.
var upgrades: Array[String] = []
## Failure archetypes PATCH has caused at least once, in any job.
var archetypes_seen: Array[String] = []
## Archetypes guarded forever (promoted at an exit interview).
var guardrails: Array[String] = []
## Backfire ids PATCH remembers causing, for callbacks in later jobs.
var memories: Array[String] = []
## How many jobs PATCH has been through (0 during the first).
var jobs_done: int = 0


func version() -> String:
	return "1.%d" % upgrades.size()


func has(upgrade_id: String) -> bool:
	return upgrades.has(upgrade_id)


func _effects(kind: String) -> Array:
	var found: Array = []
	for id in upgrades:
		if not Catalog.upgrades.has(id):
			continue
		for effect in Catalog.upgrade(id).effects:
			if effect.do == kind:
				found.append(effect)
	return found


## The version multiplier: the product of every Reliability upgrade.
func risk_scale() -> float:
	var scale: float = 1.0
	for effect in _effects("risk_scale"):
		scale *= float(effect.value)
	return scale


## How likely `archetype` is relative to v1.0 (Understanding upgrades).
func archetype_scale(archetype: String) -> float:
	var scale: float = 1.0
	for effect in _effects("archetype_scale"):
		if effect.archetype == archetype:
			scale *= float(effect.value)
	return scale


func safeguards() -> Array[String]:
	var result: Array[String] = ["staged", "dry_run"]
	for effect in _effects("unlock_safeguard"):
		result.append(str(effect.safeguard))
	return result


func can_propose(action_id: String) -> bool:
	var requires: String = str(Catalog.action(action_id).requires)
	return requires.is_empty() or has(requires)


func precise_risk() -> bool:
	return not _effects("precise_risk").is_empty()


func remote_session() -> bool:
	return not _effects("remote_session").is_empty()


func limited_autonomy() -> bool:
	return not _effects("limited_autonomy").is_empty()


func recovery_scale() -> float:
	var scale: float = 1.0
	for effect in _effects("recovery_speed"):
		scale *= float(effect.value)
	return scale


func cadence_scale() -> float:
	var scale: float = 1.0
	for effect in _effects("cadence_scale"):
		scale *= float(effect.value)
	return scale


func remember(backfire_id: String, archetype: String) -> bool:
	if not memories.has(backfire_id):
		memories.append(backfire_id)
	if archetypes_seen.has(archetype):
		return false
	archetypes_seen.append(archetype)
	return true


func to_dict() -> Dictionary:
	return {
		"version": version(), "upgrades": upgrades.duplicate(), "archetypes_seen": archetypes_seen.duplicate(),
		"guardrails": guardrails.duplicate(), "memories": memories.duplicate(), "jobs_done": jobs_done,
	}


static func from_dict(data: Dictionary) -> RefCounted:
	var state: RefCounted = load("res://scripts/sim/patch_state.gd").new()
	for key in ["upgrades", "archetypes_seen", "guardrails", "memories"]:
		var target: Array[String] = state.get(key)
		for value in data.get(key, []):
			if value is String and not target.has(value):
				target.append(value)
	state.jobs_done = int(data.get("jobs_done", 0))
	return state
