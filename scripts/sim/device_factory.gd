extends RefCounted
## Turns the building's props into devices: every desk PC a workstation owned
## by whoever sits there (the IT office's desk is the IT desk), every printer a
## printer, the server room's racks servers with the network core in the
## first, and the lift controller beside the ground-floor landing. Ids are
## `<room id>_d<slot>`, so they are stable for a given building.
const RoomLayout = preload("res://scripts/sim/room_layout.gd")
const Device = preload("res://scripts/sim/device.gd")

## Employees sit this far left of their desk's centre (staff_factory.gd).
const CHAIR_OFFSET: float = -14.0


static func create(plan: RefCounted, staff: Array) -> Array:
	var owners: Dictionary = {}
	for person in staff:
		owners["%s@%d" % [person.desk_room, roundi(person.desk_x - CHAIR_OFFSET)]] = person
	var devices: Array = []
	for index in plan.floor_indices():
		for room in plan.rooms_on(index):
			var first_rack: bool = true
			for item in RoomLayout.standing(room):
				var kind: String = _kind(room.type, str(item.prop))
				if kind.is_empty():
					continue
				if kind == "server" and first_rack:
					first_rack = false
					kind = "network_core"
				var device := Device.new()
				device.id = "%s_d%d" % [room.id, int(item.slot)]
				device.kind = kind
				device.room_id = str(room.id)
				device.floor_index = int(room.floor)
				device.x = float(item.x)
				var person: RefCounted = owners.get("%s@%d" % [room.id, roundi(float(item.x))])
				if kind == "workstation" and person != null:
					device.owner = person.id
					person.device_id = device.id
				devices.append(device)
	var lift := Device.new()
	lift.id = "lift"
	lift.kind = "elevator"
	lift.floor_index = 0
	lift.room_id = ""
	lift.x = plan.shaft_x + plan.shaft_width + 14.0
	devices.append(lift)
	return devices


static func _kind(room_type: String, prop: String) -> String:
	match prop:
		"desk_pc":
			return "it_desk" if room_type == "it_office" else "workstation"
		"printer":
			return "printer"
		"server_rack":
			return "server" if room_type == "server_room" else ""
	return ""
