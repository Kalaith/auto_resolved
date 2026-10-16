extends "res://scripts/ui/screens/screen_base.gd"
## PATCH's update between jobs: the upgrade tree by track. Each node says what
## it changes in play. Buying spends points only if the career saves; the
## flow refunds a purchase whose save failed.
signal buy_chosen(id: String)
signal finished

const Catalog = preload("res://scripts/core/catalog.gd")

const TRACKS: Array = [
	["reliability", "Reliability"], ["safety", "Safety"], ["understanding", "Understanding"],
	["capability", "Capability"], ["autonomy", "Autonomy"],
]

var career: RefCounted
var message: String = ""


func build_page() -> void:
	column.add_child(ui.heading("PATCH v%s update" % career.patch.version(), 34))
	column.add_child(text("PATCH Points to spend: %d. Upgrades last for the rest of your career." % career.points, 18, ui.palette.accent))
	if not message.is_empty():
		column.add_child(text(message, 15, ui.palette.warn))
	for track in TRACKS:
		var row: VBoxContainer = card(880)
		column.add_child(row.get_parent())
		row.add_child(ui.label(str(track[1]), 18, ui.palette.accent))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		row.add_child(flow)
		for id in Catalog.upgrade_ids:
			if Catalog.upgrade(id).track == track[0]:
				flow.add_child(_node(str(id)))
	column.add_child(ui.button("See the job offers", func() -> void: finished.emit(), true))


func _node(id: String) -> Control:
	var upgrade: Dictionary = Catalog.upgrade(id)
	var box: VBoxContainer = ui.vbox(4)
	box.custom_minimum_size = Vector2(270, 0)
	box.add_child(ui.label("%s  (%d)" % [upgrade.label, int(upgrade.cost)], 15))
	var says: Label = ui.wrapped(str(upgrade.says), 13, ui.palette.muted)
	says.custom_minimum_size.x = 260
	box.add_child(says)
	if career.patch.has(id):
		box.add_child(ui.label("Installed", 14, ui.palette.good))
		return box
	var missing: Array[String] = []
	for needed in upgrade.requires:
		if not career.patch.has(str(needed)):
			missing.append(str(Catalog.upgrade(str(needed)).label))
	if not missing.is_empty():
		box.add_child(ui.label("Needs " + ", ".join(missing), 13, ui.palette.muted))
		return box
	var buy: Button = ui.button("Install", func() -> void: buy_chosen.emit(id), career.can_buy(id), 14)
	buy.disabled = not career.can_buy(id)
	buy.custom_minimum_size = Vector2(120, 40)
	box.add_child(buy)
	return box
