extends Node
## The career between and around jobs: the title, starting or continuing a
## job, the end of each workday (warnings, dismissal, notice, the save), the
## exit interview, PATCH's update and the job board. Owns the Career and its
## save; main.gd owns the office while a job runs.
const Career = preload("res://scripts/sim/career.gd")
const CareerStore = preload("res://scripts/core/career_store.gd")
const CareerRules = preload("res://scripts/sim/career_rules.gd")
const OfficeSnapshot = preload("res://scripts/sim/office_snapshot.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const ScreenSwitcher = preload("res://addons/hatchery/ui/screen_switcher.gd")
const TitleScreen = preload("res://scripts/ui/screens/title_screen.gd")
const ExitInterview = preload("res://scripts/ui/screens/exit_interview.gd")
const UpgradeScreen = preload("res://scripts/ui/screens/upgrade_screen.gd")
const JobBoardScreen = preload("res://scripts/ui/screens/job_board.gd")
const FinaleScreen = preload("res://scripts/ui/screens/finale.gd")
const DayReport = preload("res://scripts/ui/day_report.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const RunReport = preload("res://scripts/run_report.gd")

var main: Node
var store := CareerStore.new()
var career: RefCounted = null
var screens: ScreenSwitcher
var _layer: CanvasLayer
var _seeds := RandomNumberGenerator.new()


func _ready() -> void:
	_seeds.randomize()
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	screens = ScreenSwitcher.new(_layer)


func _ui() -> RefCounted:
	return main.hud.ui


func show_title(problem: String = "") -> void:
	main.end_job()
	var screen: Control = TitleScreen.new()
	screen.saved = _saved_line()
	screen.problem = problem if not problem.is_empty() else store.last_error()
	screen.setup(_ui())
	screen.continue_chosen.connect(_continue)
	screen.new_chosen.connect(_new_career)
	screen.settings_chosen.connect(func() -> void: main.open_settings())
	screens.show(screen)


func _saved_line() -> String:
	if not store.exists():
		return ""
	var saved: RefCounted = store.load_career()
	if saved == null:
		return ""
	var where: String = "between jobs"
	if saved.stage == "job":
		where = "day %d at a %s" % [int(saved.current_job.day) + 1, str(saved.current_job.archetype).replace("_", " ")]
	return "PATCH v%s, reputation %d, $%d earned, %d jobs done; %s." % [saved.patch.version(), saved.reputation, saved.earnings, saved.history.size(), where]


func _continue() -> void:
	career = store.load_career()
	if career == null:
		show_title("Could not continue the career. " + store.last_error())
		return
	_resume()


func _new_career() -> void:
	var previous: RefCounted = store.load_career() if store.exists() else null
	if store.exists() and not store.keep_previous():
		show_title(store.last_error())
		return
	if previous != null and previous.stage == "job":
		main.analytics.run_ended(RunReport.abandoned(previous, main.analytics.run_seconds()))
	career = Career.fresh(_seeds.randi_range(1, 2147483646))
	_save()
	_resume()


func _resume() -> void:
	match career.stage:
		"job":
			_start_job(false)
		"upgrades":
			_show_upgrades()
		_:
			if career.offers.is_empty():
				career.make_offers()
				_save()
			_show_board()


## `fresh`: the job was just taken from the board, so its run report goes
## out; a continued job only restarts the run clock.
func _start_job(fresh: bool) -> void:
	var job: Dictionary = career.current_job
	main.start_job(str(job.archetype), int(job.seed), career.patch, job.state, int(job.day) + 1, career.companion_list())
	if not fresh:
		main.analytics.run_started({})
	else:
		main.analytics.run_started(RunReport.started(career, main.office))
		if not career.history.is_empty():
			main.analytics.milestone_once("second_company_started")
	if career.history.is_empty() and int(job.day) == 0:
		main.tutorial.start()


## Removes whichever between-jobs screen is showing (a job is starting).
func clear_screen() -> void:
	if is_instance_valid(screens.current):
		screens.current.queue_free()
	screens.current = null


func _save() -> bool:
	if career == null:
		return true
	if store.save(career):
		return true
	main.hud.toast("Could not save: " + store.last_error())
	return false


## The office closed for the day: judge it, save it, and either end the job
## or show the day's card.
func on_day_ended(office: RefCounted, day: int) -> void:
	if career == null:
		main.hud.notice.open("Day %d is over" % day, DayReport.body(office), [["Start day %d" % (day + 1), func() -> void: office.begin_day(day + 1), true]])
		return
	var verdict: String = CareerRules.judge_day(office)
	if verdict == "warning" or verdict == "final_warning":
		office.summon_manager()
	career.current_job.day = day
	career.current_job.state = OfficeSnapshot.capture(office)
	_save()
	if verdict == "fired":
		main.hud.notice.open("You are being let go", "Management has lost confidence in IT. Security will see you out. Politely.", [["Exit interview", func() -> void: _exit(office, "fired"), true]])
		return
	if office.notice_given:
		_exit(office, "quit")
		return
	var body: String = DayReport.body(office) + _verdict_line(verdict)
	main.hud.notice.open("Day %d is over" % day, body, [
		["Hand in notice", func() -> void: _exit(office, "quit")],
		["Start day %d" % (day + 1), func() -> void: office.begin_day(day + 1), true]])


func _verdict_line(verdict: String) -> String:
	match verdict:
		"warning":
			return "\n\nEMAIL from management: \"Confidence in IT is slipping. Someone will drop by tomorrow.\" (warning 1 of 2)"
		"final_warning":
			return "\n\nEMAIL from management: \"This is a final warning. Things need to improve by tomorrow evening.\""
		"forgiven":
			return "\n\nManagement noticed the improvement. One warning is withdrawn."
	return ""


## Hand in notice during the day: the job ends when today does.
func hand_in_notice(office: RefCounted) -> void:
	office.notice_given = true
	office.patch_desk.say(Catalog.say("patch.notice"))
	main.hud.toast("Notice handed in. Today is your last day here.")


func _exit(office: RefCounted, ended: String) -> void:
	var points: Dictionary = CareerRules.points(office, ended)
	var grade: String = CareerRules.grade(office, ended)
	var change: int = CareerRules.reputation_change(grade, ended)
	var stats: Dictionary = CareerRules.summary(office)
	var screen: Control = ExitInterview.new()
	screen.company = office.job.company_name
	screen.ended = ended
	screen.stats = stats
	screen.points = points
	screen.grade = grade
	screen.reputation_change = change
	for archetype in office.patch_desk.job_guardrails:
		screen.guardrails.append(archetype)
	screen.setup(_ui())
	var record: Dictionary = {"archetype": office.job.archetype_id, "name": office.job.company_name, "tier": office.job.tier,
		"days": int(stats.days), "ended": ended, "grade": grade, "points": int(points.total), "pay": int(stats.pay)}
	var memories: Dictionary = _companion_memories(office)
	main.analytics.run_ended(RunReport.ended(career, office, ended, main.analytics.run_seconds()))
	main.analytics.milestone_once("first_job_ended")
	screen.done.connect(func(promoted: String) -> void:
		career.finish_job(record, int(points.total), change, promoted)
		career.follow_from(str(office.job.company_name), memories)
		_save()
		_show_upgrades())
	main.end_job()
	screens.show(screen)


## What each recurring person takes from this job to the next: their own
## latest incident if they were here, else the job's latest incident.
func _companion_memories(office: RefCounted) -> Dictionary:
	var latest: String = ""
	for incident in office.patch_desk.incidents:
		latest = str(incident.archetype)
	var memories: Dictionary = {}
	for entry in Catalog.people.get("recurring", []):
		memories[str(entry.id)] = latest
	for person in office.staff:
		if person.followed_from.is_empty():
			continue
		for entry in Catalog.people.get("recurring", []):
			if str(entry.name) == person.name:
				for note in person.history:
					if note.begins_with("incident:"):
						memories[str(entry.id)] = note.trim_prefix("incident:")
	return memories


func _show_upgrades() -> void:
	main.end_job()
	var screen: Control = UpgradeScreen.new()
	screen.career = career
	screen.setup(_ui())
	screen.buy_chosen.connect(func(id: String) -> void:
		if career.buy(id):
			if _save():
				main.analytics.milestone_once("first_patch_upgrade")
			else:
				career.refund(id)
				screen.message = "The save failed, so nothing was spent. " + store.last_error()
		screen.rebuild())
	screen.finished.connect(func() -> void:
		if career.finale_due():
			_show_finale()
			return
		career.make_offers()
		_save()
		_show_board())
	screens.show(screen)


## The career's closing beat; afterwards it carries on to the job board.
func _show_finale() -> void:
	main.end_job()
	main.analytics.game_completed()
	var screen: Control = FinaleScreen.new()
	screen.career = career
	screen.setup(_ui())
	screen.keep_working.connect(func() -> void:
		career.finale_seen = true
		career.make_offers()
		_save()
		_show_board())
	screen.title_chosen.connect(func() -> void:
		career.finale_seen = true
		career.make_offers()
		_save()
		show_title())
	screens.show(screen)


func _show_board() -> void:
	main.end_job()
	var screen: Control = JobBoardScreen.new()
	screen.career = career
	screen.setup(_ui())
	screen.offer_taken.connect(func(index: int) -> void:
		career.take_offer(index)
		_save()
		_start_job(true))
	screen.title_chosen.connect(func() -> void: show_title())
	screens.show(screen)
