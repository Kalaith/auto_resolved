extends Node
## Gamepad reach for every screen. The office HUD keeps its buttons out of
## the focus chain for mouse and keyboard players (Space and E are "use", not
## "press the focused button"), so focus is switched on only while the last
## input came from a pad, and only for the one layer on top: a notice, the
## incident view or PATCH; or, after X, the whole HUD (tickets, alert, PATCH,
## speed, menu). Between jobs it focuses the current screen. Mouse, touch or a
## key press hands control back and clears the focus it made.
const Focus = preload("res://addons/hatchery/ui/focus.gd")

const PAD_HINT: String = "Stick walk   A use / call / go   D-pad floor   X browse HUD   Y PATCH   B back / menu   Back overview   Start pause   LB/RB/R3 speed"

var hud: CanvasLayer
## Returns the between-jobs screen showing, or null.
var screen: Callable = Callable()
## The last input came from a gamepad.
var active: bool = false
## X was pressed in the office with no panel open: focus walks the HUD.
var browsing: bool = false
var _root: Control = null
var _opened: Array[BaseButton] = []


func _input(event: InputEvent) -> void:
	var pad: bool = event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5)
	var other: bool = event is InputEventMouseButton or event is InputEventScreenTouch or (event is InputEventKey and event.pressed)
	if pad and not active:
		active = true
		hud.set_hint(PAD_HINT)
	elif other and active:
		active = false
		browsing = false
		_release()
		hud.set_hint("")


## The layer pad focus belongs to now, or null for none.
func target() -> Control:
	if hud.root.is_visible_in_tree():
		for layer in [hud.notice, hud.incidents, hud.patch_panel]:
			if layer.visible:
				return layer
		return hud.root if browsing else null
	browsing = false
	if screen.is_valid():
		var current: Variant = screen.call()
		if current is Control and is_instance_valid(current) and (current as Control).is_visible_in_tree():
			return current
	return null


func _process(_delta: float) -> void:
	if not active:
		return
	var root: Control = target()
	if root != _root:
		_release()
		_root = root
		if root != null:
			_enable(root)
			if root == hud.root:
				_focus_hud_start()
			else:
				_focus_start(root)
	if root == null:
		return
	_enable(root)
	var owner: Control = root.get_viewport().gui_get_focus_owner()
	# Another overlay (settings, credits) that took focus keeps it.
	if owner == null or not owner.is_visible_in_tree() or (owner is BaseButton and _opened.has(owner) and not root.is_ancestor_of(owner)):
		_focus_start(root)


## A layer may name where focus starts (`pad_start`); otherwise its first
## control.
func _focus_start(root: Control) -> void:
	if root.has_method(&"pad_start") and root.call(&"pad_start"):
		return
	Focus.focus_first(root)


## Makes every visible button under `root` reachable, remembering the ones
## that were not, to put them back.
func _enable(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is BaseButton and (child as BaseButton).focus_mode == Control.FOCUS_NONE and not child.has_meta(&"pad_skip"):
			(child as BaseButton).focus_mode = Control.FOCUS_ALL
			_opened.append(child)
		_enable(child)


## Browsing starts on the incident alert when there is one, else the top
## ticket.
func _focus_hud_start() -> void:
	if hud.alert.visible:
		hud.alert.grab_focus()
	elif not Focus.focus_first(hud.tickets):
		Focus.focus_first(hud.root)


func _release() -> void:
	var owner: Control = hud.root.get_viewport().gui_get_focus_owner() if hud.root.is_inside_tree() else null
	for button in _opened:
		if is_instance_valid(button):
			if button == owner:
				button.release_focus()
			button.focus_mode = Control.FOCUS_NONE
	_opened.clear()
	_root = null


## X in the office: start or stop walking the HUD with the d-pad.
func toggle_browsing() -> void:
	active = true
	hud.set_hint(PAD_HINT)
	browsing = not browsing
	if not browsing:
		_release()
