extends Node
## Debug controls, active only in debug builds (GDD 14.3): F1 forces PATCH's
## next execution to succeed, F2 forces it to backfire, F6 picks which
## backfire the next forced failure uses (cycling through every one), F3 opens
## a random ticket, F4 skips to the end of the workday.
const Catalog = preload("res://scripts/core/catalog.gd")
const Det = preload("res://addons/hatchery/core/det.gd")

var main: Node
var _backfire_index: int = -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or main == null or main.office == null:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var office: RefCounted = main.office
	match event.physical_keycode:
		KEY_F1:
			office.patch_desk.forced = "success"
			main.hud.toast("Debug: PATCH's next execution will succeed")
		KEY_F2:
			office.patch_desk.forced = "backfire"
			main.hud.toast("Debug: PATCH's next execution will backfire")
		KEY_F6:
			_cycle_backfire(office)
		KEY_F3:
			_random_ticket(office)
		KEY_F4:
			if office.day_running:
				office.clock.minute = office.clock.end_minute - 1.0
				main.hud.toast("Debug: skipped to the end of the day")


func _cycle_backfire(office: RefCounted) -> void:
	var ids: Array[String] = []
	for pool_id in Catalog.pools:
		for entry in Catalog.pools[pool_id]:
			ids.append(str(entry.id))
	_backfire_index = (_backfire_index + 1) % ids.size()
	office.patch_desk.forced = "backfire"
	office.patch_desk.forced_backfire = ids[_backfire_index]
	main.hud.toast("Debug: next backfire (if its action runs) is %s" % ids[_backfire_index])


func _random_ticket(office: RefCounted) -> void:
	var issue_id: String = str(Det.pick(_rng, Catalog.issue_ids))
	var kinds: Array = Catalog.issue(issue_id).devices
	var candidates: Array = office.devices.filter(func(device: RefCounted) -> bool:
		return kinds.has(device.kind) and office.helpdesk.queue.open_for_device(device.id).is_empty())
	if candidates.is_empty():
		return
	office.helpdesk.open_ticket(office, issue_id, Det.pick(_rng, candidates))
	main.hud.toast("Debug: opened a %s ticket" % Catalog.issue(issue_id).label)
