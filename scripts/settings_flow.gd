extends Node
## Player preferences through the toolkit: volume, fullscreen, UI size,
## colour-safe good/bad colours and key rebinding, saved in
## user://settings.json (never in the career file). Opens the toolkit's
## settings page over whatever is showing.
signal title_requested

const SettingsStore = preload("res://addons/hatchery/settings/settings_store.gd")
const SettingsPanel = preload("res://addons/hatchery/ui/settings_panel.gd")
const KeyBindings = preload("res://addons/hatchery/input/key_bindings.gd")
const Display = preload("res://addons/hatchery/settings/display.gd")
const Levels = preload("res://addons/hatchery/audio/levels.gd")

const DEFAULTS: Dictionary = {
	"master": 0.8, "effects": 0.8, "ambience": 0.5, "muted": false,
	"fullscreen": false, "ui_scale": 0.23, "colour_safe": false,
}
const KEY_ACTIONS: Dictionary = {
	"move_left": "Walk left", "move_right": "Walk right", "interact": "Use / call the lift / go",
	"floor_up": "Lift: floor up", "floor_down": "Lift: floor down", "toggle_overview": "Whole-building view",
	"pause": "Pause", "speed_1": "Normal speed", "speed_2": "Double speed", "speed_3": "Fast speed",
}
const WORDS: Dictionary = {
	"settings_sound": "Sound", "settings_display": "Display",
	"setting_master": "Volume", "setting_effects": "Effects", "setting_ambience": "Office hum",
	"setting_muted": "Mute", "setting_fullscreen": "Fullscreen", "setting_ui_scale": "Interface size",
	"setting_colour_safe": "Colour-safe good and bad colours",
}

var store: SettingsStore
var palette: RefCounted
var _layer: CanvasLayer
var _page: Control = null


func _ready() -> void:
	store = SettingsStore.new(DEFAULTS)
	store.keys = KeyBindings.new(KEY_ACTIONS)
	store.load_settings()
	store.apply_bindings()
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	Levels.ensure_bus("Effects")
	Levels.ensure_bus("Ambience")
	for key in DEFAULTS:
		apply(key)


## The toolkit store and its file point at each other through callables;
## break that on exit so neither outlives the game.
func _exit_tree() -> void:
	if store != null:
		store.file.validate = Callable()
		store.file.migrate = Callable()


func value(key: String) -> Variant:
	return store.values[key]


func open(kit: RefCounted, with_title: bool) -> void:
	if is_instance_valid(_page):
		return
	var page: Control = SettingsPanel.new()
	page.store = store
	page.ui = kit
	page.show_title_button = with_title
	page.sections = [
		{"title": "settings_sound", "sliders": ["master", "effects", "ambience"], "toggles": ["muted"]},
		{"title": "settings_display", "sliders": ["ui_scale"], "toggles": ["fullscreen", "colour_safe"]},
	]
	page.commit_on_release = ["ui_scale"]
	page.slider_text = func(key: String, fraction: float) -> String:
		if key == "ui_scale":
			return "%d%%" % roundi(Display.scale_from_fraction(fraction) * 100.0)
		return "%d%%" % roundi(fraction * 100.0)
	page.text = func(key: String, english: String) -> String: return str(WORDS.get(key, KEY_ACTIONS.get(key.trim_prefix("action_"), english)))
	page.applied.connect(apply)
	page.close_requested.connect(close)
	page.title_requested.connect(func() -> void:
		close()
		title_requested.emit())
	_page = page
	_layer.add_child(page)


func close() -> void:
	if is_instance_valid(_page):
		_page.queue_free()
	_page = null


func is_open() -> bool:
	return is_instance_valid(_page)


## Pushes one stored value into the engine.
func apply(key: String) -> void:
	var values: Dictionary = store.values
	match key:
		"master", "muted":
			Levels.set_bus("Master", float(values.master), bool(values.muted))
		"effects":
			Levels.set_bus("Effects", float(values.effects))
		"ambience":
			Levels.set_bus("Ambience", float(values.ambience))
		"fullscreen":
			Display.set_fullscreen(bool(values.fullscreen))
		"ui_scale":
			Display.set_ui_scale(get_tree(), Display.scale_from_fraction(float(values.ui_scale)))
		"colour_safe":
			if palette != null:
				palette.set_accessibility(bool(values.colour_safe), false)
