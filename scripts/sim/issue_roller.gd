extends RefCounted
## Decides when things break. Every few office minutes each device rolls for
## each issue that can hit it, at the issue's rate per device per day, scaled
## up by company tier and by how many days you have worked there, and down by
## whatever prevention PATCH has in place. The first day opens with three
## teaching tickets so there is something to do straight away. All draws come
## from the job's "issues" stream.
const Catalog = preload("res://scripts/core/catalog.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Det = preload("res://addons/hatchery/core/det.gd")

## The first morning: [minute, issue, device kind].
const STARTERS: Array = [[492.0, "password", "workstation"], [506.0, "printer_offline", "printer"], [520.0, "software_install", "workstation"]]

var rng: RandomNumberGenerator
var _next_roll: float = 0.0
var _pending_starters: Array = []
var _every: float = 10.0


func _init(job_seed: int) -> void:
	rng = Det.fork(job_seed, "issues")
	_every = Balance.number("issues.roll_every_minutes")


func begin_day(day: int, start_minute: float) -> void:
	_next_roll = start_minute + _every
	_pending_starters = STARTERS.duplicate(true) if day == 1 else []


## Opens whatever breaks between the last roll and `minute`.
func step(office: RefCounted, minute: float) -> void:
	_open_starters(office, minute)
	while minute >= _next_roll:
		_roll(office, _next_roll)
		_next_roll += _every


func _open_starters(office: RefCounted, minute: float) -> void:
	while not _pending_starters.is_empty() and minute >= float(_pending_starters[0][0]):
		var starter: Array = _pending_starters.pop_front()
		var candidates: Array = _candidates(office, Catalog.issue(str(starter[1])), str(starter[2]))
		if not candidates.is_empty():
			office.helpdesk.open_ticket(office, str(starter[1]), Det.pick(rng, candidates))


func _roll(office: RefCounted, minute: float) -> void:
	if minute >= Balance.number("day.leaving_start_minute"):
		return
	if office.helpdesk.queue.open_count() >= Balance.integer("issues.max_open"):
		return
	var clock: RefCounted = office.clock
	var window: float = _every / (clock.end_minute - clock.start_minute)
	var scale: float = (1.0 + Balance.number("issues.tier_scale") * float(office.job.tier - 1)) \
		* (1.0 + Balance.number("issues.day_scale") * float(clock.day - 1))
	for issue_id in Catalog.issue_ids:
		var issue: Dictionary = Catalog.issue(issue_id)
		if int(issue.min_tier) > office.job.tier:
			continue
		for kind in issue.devices:
			for device in _candidates(office, issue, str(kind)):
				var chance: float = float(issue.per_device_per_day) * window * scale * office.issue_factor(issue_id, device)
				if Det.chance(rng, chance):
					office.helpdesk.open_ticket(office, issue_id, device)


## Devices of `kind` that `issue` could hit now: no open ticket already, and
## a workstation only while its owner is in the building.
func _candidates(office: RefCounted, issue: Dictionary, kind: String) -> Array:
	var result: Array = []
	for device in office.devices:
		if device.kind != kind or not office.helpdesk.queue.open_for_device(device.id).is_empty():
			continue
		if kind == "workstation":
			var owner: RefCounted = office.employee(device.owner)
			if owner == null or not owner.present:
				continue
		if issue.spread == "floor" and kind == "network_core" and office.staffed_floors().is_empty():
			continue
		result.append(device)
	return result
