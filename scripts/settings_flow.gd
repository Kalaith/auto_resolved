extends Node
## Player preferences through the toolkit: volume, fullscreen, UI size,
## colour-safe good/bad colours and key rebinding, saved in
## user://settings.json (never in the career file). Opens the toolkit's
## settings page over whatever is showing.
signal title_requested

const SettingsStore = preload("res://addons/hatchery/settings/settings_store.gd")
const SettingsBundle = preload("res://addons/hatchery/settings/settings_bundle.gd")
const KeyBindings = preload("res://addons/hatchery/input/key_bindings.gd")
const EngineSettings = preload("res://addons/hatchery/settings/engine_settings.gd")

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

var settings: SettingsBundle
var store: SettingsStore
var engine: EngineSettings
var palette: RefCounted
var _layer: CanvasLayer
var _page: Control = null


func _ready() -> void:
	settings = SettingsBundle.new(DEFAULTS, get_tree(), {"Master": "master", "Effects": "effects", "Ambience": "ambience"})
	store = settings.store
	engine = settings.engine
	store.keys = KeyBindings.new(KEY_ACTIONS)
	engine.extra = _apply_own
	settings.sections = [
		{"title": "settings_sound", "sliders": ["master", "effects", "ambience"], "toggles": ["muted"]},
		{"title": "settings_display", "sliders": ["ui_scale"], "toggles": ["fullscreen", "colour_safe"]},
	]
	settings.text = func(key: String, english: String) -> String: return str(WORDS.get(key, KEY_ACTIONS.get(key.trim_prefix("action_"), english)))
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	settings.load_and_apply()


## The toolkit store and its file point at each other through callables;
## break that on exit so neither outlives the game.
func _exit_tree() -> void:
	if settings != null:
		settings.release()


func value(key: String) -> Variant:
	return settings.value(key)


func open(kit: RefCounted, with_title: bool) -> void:
	if is_instance_valid(_page):
		return
	var page: Control = settings.make_page(kit)
	page.show_title_button = with_title
	page.panel_size = Vector2(820, 860)
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
	settings.apply(key)


func _apply_own(key: String) -> void:
	if key == "colour_safe" and palette != null:
		palette.set_accessibility(bool(store.values.colour_safe), false)
