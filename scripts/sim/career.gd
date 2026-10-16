extends RefCounted
## The persistent owner of a career: PATCH (its upgrades and memory),
## reputation, lifetime earnings (the score), unspent PATCH Points, the job
## history, the job in progress and the current job board. Everything the
## save holds lives here; career_store.gd writes it.
const Catalog = preload("res://scripts/core/catalog.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")
const PatchState = preload("res://scripts/sim/patch_state.gd")
const JobBoard = preload("res://scripts/sim/job_board.gd")
const OfficeSnapshot = preload("res://scripts/sim/office_snapshot.gd")

const SCHEMA: int = 1
## Where the player is between saves: in a job, at an exit interview's
## upgrade step, or choosing the next job.
const STAGES: Array[String] = ["job", "upgrades", "board"]

var career_seed: int = 0
var patch: PatchState = PatchState.new()
var reputation: int = 0
var earnings: int = 0
var points: int = 0
## [{"archetype", "name", "tier", "days", "ended", "grade", "points", "pay"}]
var history: Array[Dictionary] = []
## {"archetype", "seed", "day", "state"} while a job is in progress, else {}.
var current_job: Dictionary = {}
var offers: Array[Dictionary] = []
var stage: String = "board"


static func fresh(seed_value: int) -> RefCounted:
	var career: RefCounted = load("res://scripts/sim/career.gd").new()
	career.career_seed = seed_value
	career.stage = "job"
	career.current_job = {"archetype": JobBoard.first_archetype(), "seed": JobBoard.first_seed(seed_value), "day": 0, "state": {}}
	return career


## The highest company tier the career's reputation opens.
func max_tier() -> int:
	var tier: int = 1
	for step in [2, 3, 4]:
		if reputation >= Balance.integer("career.tier_reputation.%d" % step):
			tier = step
	return tier


func make_offers() -> void:
	offers = JobBoard.offers(self)
	stage = "board"


## Records a finished job: pay, points, reputation, PATCH's lessons.
func finish_job(record: Dictionary, earned_points: int, reputation_change: int, promoted: String) -> void:
	history.append(record)
	earnings += int(record.pay)
	points += earned_points
	reputation = maxi(0, reputation + reputation_change)
	patch.jobs_done += 1
	if not promoted.is_empty() and not patch.guardrails.has(promoted):
		patch.guardrails.append(promoted)
	current_job = {}
	stage = "upgrades"


## Whether `id` can be bought now: affordable, prerequisites owned, not owned.
func can_buy(id: String) -> bool:
	if patch.has(id) or not Catalog.upgrades.has(id):
		return false
	var upgrade: Dictionary = Catalog.upgrade(id)
	if int(upgrade.cost) > points:
		return false
	for needed in upgrade.requires:
		if not patch.has(str(needed)):
			return false
	return true


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	points -= int(Catalog.upgrade(id).cost)
	patch.upgrades.append(id)
	return true


## Undoes `buy` when the save that should have recorded it failed.
func refund(id: String) -> void:
	if patch.upgrades.has(id):
		patch.upgrades.erase(id)
		points += int(Catalog.upgrade(id).cost)


func take_offer(index: int) -> void:
	var offer: Dictionary = offers[index]
	current_job = {"archetype": offer.archetype, "seed": int(offer.seed), "day": 0, "state": {}}
	offers.clear()
	stage = "job"


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA, "career_seed": career_seed, "patch": patch.to_dict(),
		"career": {"reputation": reputation, "earnings": earnings, "points": points, "history": history.duplicate(true)},
		"current_job": current_job.duplicate(true), "offers": offers.duplicate(true), "stage": stage,
	}


static func from_dict(data: Dictionary) -> RefCounted:
	var career: RefCounted = load("res://scripts/sim/career.gd").new()
	career.career_seed = int(data.career_seed)
	career.patch = PatchState.from_dict(data.patch)
	career.reputation = int(data.career.reputation)
	career.earnings = int(data.career.earnings)
	career.points = int(data.career.points)
	for entry in data.career.history:
		career.history.append(entry)
	career.current_job = data.current_job
	for offer in data.offers:
		career.offers.append(offer)
	career.stage = str(data.stage)
	return career


## The shape check JsonSave runs before trusting or writing a file.
static func valid(data: Dictionary) -> bool:
	if not data.get("career_seed") is float and not data.get("career_seed") is int:
		return false
	if not data.get("patch") is Dictionary or not data.get("career") is Dictionary:
		return false
	var career: Dictionary = data.career
	for key in ["reputation", "earnings", "points"]:
		if not (career.get(key) is float or career.get(key) is int) or float(career[key]) < 0.0:
			return false
	if not career.get("history") is Array or not data.get("offers") is Array:
		return false
	if not data.get("current_job") is Dictionary or not STAGES.has(data.get("stage")):
		return false
	if data.stage == "job":
		var job: Dictionary = data.current_job
		if not Catalog.archetypes.has(job.get("archetype")) or not job.get("state") is Dictionary:
			return false
		if not (job.get("seed") is float or job.get("seed") is int) or not (job.get("day") is float or job.get("day") is int):
			return false
		if not OfficeSnapshot.valid(job.state):
			return false
	for key in ["upgrades", "archetypes_seen", "guardrails", "memories"]:
		if not data.patch.get(key) is Array:
			return false
	for id in data.patch.upgrades:
		if not Catalog.upgrades.has(id):
			return false
	for offer in data.offers:
		if not offer is Dictionary or not Catalog.archetypes.has(offer.get("archetype")):
			return false
	return true
