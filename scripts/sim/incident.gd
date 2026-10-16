extends RefCounted
## What went wrong when a PATCH execution backfired, kept so the player can
## trace it (GDD 13): request -> plan -> scope -> execution -> effects ->
## recovery. It also remembers exactly what it touched, so a recovery undoes
## this incident's damage and nothing else.

var id: int = 0
var execution_id: int = 0
var action_id: String = ""
var backfire_id: String = ""
var archetype: String = ""
var severity: int = 1
var created: float = 0.0
## False until the player can see it (false successes hide for a while).
var revealed: bool = false
## active, recovered
var status: String = "active"
## Whether a backup safeguard was on (full restores) and rollback is possible.
var had_backup: bool = false
var can_rollback: bool = false
## The device most affected, for on-site recoveries.
var site_device: String = ""
## What this incident did, for recoveries to undo.
var opened_tickets: Array[int] = []
var deleted_tickets: Array[int] = []
var closed_tickets: Array[int] = []
var devices: Array[String] = []
var floors: Array[int] = []
var lift: bool = false
## [{"at": stamp, "step": request|plan|scope|execution|effect|recovery, "text"}]
var timeline: Array[Dictionary] = []


func source() -> String:
	return "incident:%d" % id


func is_active() -> bool:
	return status == "active"


func note(at: float, step: String, text: String) -> void:
	timeline.append({"at": at, "step": step, "text": text})


func to_dict() -> Dictionary:
	return {
		"id": id, "execution": execution_id, "action": action_id, "backfire": backfire_id, "archetype": archetype,
		"severity": severity, "created": created, "revealed": revealed, "status": status, "timeline": timeline.duplicate(true),
	}
