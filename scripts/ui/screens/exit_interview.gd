extends "res://scripts/ui/screens/screen_base.gd"
## The exit interview (GDD 9.2): days worked, people supported, uptime,
## automations, catastrophes and incidents solved, pay, the reference, the
## PATCH Points earned line by line, and one guardrail from this job PATCH
## may keep forever.
signal done(promoted: String)

const Catalog = preload("res://scripts/core/catalog.gd")

## Filled by the career flow before the screen is added.
var company: String = ""
var ended: String = "quit"
var stats: Dictionary = {}
var points: Dictionary = {}
var grade: String = "C"
var reputation_change: int = 0
var guardrails: Array[String] = []
var _promoted: String = ""


func build_page() -> void:
	column.add_child(ui.heading("Exit interview: %s" % company, 34))
	var verdict: String = "You handed in your notice after %d day%s." if ended == "quit" else "You were let go after %d day%s."
	column.add_child(text(verdict % [int(stats.days), "" if int(stats.days) == 1 else "s"], 18, ui.palette.muted))
	var facts: VBoxContainer = card(880)
	column.add_child(facts.get_parent())
	facts.add_child(text("Days worked: %d     People supported: %d     Staff uptime: %d%%" % [int(stats.days), int(stats.people), roundi(float(stats.uptime) * 100.0)]))
	facts.add_child(text("Tickets resolved: %d (%d by PATCH)     Automations installed: %d" % [int(stats.resolved), int(stats.by_patch), int(stats.automations)]))
	facts.add_child(text("Incidents: %d, recovered %d, catastrophes %d" % [int(stats.incidents), int(stats.recovered), int(stats.catastrophes)]))
	facts.add_child(text("Pay earned: $%d" % int(stats.pay), 18, ui.palette.good))
	var reference: VBoxContainer = card(880)
	column.add_child(reference.get_parent())
	var change: String = ("+%d" % reputation_change) if reputation_change >= 0 else str(reputation_change)
	reference.add_child(text("Reference: %s   (reputation %s)" % [grade, change], 20, ui.palette.accent))
	reference.add_child(text(_reference_line(), 15, ui.palette.muted))
	var earned: VBoxContainer = card(880)
	column.add_child(earned.get_parent())
	earned.add_child(text("PATCH Points earned: %d" % int(points.total), 20, ui.palette.accent))
	for item in points.items:
		if float(item[1]) > 0.0:
			earned.add_child(text("%s: %.1f" % [item[0], float(item[1])], 15))
	if ended == "fired":
		earned.add_child(text("A dismissal keeps only part of the points. Quitting keeps them all.", 14, ui.palette.warn))
	_guardrail_choice()
	column.add_child(ui.button("On to PATCH's update", func() -> void: done.emit(_promoted), true))


func _reference_line() -> String:
	match grade:
		"A":
			return "\"Reliable, calm, and the printers worked. We will miss you.\""
		"B":
			return "\"Solid. Things mostly worked, and when they did not, they got fixed.\""
		"C":
			return "\"Did the job. The queue was a bit long some days.\""
	return "\"We wish them well in their future endeavours.\""


func _guardrail_choice() -> void:
	var box: VBoxContainer = card(880)
	column.add_child(box.get_parent())
	if guardrails.is_empty():
		box.add_child(text("No guardrails were set at this job, so PATCH keeps no new rule.", 15, ui.palette.muted))
		return
	box.add_child(text("Pick one guardrail from this job for PATCH to keep forever:", 16))
	for archetype in guardrails:
		var id: String = archetype
		var toggle: CheckButton = ui.toggle(str(Catalog.failure_archetypes[id].guardrail), func(on: bool) -> void:
			_promoted = id if on else ""
			rebuild())
		toggle.set_pressed_no_signal(_promoted == id)
		box.add_child(toggle)
