extends SceneTree
## Analytics for Hatchery Signals: data/analytics.json must read cleanly,
## every milestone the game sends must be a snake_case id, and job reports
## from scripted careers (a job worked by hand for a few days, then quit, and
## a saved job abandoned) must pass the portal's shape rules (the toolkit's
## telemetry/report_rules.gd), name only catalogue ids, and survive the
## unsent-queue file's JSON round trip with their counts still integers.
## Seconds; prints FAIL lines and exits 1 on a problem.
##
## With `-- --endpoint=http://127.0.0.1:8765/events` it also sends a real batch
## through the toolkit's signals_client.gd to that address (a local server,
## never the live portal) and expects HTTP 202.
##
## Run: godot --headless --path . --script res://tools/analytics_check.gd

const Catalog = preload("res://scripts/core/catalog.gd")
const Career = preload("res://scripts/sim/career.gd")
const Job = preload("res://scripts/sim/job.gd")
const OfficeSim = preload("res://scripts/sim/office_sim.gd")
const RunReport = preload("res://scripts/run_report.gd")
const SignalsClient = preload("res://addons/hatchery/telemetry/signals_client.gd")
const SignalsConfig = preload("res://addons/hatchery/telemetry/signals_config.gd")
const ReportRules = preload("res://addons/hatchery/telemetry/report_rules.gd")
const JsonIo = preload("res://addons/hatchery/core/json_io.gd")
const AtomicFile = preload("res://addons/hatchery/storage/atomic_file.gd")
const LaunchArgs = preload("res://addons/hatchery/settings/launch_args.gd")

const CONFIG := "res://data/analytics.json"
const SEEDS: Array[int] = [5, 17, 29]
const DAYS: int = 2
const WALK_MINUTES: float = 10.0
## Where milestone_once("...") calls live.
const SOURCES: Array[String] = ["res://scripts/main.gd", "res://scripts/career_flow.gd"]
const SEND_TIMEOUT := 20.0
const IDS_FILE := "user://analytics_check_ids.json"
const QUEUE_FILE := "user://analytics_check_queue.json"

var _failures: int = 0
var _client: SignalsClient
var _waited: float = 0.0
var _replies: Array[int] = []
var _sent: int = 0
var _expected: int = 0


func _initialize() -> void:
	var problems: Array[String] = Catalog.problems()
	if not problems.is_empty():
		for problem in problems:
			print("DATA  ", problem)
		quit(1)
		return
	var errors: Array[String] = []
	SignalsConfig.read(CONFIG, errors)
	for error in errors:
		_check(false, "config: %s" % error)
	_check_milestones()
	var reports: Array[Dictionary] = []
	for seed_value in SEEDS:
		reports.append_array(_play_career(seed_value))
	print("analytics_check: %d reports from %d careers" % [reports.size(), SEEDS.size()])
	var endpoint: String = LaunchArgs.value("endpoint")
	if endpoint.is_empty():
		_finish()
		return
	# The client's HTTPRequest needs the running tree, which starts after this.
	_send.call_deferred(endpoint, reports)


## A fresh career takes its first offer, works DAYS days by hand and quits;
## then a second career is abandoned part-way through its first job.
func _play_career(seed_value: int) -> Array[Dictionary]:
	var where: String = "seed %d" % seed_value
	var career: RefCounted = Career.fresh(seed_value)
	career.make_offers()
	career.take_offer(0)
	var job: RefCounted = Job.create(str(career.current_job.archetype), int(career.current_job.seed))
	var office: RefCounted = OfficeSim.create(job, career.patch)
	var started: Dictionary = RunReport.started(career, office)
	for day in range(1, DAYS + 1):
		_work_day(office, day)
	var ended: Dictionary = RunReport.ended(career, office, "quit", 600)
	_check(int(ended["days"]) == DAYS, "%s: %d days reported, expected %d" % [where, int(ended["days"]), DAYS])
	_check(int(ended["issues_fixed"]) > 0, "%s: no issues fixed in %d days" % [where, DAYS])
	var abandoned: Dictionary = RunReport.abandoned(career, 120)
	var reports: Array[Dictionary] = [started, ended, abandoned]
	for report in reports:
		var label: String = "%s %s" % [where, str(report.get("outcome", "started"))]
		for problem in ReportRules.problems(report):
			_check(false, "%s: %s" % [label, problem])
		_check_ids(report, label)
		_check_round_trip(report, label)
	return reports


## Fixes the most urgent open ticket back to back until the evening.
func _work_day(office: RefCounted, day: int) -> void:
	office.begin_day(day)
	var free_at: float = office.clock.stamp()
	while office.day_running:
		office.step(OfficeSim.TICK * 6.0)
		var open: Array = office.helpdesk.queue.by_urgency()
		if office.clock.stamp() >= free_at and not open.is_empty():
			free_at = office.clock.stamp() + office.helpdesk.fix_effort(open[0]) + WALK_MINUTES
			office.helpdesk.resolve(office, open[0], "player")
	office.drain_events()


func _check_ids(report: Dictionary, where: String) -> void:
	_check(Catalog.archetype_ids.has(str(report["company"])), "%s: company '%s' is not an archetype" % [where, report["company"]])
	_check((report["patch_upgrades"] as Dictionary).size() == Catalog.upgrade_ids.size(), "%s: patch_upgrades does not list every PATCH upgrade" % where)
	for id: Variant in report["patch_upgrades"]:
		_check(Catalog.upgrade_ids.has(str(id)), "%s: '%s' is not a PATCH upgrade" % [where, id])


## Through the queue file's JSON and back: same report, counts still ints.
func _check_round_trip(report: Dictionary, where: String) -> void:
	var back: Variant = JsonIo.from_bytes(JsonIo.bytes({"data": report}))
	var restored: Dictionary = JsonIo.whole_numbers(back)["data"]
	_check(JSON.stringify(restored) == JSON.stringify(report), "%s: report changed through the queue file" % where)
	_check(restored["job_number"] is int, "%s: job_number came back as %s" % [where, type_string(typeof(restored["job_number"]))])


## Every milestone_once("...") name in the game's scripts is snake_case.
func _check_milestones() -> void:
	var call := RegEx.create_from_string("milestone_once\\(\"([^\"]*)\"\\)")
	var snake := RegEx.create_from_string("^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
	var found: int = 0
	for path in SOURCES:
		for result in call.search_all(FileAccess.get_file_as_string(path)):
			found += 1
			var name: String = result.get_string(1)
			_check(snake.search(name) != null, "%s: milestone '%s' is not snake_case" % [path, name])
	_check(found >= 5, "found only %d milestones in %s" % [found, ", ".join(SOURCES)])


func _process(delta: float) -> bool:
	if _client == null:
		return false
	_waited += delta
	if _sent >= _expected or _waited > SEND_TIMEOUT:
		_check(_sent == _expected, "only %d of %d events were answered" % [_sent, _expected])
		for code in _replies:
			_check(code == 202, "local endpoint answered %d, expected 202" % code)
		print("analytics_check: sent %d events in %d batches, HTTP %s" % [_sent, _replies.size(), str(_replies)])
		# Off first, so quitting does not queue (and save) a session end.
		_client.set_enabled(false)
		AtomicFile.remove_all(IDS_FILE)
		AtomicFile.remove_all(QUEUE_FILE)
		_finish()
	return false


func _send(endpoint: String, reports: Array[Dictionary]) -> void:
	AtomicFile.remove_all(IDS_FILE)
	AtomicFile.remove_all(QUEUE_FILE)
	_client = SignalsClient.new()
	_client.ids_path = IDS_FILE
	_client.queue_path = QUEUE_FILE
	_client.endpoint_override = endpoint
	_client.batch_sent.connect(func(code: int, count: int) -> void:
		_replies.append(code)
		_sent += count)
	var ended: Array[Dictionary] = []
	for report in reports:
		if report.has("outcome"):
			ended.append(report)
	# session_started, each ended report and the once-only first_run_finished milestone.
	_expected = 2 + ended.size()
	root.add_child(_client)
	_client.start(CONFIG, true, false, false)
	_check(_client.status != "", "client should stay off until enabled")
	_client.set_enabled(true)
	for report in ended:
		_client.run_ended(report)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL  ", message)


func _finish() -> void:
	print("analytics_check: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)
