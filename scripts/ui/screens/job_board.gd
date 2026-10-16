extends "res://scripts/ui/screens/screen_base.gd"
## The job board: where the career stands, then three offers. Better
## companies pay more and are harder: more floors, more staff, new problems.
signal offer_taken(index: int)
signal title_chosen

var career: RefCounted


func build_page() -> void:
	column.add_child(ui.heading("Job board", 34))
	var jobs: int = career.history.size()
	column.add_child(text("PATCH v%s   Reputation %d (tier %d open)   Lifetime earnings $%d   Jobs done %d" % [
		career.patch.version(), career.reputation, career.max_tier(), career.earnings, jobs], 16, ui.palette.muted))
	if jobs > 0:
		var last: Dictionary = career.history[jobs - 1]
		var days: String = "1 day" if int(last.days) == 1 else "%d days" % int(last.days)
		column.add_child(text("Last job: %s, %s, %s, reference %s." % [last.name, days, "quit" if last.ended == "quit" else "let go", last.grade], 15, ui.palette.muted))
	for i in range(career.offers.size()):
		column.add_child(_offer(i, career.offers[i]))
	column.add_child(ui.button("Back to title", func() -> void: title_chosen.emit()))


func _offer(index: int, offer: Dictionary) -> Control:
	var box: VBoxContainer = card(880)
	var top: HBoxContainer = ui.hbox(12)
	box.add_child(top)
	var name: Label = ui.heading(str(offer.name), 22)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(ui.label("$%d / day" % int(offer.pay), 20, ui.palette.good))
	var floors: String = "%d floors%s" % [int(offer.floors), " + basement" if bool(offer.basement) else ""]
	box.add_child(text("%s, tier %d   %s   about %d staff" % [offer.label, int(offer.tier), floors, int(offer.staff)], 15))
	box.add_child(text(str(offer.hint), 14, ui.palette.muted))
	var take: Button = ui.button("Take this job", func() -> void: offer_taken.emit(index), true, 15)
	take.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(take)
	return box.get_parent()
