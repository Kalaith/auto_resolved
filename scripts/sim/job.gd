extends RefCounted
## One employment: which company archetype, its generated name and pay, and the
## seed every per-job system forks its random stream from. Plain data; the same
## archetype and seed always give the same job and the same building.
const Catalog = preload("res://scripts/core/catalog.gd")
const Det = preload("res://addons/hatchery/core/det.gd")

var archetype_id: String = ""
var seed_value: int = 0
var company_name: String = ""
var tier: int = 1
var pay_per_day: int = 0


static func create(archetype: String, job_seed: int) -> RefCounted:
	var job: RefCounted = load("res://scripts/sim/job.gd").new()
	var data: Dictionary = Catalog.archetype(archetype)
	var rng: RandomNumberGenerator = Det.fork(job_seed, "company_name")
	job.archetype_id = archetype
	job.seed_value = job_seed
	job.tier = int(data.tier)
	job.pay_per_day = int(data.pay_per_day)
	job.company_name = _compose_name(str(Det.pick(rng, data.names.first)), str(Det.pick(rng, data.names.second)))
	return job


## "Bloop" + ".io" joins without a space; every other pair is two words.
static func _compose_name(first: String, second: String) -> String:
	return first + second if second.begins_with(".") else first + " " + second


func archetype() -> Dictionary:
	return Catalog.archetype(archetype_id)


func label() -> String:
	return str(archetype().label)
