extends "res://scripts/ui/screens/screen_base.gd"
## The career's closing beat (GDD north star: PATCH becomes an effective
## successor). Shown once, after PATCH's update, when PATCH owns every
## upgrade or a top-tier job ended without a firing: what PATCH has become,
## and every job worked. The career goes on afterwards if the player wants.
signal keep_working
signal title_chosen

const Catalog = preload("res://scripts/core/catalog.gd")

## Filled by the career flow before the screen is added.
var career: RefCounted


func build_page() -> void:
	var patch: RefCounted = career.patch
	column.add_child(ui.heading("PATCH v%s is ready" % patch.version(), 38))
	column.add_child(text(_opening(), 18, ui.palette.muted))
	var who: VBoxContainer = card(880)
	column.add_child(who.get_parent())
	who.add_child(text("PATCH, as it leaves you", 20, ui.palette.accent))
	who.add_child(text("Upgrades: %d of %d     Guardrails kept for good: %d     Kinds of mistake it has met: %d" % [
		patch.upgrades.size(), Catalog.upgrade_ids.size(), patch.guardrails.size(), patch.archetypes_seen.size()], 16))
	who.add_child(text("\"I have read the runbooks you never wrote. I ask before I delete things now. Mostly.\" - PATCH", 15, ui.palette.muted))
	var jobs: VBoxContainer = card(880)
	column.add_child(jobs.get_parent())
	var days: int = 0
	for record in career.history:
		days += int(record.days)
	jobs.add_child(text("Your career: %d jobs, %d days, $%d earned, reputation %d" % [career.history.size(), days, career.earnings, career.reputation], 20, ui.palette.accent))
	for record in career.history:
		jobs.add_child(text(_job_line(record), 15))
	var row: HBoxContainer = ui.hbox(12)
	column.add_child(row)
	var keep: Button = ui.button("Keep working", func() -> void: keep_working.emit(), true)
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(keep)
	var leave: Button = ui.button("Back to title", func() -> void: title_chosen.emit())
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(leave)


func _opening() -> String:
	if career.patch.upgrades.size() >= Catalog.upgrade_ids.size():
		return "Every upgrade is installed. PATCH resets the passwords, watches the printers and rolls back its own mistakes before anyone files a ticket. " + \
			"The helpdesk you walked into on your first week now mostly runs itself. You trained your successor."
	return "You kept a top-tier company running with PATCH beside you, and walked out on your own terms. " + \
		"PATCH can carry a building like that now. You trained your successor."


## "Kettleby Hobbs (Family business, tier 1): 3 days, quit, reference B, 6 points, $360"
func _job_line(record: Dictionary) -> String:
	var label: String = str(Catalog.archetype(str(record.archetype)).label) if Catalog.archetypes.has(str(record.archetype)) else str(record.archetype)
	var ended: String = "quit" if str(record.ended) == "quit" else "let go"
	return "%s (%s, tier %d): %d day%s, %s, reference %s, %d points, $%d" % [str(record.name), label, int(record.tier), int(record.days),
		"" if int(record.days) == 1 else "s", ended, str(record.grade), int(record.points), int(record.pay)]
