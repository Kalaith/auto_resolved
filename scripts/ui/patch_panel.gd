extends PanelContainer
## Talking to PATCH: structured intents instead of free text (a ticket, a
## recurring category, the queue), the proposal card with its five answers,
## scope and safeguards, and the list of running automations. Opened from the
## PATCH button; the office stays live and the player can keep walking.
signal closed

const Catalog = preload("res://scripts/core/catalog.gd")
const ProposalCard = preload("res://scripts/ui/proposal_card.gd")

const CHAT_LINES: int = 4

var ui: RefCounted
var office: RefCounted
var _title: Label
var _chat: VBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _card: ProposalCard
var _chat_seen: int = -1
var _page: String = "menu"


func build(kit: RefCounted) -> void:
	ui = kit
	add_theme_stylebox_override("panel", ui.panel_box(0.95, 12))
	custom_minimum_size = Vector2(460, 0)
	var column: VBoxContainer = ui.vbox(8)
	add_child(column)
	var top: HBoxContainer = ui.hbox(8)
	column.add_child(top)
	_title = ui.heading("PATCH", 22)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	var close: Button = ui.button("X", func() -> void: close_panel(), false, 14)
	close.custom_minimum_size = Vector2(40, 36)
	close.focus_mode = Control.FOCUS_NONE
	top.add_child(close)
	_chat = ui.vbox(4)
	column.add_child(_chat)
	column.add_child(HSeparator.new())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(436, 0)
	column.add_child(_scroll)
	_body = ui.vbox(6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_card = ProposalCard.new()
	_card.build(ui)
	_card.finished.connect(func() -> void: _show_menu())
	_card.visible = false
	_body.add_child(_card)
	_card.buttons.visible = false
	column.add_child(_card.buttons)
	visible = false


func open_for(sim: RefCounted) -> void:
	office = sim
	visible = true
	_chat_seen = -1
	_show_menu()


func close_panel() -> void:
	visible = false
	_card.visible = false
	_card.buttons.visible = false
	closed.emit()


## Opens straight onto a proposal for one ticket (from the ticket panel).
func ask_about_ticket(sim: RefCounted, ticket_id: int) -> void:
	open_for(sim)
	var ticket: RefCounted = office.helpdesk.queue.get_ticket(ticket_id)
	if ticket != null and ticket.is_open():
		_show_proposal(office.patch_desk.propose_ticket(office, ticket))


func _process(_delta: float) -> void:
	if not visible or office == null:
		return
	_title.text = "PATCH v%s" % office.patch.version()
	if office.patch_desk.chat.size() != _chat_seen:
		_refresh_chat()
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, 330.0)
	if _page == "card":
		_card.refresh_risk()


func _refresh_chat() -> void:
	_chat_seen = office.patch_desk.chat.size()
	for child in _chat.get_children():
		child.queue_free()
	var lines: Array = office.patch_desk.chat.slice(-(2 if _page == "card" else CHAT_LINES))
	for line in lines:
		var patch: bool = line.who == "patch"
		var label: Label = ui.wrapped(("PATCH: " if patch else "You: ") + str(line.text), 14, ui.palette.text if patch else ui.palette.muted)
		label.custom_minimum_size.x = 436
		_chat.add_child(label)


func _clear_body() -> void:
	_card.visible = false
	_card.buttons.visible = false
	for child in _body.get_children():
		if child != _card:
			child.queue_free()


func _row(text: String, callback: Callable, primary: bool = false) -> Button:
	var button: Button = ui.button(text, callback, primary, 15)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.custom_minimum_size = Vector2(420, 40)
	_body.add_child(button)
	return button


func _show_menu() -> void:
	_page = "menu"
	_chat_seen = -1
	_clear_body()
	_row("Help with a ticket...", func() -> void: _show_tickets())
	_row("We keep getting the same tickets...", func() -> void: _show_categories())
	for id in ["organize_queue", "archive_resolved"]:
		var action_id: String = id
		_row(str(Catalog.action(action_id).label), func() -> void: _show_proposal(office.patch_desk.propose_queue(office, action_id)))
	_row("What are you running? (%d)" % office.patch_desk.automations.size(), func() -> void: _show_automations())


func _show_tickets() -> void:
	_page = "tickets"
	_clear_body()
	var tickets: Array = office.helpdesk.queue.by_urgency()
	if tickets.is_empty():
		office.patch_desk.say(Catalog.say("patch.no_tickets"))
	for ticket in tickets.slice(0, 8):
		var chosen: RefCounted = ticket
		_row("#%d %s" % [ticket.id, ticket.title], func() -> void: _show_proposal(office.patch_desk.propose_ticket(office, chosen)))
	_row("Back", func() -> void: _show_menu())


func _show_categories() -> void:
	_page = "categories"
	_clear_body()
	var found: Array[String] = office.patch_desk.categories(office)
	if found.is_empty():
		office.patch_desk.say(Catalog.say("patch.no_categories"))
	for issue in found:
		var chosen: String = issue
		_row("%s tickets" % Catalog.issue(issue).label, func() -> void: _show_proposal(office.patch_desk.propose_category(office, chosen)))
	_row("Back", func() -> void: _show_menu())


func _show_proposal(proposal: RefCounted) -> void:
	if proposal == null:
		_show_menu()
		return
	_page = "card"
	_chat_seen = -1
	_clear_body()
	_card.visible = true
	_card.buttons.visible = true
	_card.show_proposal(office, proposal)


func _show_automations() -> void:
	_page = "automations"
	_clear_body()
	var desk: RefCounted = office.patch_desk
	if desk.automations.is_empty() and desk.repeat_actions.is_empty():
		desk.say(Catalog.say("patch.no_automations"))
	for automation in desk.automations:
		var item: RefCounted = automation
		var state: String = "running" if item.enabled else ("PAUSED after an incident" if item.paused_by == "incident" else "paused")
		var info: Label = ui.wrapped("%s - %s\n%s, %d runs, %d clean" % [item.name(), item.proposal.scope_text(office), state, item.runs, item.successes], 14, ui.palette.text)
		info.custom_minimum_size.x = 420
		_body.add_child(info)
		var buttons: HBoxContainer = ui.hbox(6)
		_body.add_child(buttons)
		var toggle: Button = ui.button("Pause" if item.enabled else "Resume", func() -> void:
			desk.set_automation_enabled(item, not item.enabled)
			_show_automations(), false, 14)
		var remove: Button = ui.button("Uninstall", func() -> void:
			desk.remove_automation(item)
			_show_automations(), false, 14)
		for button in [toggle, remove]:
			button.focus_mode = Control.FOCUS_NONE
			buttons.add_child(button)
	for id in desk.repeat_actions:
		var action_id: String = id
		_row("Stop repeating: %s" % Catalog.action(action_id).label, func() -> void:
			desk.repeat_actions.erase(action_id)
			_show_automations())
	_row("Back", func() -> void: _show_menu())
