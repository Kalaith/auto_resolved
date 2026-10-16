extends RefCounted
## Where each prop of a room stands, as plain data, so the world view draws the
## same layout the simulation turns into desks and devices. Windows hang high
## on the back wall; everything else stands on the floor, spread evenly. A
## room type with `fill` repeats that prop to fill its width.
const Catalog = preload("res://scripts/core/catalog.gd")

const EDGE: float = 26.0


## [{prop, x, slot}] for the props standing on the floor, left to right.
## `slot` is the prop's index in that list and part of device ids.
static func standing(room: Dictionary) -> Array:
	var data: Dictionary = Catalog.room(room.type)
	var props: Array = data.props.filter(func(prop: String) -> bool: return prop != "window")
	if data.has("fill"):
		var room_space: float = float(room.width) - EDGE * 2.0
		var count: int = maxi(1, int(room_space / float(data.fill_spacing)) - props.size())
		var half: int = int(props.size() / 2.0)
		for i in range(count):
			props.insert(half, data.fill)
	var result: Array = []
	for i in range(props.size()):
		result.append({"prop": str(props[i]), "x": slot_x(room, i, props.size()), "slot": i})
	return result


## X positions of the room's windows (none in a basement).
static func windows(room: Dictionary) -> Array[float]:
	var result: Array[float] = []
	if int(room.floor) < 0:
		return result
	var count: int = Catalog.room(room.type).props.count("window")
	for i in range(count):
		result.append(slot_x(room, i, count))
	return result


static func slot_x(room: Dictionary, index: int, count: int) -> float:
	var inner: float = float(room.width) - EDGE * 2.0
	return float(room.x) + EDGE + inner * (float(index) + 0.5) / float(count)
