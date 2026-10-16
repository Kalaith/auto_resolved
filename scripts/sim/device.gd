extends RefCounted
## One piece of IT in the building: a workstation, a printer, a server, the
## network core, the elevator controller or the IT desk. Its faults are what
## the world shows on it and what blocks the people who depend on it; each
## fault remembers its source (a ticket or a PATCH incident) so fixing one
## never clears another's damage.

var id: String = ""
## workstation, printer, server, network_core, elevator, it_desk
var kind: String = ""
var room_id: String = ""
var floor_index: int = 0
var x: float = 0.0
## The employee at this desk ("" for shared devices).
var owner: String = ""
## fault id -> {"block": 0..1, "source": "ticket:12" | "incident:3"}
var faults: Dictionary = {}


func label() -> String:
	match kind:
		"workstation":
			return "PC"
		"printer":
			return "Printer"
		"server":
			return "Server"
		"network_core":
			return "Network core"
		"elevator":
			return "Lift controller"
		"it_desk":
			return "IT desk"
	return kind


func add_fault(fault: String, block: float, source: String) -> void:
	faults[fault] = {"block": block, "source": source}


## Removes every fault that came from `source`.
func clear_source(source: String) -> void:
	for fault in faults.keys():
		if faults[fault].source == source:
			faults.erase(fault)


func has_fault(fault: String) -> bool:
	return faults.has(fault)


func is_healthy() -> bool:
	return faults.is_empty()


## The worst share of work this device's faults take from its user.
func block() -> float:
	var worst: float = 0.0
	for fault in faults:
		worst = maxf(worst, float(faults[fault].block))
	return worst
