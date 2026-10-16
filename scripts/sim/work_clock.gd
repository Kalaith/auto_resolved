extends RefCounted
## The workday clock: which day of the job it is and the minute of that day
## (minutes since midnight, so 540 is 09:00). It advances with simulation
## seconds at a rate that fits the whole workday into `day.real_seconds`.
const Balance = preload("res://addons/hatchery/core/balance.gd")

const PHASES: Array[String] = ["arrival", "morning", "lunch", "afternoon", "leaving"]

var day: int = 1
var minute: float = 0.0
var start_minute: float = 0.0
var end_minute: float = 0.0
var minutes_per_second: float = 1.0
var _arrival_end: float = 0.0
var _lunch_start: float = 0.0
var _lunch_end: float = 0.0
var _leaving_start: float = 0.0


func _init() -> void:
	start_minute = Balance.number("day.start_minute")
	end_minute = Balance.number("day.end_minute")
	_arrival_end = Balance.number("day.arrival_end_minute")
	_lunch_start = Balance.number("day.lunch_start_minute")
	_lunch_end = Balance.number("day.lunch_end_minute")
	_leaving_start = Balance.number("day.leaving_start_minute")
	minutes_per_second = (end_minute - start_minute) / Balance.number("day.real_seconds")
	minute = start_minute


## Advances by `seconds` of simulation time. True on the step the day ends.
func step(seconds: float) -> bool:
	if is_over():
		return false
	minute = minf(minute + seconds * minutes_per_second, end_minute)
	return is_over()


func is_over() -> bool:
	return minute >= end_minute


func begin_day(index: int) -> void:
	day = index
	minute = start_minute


## Minutes since the job began: day 1 at 00:00 is 0. Tickets and incidents
## stamp themselves with this so deadlines work across days.
func stamp() -> float:
	return float(day - 1) * 1440.0 + minute


func phase() -> String:
	if minute < _arrival_end:
		return "arrival"
	if minute < _lunch_start:
		return "morning"
	if minute < _lunch_end:
		return "lunch"
	if minute < _leaving_start:
		return "afternoon"
	return "leaving"


## 0 at the start of the workday, 1 at its end.
func progress() -> float:
	return clampf((minute - start_minute) / (end_minute - start_minute), 0.0, 1.0)


static func hhmm(at: float) -> String:
	var whole: int = int(at) % 1440
	return "%02d:%02d" % [whole / 60, whole % 60]
