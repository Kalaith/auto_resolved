extends RefCounted
## The chance one PATCH execution backfires (GDD 7.2):
##   clamp(base x version x scope x safeguards x context, minimum, maximum)
## where context is the company tier's unfamiliarity times the backfire pool's
## archetype mix (Understanding upgrades and guardrails thin out the
## archetypes they cover). Every factor comes from balance.json. The number is
## never zero, and the player sees it as a band.
const Catalog = preload("res://scripts/core/catalog.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")


## The backfire chance before guardrails stop anything: what the roll uses.
static func raw(action_id: String, scope: String, safeguards: Array, patch: RefCounted, tier: int) -> float:
	var action: Dictionary = Catalog.action(action_id)
	var p: float = Balance.number("risk.base." + str(action.risk_class))
	p *= patch.risk_scale()
	p *= Balance.number("risk.scope." + scope)
	if safeguards.has("staged") and scope != "ticket":
		p *= Balance.number("risk.staged")
	if safeguards.has("dry_run"):
		p *= Balance.number("risk.dry_run")
	if safeguards.has("confirm_delete") and action.risk_class == "destructive":
		p *= Balance.number("risk.confirm_delete")
	p *= 1.0 + Balance.number("risk.tier_step") * float(tier - 1)
	p *= _mix(action, patch, [])
	return clampf(p, Balance.number("risk.minimum"), Balance.number("risk.maximum"))


## The expected chance after guardrails catch what they cover: what the
## proposal card shows.
static func shown(action_id: String, scope: String, safeguards: Array, patch: RefCounted, tier: int, guarded: Array) -> float:
	var p: float = raw(action_id, scope, safeguards, patch, tier)
	var action: Dictionary = Catalog.action(action_id)
	var unguarded: float = _mix(action, patch, [])
	if unguarded <= 0.0:
		return p
	return maxf(p * _mix(action, patch, guarded) / unguarded, Balance.number("risk.minimum"))


## The pool's weighted archetype scale: 1 at v1.0 with no guardrails.
static func _mix(action: Dictionary, patch: RefCounted, guarded: Array) -> float:
	var total: float = 0.0
	var kept: float = 0.0
	for entry in Catalog.pools[action.backfires]:
		var weight: float = float(entry.weight)
		total += weight
		var scale: float = patch.archetype_scale(str(entry.archetype))
		if guarded.has(entry.archetype):
			scale *= Balance.number("risk.guardrail")
		kept += weight * scale
	return kept / total if total > 0.0 else 1.0


## "Low (2-6%)": a range around `p`, narrow with the Ticket context upgrade.
static func band(p: float, precise: bool) -> String:
	var low: float = p * Balance.number("risk.band_precise_low" if precise else "risk.band_low")
	var high: float = minf(p * Balance.number("risk.band_precise_high" if precise else "risk.band_high"), 0.95)
	return "%s (%s-%s%%)" % [word(p), _percent(low), _percent(high)]


static func word(p: float) -> String:
	if p < 0.05:
		return "Low"
	if p < 0.12:
		return "Moderate"
	if p < 0.25:
		return "High"
	return "Severe"


static func _percent(value: float) -> String:
	var percent: float = value * 100.0
	if percent < 1.0:
		return "%.1f" % percent
	return str(roundi(percent))
