extends Node
## The office's placeholder sound, synthesised at start by the toolkit (no
## audio files): an office hum, the lift's ding when it opens where you are,
## a blip for a new ticket, a chime for a fix, a printer churning out paper,
## and an alarm when PATCH causes an incident. Effects play on the Effects
## bus and the hum on Ambience, so the settings sliders reach them.
const Synth = preload("res://addons/hatchery/audio/synth.gd")
const CueBank = preload("res://addons/hatchery/audio/cue_bank.gd")
const Ambience = preload("res://addons/hatchery/audio/ambience.gd")

var main: Node
var _sfx: CueBank
var _ambience: Ambience
var _hum: Array = []
var _last_state: int = -1


func _ready() -> void:
	_sfx = CueBank.new()
	_sfx.bus = &"Effects"
	add_child(_sfx)
	_ambience = Ambience.new()
	_ambience.bus = &"Ambience"
	add_child(_ambience)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	_sfx.add("ding", Synth.tone(rng, [[1318.5, 0.55], [1975.5, 0.25]], 1.0, 0.0, 4.0, 0.5), -8.0, 0.5)
	_sfx.add("ticket", Synth.tone(rng, [[660.0, 0.5], [990.0, 0.2]], 0.2, 0.0, 14.0, 0.45), -10.0, 0.4)
	_sfx.add("fixed", Synth.tone(rng, [[880.0, 0.45], [1320.0, 0.35], [1760.0, 0.15]], 0.6, 0.0, 5.0, 0.5), -8.0)
	_sfx.add("printer", Synth.tone(rng, [[110.0, 0.4], [220.0, 0.2]], 0.9, 0.55, 2.5, 0.45), -8.0, 1.0)
	_sfx.add("alarm", Synth.tone(rng, [[740.0, 0.5], [370.0, 0.3]], 0.9, 0.05, 1.8, 0.55), -6.0)
	_sfx.add("patch", Synth.tone(rng, [[523.3, 0.4], [784.0, 0.3]], 0.25, 0.0, 9.0, 0.4), -12.0, 0.3)
	_hum = [
		{"stream": Synth.drone_loop(55.0, [1.0, 2.0, 3.0], 4.0, 0.25), "db": -18.0},
		{"stream": Synth.hiss_loop(rng, 4.0, 0.2), "db": -26.0, "offset": 0.4},
	]


func _process(_delta: float) -> void:
	if main == null or main.office == null or main.player == null:
		if _ambience.current != "":
			_ambience.stop()
		return
	_ambience.play_bed("office", _hum)
	var car: RefCounted = main.elevator
	if car.state != _last_state:
		var near: bool = main.player.riding or car.current_floor() == main.player.floor_index
		if car.state == car.State.OPENING and near:
			_sfx.cue("ding")
		_last_state = car.state


func on_event(event: Dictionary) -> void:
	match str(event.type):
		"ticket_opened":
			_sfx.cue("ticket")
		"ticket_resolved":
			if event.by == "player":
				_sfx.cue("fixed")
			else:
				_sfx.cue("patch")
		"incident_opened":
			_sfx.cue("alarm")
			if str(event.backfire).contains("page") or str(event.backfire).contains("firmware"):
				_sfx.cue("printer")
		"incident_recovered":
			_sfx.cue("fixed", 1.25)
