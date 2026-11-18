extends "res://addons/hatchery/testing/capture_runner.gd"
## Screenshots of one building per archetype, close up and in overview, a
## ride, and the office through a day:
##   godot --path . --script res://tools/capture.gd -- [--only=<part>]
## Shots go to docs/verification/ (the toolkit's capture runner).
const Catalog = preload("res://scripts/core/catalog.gd")

var only: String = ""


func tour() -> void:
	# The tour runs in a window but never makes a sound.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	var main: Node = await open_scene("res://scenes/main.tscn")
	if only.is_empty() or only == "career":
		await _career(main)
	if only.is_empty() or only == "buildings":
		await _buildings(main)
	if only.is_empty() or only == "day":
		await _day(main)
	if only.is_empty() or only == "patch":
		await _patch(main)
	if only.is_empty() or only == "menus":
		await _menus(main)
	if only.is_empty() or only == "pad":
		await _pad(main)


func _buildings(main: Node) -> void:
	for id in Catalog.archetype_ids:
		main.start_job(id, 1234)
		await seconds(0.6)
		await shot("%s_close" % id)
		main.camera.overview = true
		await seconds(1.2)
		await shot("%s_overview" % id)
		main.camera.overview = false
	await _extremes(main)
	main.start_job("startup", 99)
	main.player.go_to(main.plan.highest, main.plan.width - 60.0)
	await seconds(4.0)
	await shot("route_riding")
	await seconds(5.0)
	await shot("route_arrived")


## The smallest and largest staff roll of each archetype over seeds 1..40,
## in overview at the height of the morning arrival (empty floors, lift
## queues). headcount_report prints the same rolls with their numbers.
func _extremes(main: Node) -> void:
	const Job = preload("res://scripts/sim/job.gd")
	const BuildingPlan = preload("res://scripts/sim/building_plan.gd")
	const StaffFactory = preload("res://scripts/sim/staff_factory.gd")
	for id in Catalog.archetype_ids:
		var rolls: Dictionary = {}
		for seed_value in range(1, 41):
			var job: RefCounted = Job.create(id, seed_value)
			rolls[seed_value] = StaffFactory.create(job, BuildingPlan.generate(job)).size()
		var seeds: Array = rolls.keys()
		seeds.sort_custom(func(a: int, b: int) -> bool: return rolls[a] < rolls[b] or (rolls[a] == rolls[b] and a < b))
		for pair in [["smallest", seeds[0]], ["largest", seeds[-1]]]:
			main.start_job(id, int(pair[1]))
			main.camera.overview = true
			Engine.time_scale = 4.0
			main.set_speed(4.0)
			await _until(main, 535.0)
			Engine.time_scale = 1.0
			main.set_speed(0.0)
			await seconds(0.3)
			await shot("roll_%s_%s" % [id, pair[0]])
	main.camera.overview = false


## The office through a day at high speed: arrival, a working morning, lunch.
func _day(main: Node) -> void:
	main.start_job("accounting_firm", 4321)
	main.camera.overview = true
	Engine.time_scale = 4.0
	main.set_speed(4.0)
	await _until(main, 505.0)
	await shot("day_morning_arrival")
	main.camera.overview = false
	await _until(main, 530.0)
	var open: Array = main.office.helpdesk.queue.by_urgency()
	if not open.is_empty():
		main.work.request(open[0].id)
	await _until(main, 560.0)
	await shot("day_ticket_fix")
	await _until(main, 620.0)
	await shot("day_working_close")
	main.camera.overview = true
	await _until(main, 735.0)
	await shot("day_lunch_crowd")
	await _until(main, 1075.0)
	await shot("day_evening")
	Engine.time_scale = 1.0


## Talking to PATCH: a ticket proposal, the approval, an automation card.
func _patch(main: Node) -> void:
	main.start_job("startup", 777)
	Engine.time_scale = 4.0
	await _until(main, 540.0)
	Engine.time_scale = 1.0
	var open: Array = main.office.helpdesk.queue.by_urgency()
	main.hud.open_patch(main.office, open[0].id if not open.is_empty() else -1)
	await seconds(0.5)
	await shot("patch_ticket_proposal")
	main.hud.patch_panel._card._approve(false)
	await seconds(0.5)
	await shot("patch_after_approval")
	var desk: RefCounted = main.office.patch_desk
	main.hud.patch_panel._show_proposal(desk.propose_category(main.office, "password"))
	await seconds(0.5)
	await shot("patch_automation_card")
	main.hud.patch_panel.close_panel()
	await _incident(main)


## A forced backfire: queue organising deletes every ticket; the incident view.
func _incident(main: Node) -> void:
	var desk: RefCounted = main.office.patch_desk
	desk.forced = "backfire"
	desk.forced_backfire = "deleted_all_tickets"
	main.hud.open_patch(main.office)
	main.hud.patch_panel._show_proposal(desk.propose_queue(main.office, "organize_queue"))
	await seconds(0.3)
	main.hud.patch_panel._card._approve(false)
	await seconds(0.5)
	main.hud.patch_panel.close_panel()
	await seconds(0.3)
	await shot("incident_alert")
	main.hud.incidents.open_for(main.office)
	await seconds(0.5)
	await shot("incident_view")


## The career screens: title, an exit interview after a short job, PATCH's
## update and the job board. Uses a throwaway career that is never saved.
func _career(main: Node) -> void:
	await seconds(0.5)
	await shot("career_title")
	var flow: Node = main.flow
	flow.store.file.enabled = false
	flow.career = preload("res://scripts/sim/career.gd").fresh(4242)
	flow._resume()
	await seconds(0.8)
	await shot("career_tutorial_welcome")
	main.tutorial.acknowledge()
	await seconds(0.3)
	await shot("career_tutorial_it")
	main.office.metrics.end_day()
	main.office.day_summaries.append(main.office.metrics.day.duplicate(true))
	main.office.patch_desk.add_guardrail("bulk_misread")
	flow._exit(main.office, "quit")
	await seconds(0.5)
	await shot("career_exit_interview")
	flow.screens.current.done.emit("bulk_misread")
	await seconds(0.5)
	await shot("career_upgrades")
	flow.screens.current.finished.emit()
	await seconds(0.5)
	await shot("career_job_board")
	await _restored_day(main, flow)
	flow.career = null


## A day saved to JSON and laid back over a freshly built office, as Continue
## does: the incident, its faults and the automation should all come back.
func _restored_day(main: Node, flow: Node) -> void:
	const JsonIO = preload("res://addons/hatchery/core/json_io.gd")
	const Snapshot = preload("res://scripts/sim/office_snapshot.gd")
	const CareerScript = preload("res://scripts/sim/career.gd")
	main.start_job("accounting_firm", 31337, flow.career.patch)
	Engine.time_scale = 4.0
	await _until(main, 540.0)
	var desk: RefCounted = main.office.patch_desk
	desk.forced = "backfire"
	desk.forced_backfire = "everyone_admin"
	desk.approve(main.office, desk.propose_category(main.office, "new_employee") if main.office.patch.has("onboarding_blueprint") else desk.propose_queue(main.office, "organize_queue"), false)
	desk.approve(main.office, desk.propose_category(main.office, "password") if not desk.categories(main.office).is_empty() else desk.propose_queue(main.office, "archive_resolved"), false)
	await _until(main, 600.0)
	Engine.time_scale = 1.0
	flow.career.current_job = {"archetype": "accounting_firm", "seed": 31337, "day": 1, "state": Snapshot.capture(main.office)}
	var text: String = JsonIO.bytes(flow.career.to_dict()).get_string_from_utf8()
	var data: Dictionary = JsonIO.parse(text)
	print("career valid after JSON round trip: ", CareerScript.valid(data))
	var back: RefCounted = CareerScript.from_dict(data)
	main.start_job("accounting_firm", 31337, back.patch, back.current_job.state, 2)
	print("restored: %d tickets, %d incidents, %d automations, confidence %d" % [main.office.helpdesk.queue.tickets.size(),
		main.office.patch_desk.incidents.size(), main.office.patch_desk.automations.size(), roundi(main.office.metrics.confidence)])
	main.camera.overview = true
	await seconds(1.5)
	await shot("career_restored_day")
	main.camera.overview = false


## The job menu, settings, a paper flood, and the end of a bad day with a
## warning from management. Uses a throwaway career that is never saved.
func _menus(main: Node) -> void:
	var flow: Node = main.flow
	flow.store.file.enabled = false
	flow.career = preload("res://scripts/sim/career.gd").fresh(777)
	flow._resume()
	Engine.time_scale = 4.0
	await _until(main, 520.0)
	Engine.time_scale = 1.0
	var office: RefCounted = main.office
	var printers: Array = office.devices_of("printer")
	var ticket: RefCounted = office.helpdesk.open_ticket(office, "printer_offline", printers[0])
	office.patch_desk.forced = "backfire"
	office.patch_desk.forced_backfire = "endless_test_page"
	office.patch_desk.approve(office, office.patch_desk.propose_ticket(office, ticket), false)
	main.player.go_to(printers[0].floor_index, printers[0].x + 60.0)
	await seconds(6.0)
	await shot("menus_paper_flood")
	main.open_menu()
	await seconds(0.4)
	await shot("menus_job_menu")
	_press(main.hud.notice, "Quit game")
	await seconds(0.4)
	await shot("menus_quit_unfinished_day")
	main.hud.notice.visible = false
	main.settings.close()
	main.open_settings()
	await seconds(0.4)
	await shot("menus_settings")
	main.settings.close()
	office.metrics.confidence = 20.0
	office.clock.minute = office.clock.end_minute - 0.5
	await seconds(1.0)
	await shot("menus_day_over_warning")
	main.hud.notice.visible = false
	flow.career = null


func _until(main: Node, minute: float) -> void:
	while main.office.clock.minute < minute and main.office.day_running:
		await frames(5)


## Presses the notice's button labelled `text`, as a click would.
func _press(notice: Control, text: String) -> void:
	for button in notice._buttons.get_children():
		if button is Button and button.text == text:
			button.pressed.emit()
			return
	push_error("No '%s' button on the notice" % text)


## Every screen driven by gamepad buttons alone: the title, browsing the HUD,
## PATCH from its menu to a proposal, an incident, the job menu, then the
## exit interview, PATCH's update and the job board. A throwaway career that
## is never saved.
func _pad(main: Node) -> void:
	var flow: Node = main.flow
	flow.store.file.enabled = false
	flow.show_title()
	await seconds(0.3)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await shot("pad_title")
	flow.career = preload("res://scripts/sim/career.gd").fresh(555)
	flow.career.history.append({"archetype": "startup", "name": "Bloop.io", "tier": 1, "days": 1, "ended": "quit", "grade": "C", "points": 2, "pay": 150})
	flow._resume()
	Engine.time_scale = 4.0
	await _until(main, 560.0)
	Engine.time_scale = 1.0
	main.set_speed(0.0)
	await _button(JOY_BUTTON_X)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await shot("pad_hud_browse")
	await _button(JOY_BUTTON_B)
	await _button(JOY_BUTTON_Y)
	await shot("pad_patch_menu")
	await _button(JOY_BUTTON_A)
	await shot("pad_patch_tickets")
	await _button(JOY_BUTTON_A)
	await shot("pad_patch_card")
	await _button(JOY_BUTTON_B)
	var desk: RefCounted = main.office.patch_desk
	desk.forced = "backfire"
	desk.forced_backfire = "deleted_all_tickets"
	desk.approve(main.office, desk.propose_queue(main.office, "organize_queue"), false)
	await seconds(0.3)
	await _button(JOY_BUTTON_X)
	await shot("pad_alert_focus")
	await _button(JOY_BUTTON_A)
	await shot("pad_incident_view")
	await _button(JOY_BUTTON_B)
	await _button(JOY_BUTTON_B)
	await _button(JOY_BUTTON_B)
	await shot("pad_job_menu")
	await _button(JOY_BUTTON_B)
	main.office.metrics.end_day()
	main.office.day_summaries.append(main.office.metrics.day.duplicate(true))
	flow._exit(main.office, "quit")
	await seconds(0.4)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await shot("pad_exit_interview")
	await _press_until_screen_changes(flow)
	await shot("pad_upgrades")
	await _press_until_screen_changes(flow)
	await shot("pad_job_board")
	flow.career = null


## Presses and releases one pad button, as a player would.
func _button(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		event.pressure = 1.0 if down else 0.0
		Input.parse_input_event(event)
		await frames(3)
	await seconds(0.25)


## Walks focus down and presses A until the between-jobs screen changes.
func _press_until_screen_changes(flow: Node) -> void:
	var before: Control = flow.screens.current
	for attempt in range(16):
		await _button(JOY_BUTTON_A)
		if flow.screens.current != before:
			await seconds(0.3)
			return
		await _button(JOY_BUTTON_DPAD_DOWN)
	push_error("Pad presses never left the screen")
