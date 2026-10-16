extends RefCounted
## Turns an archetype's hex theme into Colors for one job. Each job nudges the
## whole palette's hue by up to `hue_jitter`, so two law firms are related but
## never identical.
const THEME_KEYS: Array[String] = ["sky", "exterior", "slab", "trim", "floor", "furniture", "accent"]


static func resolve(theme: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var turn: float = _job_turn(theme, rng)
	var result: Dictionary = {"turn": turn}
	for key in THEME_KEYS:
		result[key] = _turned(Color(str(theme[key])), turn)
	return result


## The theme's wall colours under the same hue turn `resolve` chose.
static func walls(theme: Dictionary, turn: float) -> Array[Color]:
	var result: Array[Color] = []
	for hex in theme.walls:
		result.append(_turned(Color(str(hex)), turn))
	return result


## Darkens (negative) or lightens (positive) a wall for a room type.
static func shifted(colour: Color, amount: float) -> Color:
	return colour.darkened(-amount) if amount < 0.0 else colour.lightened(amount)


static func _job_turn(theme: Dictionary, rng: RandomNumberGenerator) -> float:
	var jitter: float = float(theme.hue_jitter)
	return rng.randf_range(-jitter, jitter)


static func _turned(colour: Color, turn: float) -> Color:
	return Color.from_hsv(fposmod(colour.h + turn, 1.0), colour.s, colour.v, colour.a)
