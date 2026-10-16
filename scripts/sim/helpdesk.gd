extends RefCounted
## The ticket side of the office: opening a ticket puts its fault on the
## device (and on a floor or the whole building for outages), resolving one
## takes exactly that ticket's faults away again, and a manual fix is checked
## against where the player is standing. The office is passed in to every
## call rather than stored, so there is no reference cycle.
const Catalog = preload("res://scripts/core/catalog.gd")
const Ticket = preload("res://scripts/sim/ticket.gd")
const TicketQueue = preload("res://scripts/sim/ticket_queue.gd")
const IssueRoller = preload("res://scripts/sim/issue_roller.gd")

var queue := TicketQueue.new()
var roller: IssueRoller


func _init(job_seed: int) -> void:
	roller = IssueRoller.new(job_seed)


func open_ticket(office: RefCounted, issue_id: String, device: RefCounted, floor_override: int = -999) -> Ticket:
	var issue: Dictionary = Catalog.issue(issue_id)
	var ticket := Ticket.new()
	ticket.issue = issue_id
	ticket.title = str(issue.title)
	ticket.device_id = device.id
	ticket.reporter = device.owner
	ticket.severity = int(issue.severity)
	ticket.floor_index = device.floor_index
	if issue.spread == "floor" and device.kind == "network_core":
		ticket.floor_index = floor_override if floor_override != -999 else office.pick_staffed_floor(roller.rng)
	ticket.created = office.clock.stamp()
	var patience: float = 1.0
	var reporter: RefCounted = office.employee(device.owner)
	if reporter != null:
		patience = 0.6 + reporter.patience * 0.8
		if issue_id == "new_employee":
			office.replace_with_new_starter(reporter)
	ticket.deadline = ticket.created + float(issue.patience_minutes) * patience
	queue.add(ticket)
	_apply_faults(office, ticket, issue, device)
	office.metrics.on_ticket_opened(ticket)
	office.emit("ticket_opened", {"ticket": ticket.id, "issue": issue_id, "device": device.id, "floor": ticket.floor_index})
	return ticket


func _apply_faults(office: RefCounted, ticket: Ticket, issue: Dictionary, device: RefCounted) -> void:
	var spread: String = str(issue.spread)
	device.add_fault(str(issue.fault), float(issue.blocks) if spread == "device" else 0.0, ticket.source())
	if spread == "floor":
		office.add_area_fault(ticket.source(), str(issue.fault), float(issue.blocks), [ticket.floor_index])
	elif spread == "building":
		office.add_area_fault(ticket.source(), str(issue.fault), float(issue.blocks), office.plan.floor_indices())


## Closes `ticket` for real: its faults go, its reporter cheers up, and the
## company notices (more if it was quick). `by` is player, patch or automation.
func resolve(office: RefCounted, ticket: Ticket, by: String) -> void:
	if not ticket.is_open():
		return
	ticket.status = "resolved"
	ticket.resolved_at = office.clock.stamp()
	ticket.resolved_by = by
	ticket.falsely_closed = false
	office.clear_source(ticket.source())
	var reporter: RefCounted = office.employee(ticket.reporter)
	if reporter != null:
		reporter.mood = minf(1.0, reporter.mood + 0.12)
	office.metrics.on_ticket_resolved(ticket, office.clock.stamp())
	office.emit("ticket_resolved", {"ticket": ticket.id, "issue": ticket.issue, "device": ticket.device_id, "by": by})


## Where the player can do this ticket's manual fix: always at its device,
## and at the IT desk for desk-fixable issues (or any with remote sessions).
func fix_places(office: RefCounted, ticket: Ticket) -> Array[String]:
	var places: Array[String] = [ticket.device_id]
	var issue: Dictionary = Catalog.issue(ticket.issue)
	if issue.manual.at == "desk_or_device" or office.remote_fix_allowed(ticket.issue):
		for desk in office.devices_of("it_desk"):
			places.append(desk.id)
	return places


func fix_seconds(ticket: Ticket) -> float:
	return float(Catalog.issue(ticket.issue).manual.seconds)


## The player started working on `ticket`.
func begin_manual(office: RefCounted, ticket: Ticket) -> void:
	if ticket.is_open() and ticket.status != "in_progress":
		ticket.status = "in_progress"
		office.emit("ticket_started", {"ticket": ticket.id})


## The player held the fix long enough at `device_id`. False (and nothing
## changes) if that is not a place this ticket can be fixed.
func complete_manual(office: RefCounted, ticket: Ticket, device_id: String) -> bool:
	if ticket == null or not ticket.is_open() or not fix_places(office, ticket).has(device_id):
		return false
	resolve(office, ticket, "player")
	return true


## The player walked away from a half-done fix.
func abandon_manual(ticket: Ticket) -> void:
	if ticket != null and ticket.status == "in_progress":
		ticket.status = "triaged"
