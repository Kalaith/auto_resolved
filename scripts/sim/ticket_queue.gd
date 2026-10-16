extends RefCounted
## Every ticket of the job, open and closed, with ids counting up from 1. The
## queue only stores and looks up; the office decides what opening, fixing or
## deleting a ticket does to devices, people and confidence.
const Ticket = preload("res://scripts/sim/ticket.gd")

var tickets: Array = []
var _by_id: Dictionary = {}
var _next_id: int = 1


func add(ticket: Ticket) -> Ticket:
	ticket.id = _next_id
	_next_id += 1
	tickets.append(ticket)
	_by_id[ticket.id] = ticket
	return ticket


func get_ticket(id: int) -> Ticket:
	return _by_id.get(id)


func open_tickets() -> Array:
	return tickets.filter(func(ticket: Ticket) -> bool: return ticket.is_open())


func open_count() -> int:
	var count: int = 0
	for ticket in tickets:
		if ticket.is_open():
			count += 1
	return count


func open_for_device(device_id: String) -> Array:
	return tickets.filter(func(ticket: Ticket) -> bool: return ticket.is_open() and ticket.device_id == device_id)


func open_for_person(person_id: String) -> Array:
	return tickets.filter(func(ticket: Ticket) -> bool: return ticket.is_open() and ticket.reporter == person_id)


func open_of_issue(issue: String) -> Array:
	return tickets.filter(func(ticket: Ticket) -> bool: return ticket.is_open() and ticket.issue == issue)


## Open tickets ordered by urgency: overdue and nearest deadline first.
func by_urgency() -> Array:
	var result: Array = open_tickets()
	result.sort_custom(func(a: Ticket, b: Ticket) -> bool:
		if not is_equal_approx(a.deadline, b.deadline):
			return a.deadline < b.deadline
		return a.id < b.id)
	return result


func resolved_since(stamp: float) -> Array:
	return tickets.filter(func(ticket: Ticket) -> bool: return ticket.status == "resolved" and ticket.resolved_at >= stamp)
