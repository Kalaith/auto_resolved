extends RefCounted
## How the company sees IT: confidence (management's trust, 0..100), staff
## productivity, the backlog, and running tallies for the day and the job that
## the end-of-day card, the exit interview and PATCH Points read.
const Balance = preload("res://addons/hatchery/core/balance.gd")

var confidence: float = 60.0
## Mean productivity of the staff in the building right now, 0..1.
var productivity: float = 1.0
var day: Dictionary = {}
var job: Dictionary = {}
## Confidence at the end of each finished day, oldest first.
var confidence_by_day: Array[float] = []
var _drain: float = 0.0
var _fix_gain: float = 0.0
var _fast_gain: float = 0.0
var _mood_drop: float = 0.0
var _mood_recover: float = 0.0
var _mood_rest: float = 0.7


func _init() -> void:
	confidence = Balance.number("metrics.confidence_start")
	_drain = Balance.number("metrics.overdue_drain_per_hour")
	_fix_gain = Balance.number("metrics.fix_gain")
	_fast_gain = Balance.number("metrics.fast_fix_gain")
	_mood_drop = Balance.number("metrics.mood_drop_per_hour")
	_mood_recover = Balance.number("metrics.mood_recover_per_hour")
	_mood_rest = Balance.number("metrics.mood_rest")
	job = _blank()
	day = _blank()


static func _blank() -> Dictionary:
	return {
		"opened": 0, "resolved": 0, "by_player": 0, "by_patch": 0, "overdue_minutes": 0.0,
		"productivity_sum": 0.0, "productivity_minutes": 0.0, "incidents": 0, "recovered": 0,
		"executions": 0, "backfires": 0, "automation_runs": 0, "people": {},
	}


func begin_day() -> void:
	day = _blank()


func end_day() -> void:
	confidence_by_day.append(confidence)


func on_ticket_opened(_ticket: RefCounted) -> void:
	_count("opened")


func on_ticket_resolved(ticket: RefCounted, now: float) -> void:
	_count("resolved")
	_count("by_player" if ticket.resolved_by == "player" else "by_patch")
	if not ticket.reporter.is_empty():
		day.people[ticket.reporter] = true
		job.people[ticket.reporter] = true
	var gain: float = _fix_gain * float(ticket.severity)
	if now - ticket.created < (ticket.deadline - ticket.created) * 0.5:
		gain += _fast_gain
	if now > ticket.deadline:
		gain *= 0.4
	add_confidence(gain)


func add_confidence(amount: float) -> void:
	confidence = clampf(confidence + amount, 0.0, 100.0)


func count(key: String, amount: int = 1) -> void:
	_count(key, amount)


func _count(key: String, amount: int = 1) -> void:
	day[key] = int(day[key]) + amount
	job[key] = int(job[key]) + amount


## Advances people and confidence by `minutes` of office time.
func step(office: RefCounted, minutes: float) -> void:
	var hours: float = minutes / 60.0
	var now: float = office.clock.stamp()
	var overdue: float = 0.0
	for ticket in office.helpdesk.queue.open_tickets():
		if ticket.is_overdue(now):
			overdue += float(ticket.severity)
			day.overdue_minutes = float(day.overdue_minutes) + minutes
			job.overdue_minutes = float(job.overdue_minutes) + minutes
	add_confidence(-_drain * overdue * hours)
	var total: float = 0.0
	var present: int = 0
	for person in office.staff:
		if not person.present:
			continue
		present += 1
		var block: float = office.block_for(person)
		if block > 0.0:
			person.mood = maxf(0.0, person.mood - _mood_drop * block * (1.2 - person.patience) * hours)
		else:
			person.mood = move_toward(person.mood, _mood_rest, _mood_recover * hours)
		person.productivity = (1.0 - block) * (0.75 + 0.25 * person.mood)
		total += person.productivity
	productivity = total / float(present) if present > 0 else 1.0
	if present > 0:
		day.productivity_sum = float(day.productivity_sum) + productivity * minutes
		day.productivity_minutes = float(day.productivity_minutes) + minutes
		job.productivity_sum = float(job.productivity_sum) + productivity * minutes
		job.productivity_minutes = float(job.productivity_minutes) + minutes


## Average productivity over a tally (day or job), 0..1.
static func average_productivity(tally: Dictionary) -> float:
	var minutes: float = float(tally.productivity_minutes)
	return float(tally.productivity_sum) / minutes if minutes > 0.0 else 1.0


func to_dict() -> Dictionary:
	return {"confidence": confidence, "job": job.duplicate(true), "confidence_by_day": confidence_by_day.duplicate()}
