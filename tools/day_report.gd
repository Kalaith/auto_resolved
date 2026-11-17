extends SceneTree
## Balancing aid: runs workdays per company archetype under two stand-in
## players and prints what is left open, what PATCH broke and how management
## judged each evening.
##
##   hand   fixes the most urgent ticket back to back (its effort plus
##          WALK_MINUTES of walking each) and never asks PATCH; one day.
##   patch  a careful player with the PATCH a career would have by that tier
##          (TIER_BUDGET points spent cheapest first). Every CHECK_MINUTES it
##          automates each recurring issue at building scope with every
##          safeguard that applies, if the card shows at most AUTOMATE_LIMIT,
##          and sends PATCH the open tickets it is not fixing itself, with a
##          dry run, at most ONE_OFF_LIMIT. By hand it recovers incidents
##          first, then fixes the most urgent ticket. Plays DAYS days, judged
##          each evening as the career does, so a firing shows.
##
##   godot --headless --path . --script res://tools/day_report.gd -- [--policy=hand|patch]
const Catalog = preload("res://scripts/core/catalog.gd")
const Job = preload("res://scripts/sim/job.gd")
const OfficeSim = preload("res://scripts/sim/office_sim.gd")
const PatchState = preload("res://scripts/sim/patch_state.gd")
const CareerRules = preload("res://scripts/sim/career_rules.gd")

const SEEDS: Array[int] = [11, 22, 33, 44, 55, 66, 77, 88]
const WALK_MINUTES: float = 10.0
const DAYS: int = 3
const CHECK_MINUTES: float = 15.0
const AUTOMATE_LIMIT: float = 0.25
const ONE_OFF_LIMIT: float = 0.12
## PATCH Points a careful career has spent by the time it reaches each tier.
const TIER_BUDGET: Dictionary = {1: 0, 2: 8, 3: 22, 4: 40}


func _init() -> void:
	Catalog.ensure_loaded()
	var policy: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--policy="):
			policy = argument.trim_prefix("--policy=")
	if policy.is_empty() or policy == "hand":
		_hand_report()
	if policy.is_empty() or policy == "patch":
		_patch_report()
	quit(0)


func _hand_report() -> void:
	print("Hand fixing only, day 1:")
	for id in Catalog.archetype_ids:
		var tickets: int = 0
		var fixed: int = 0
		var left: int = 0
		var staff: int = 0
		for seed_value in SEEDS:
			var office: RefCounted = OfficeSim.create(Job.create(id, seed_value))
			office.begin_day(1)
			var free_at: float = office.clock.stamp()
			while office.day_running:
				office.step(OfficeSim.TICK * 6.0)
				var open: Array = office.helpdesk.queue.by_urgency()
				if office.clock.stamp() >= free_at and not open.is_empty():
					free_at = office.clock.stamp() + office.helpdesk.fix_effort(open[0]) + WALK_MINUTES
					office.helpdesk.resolve(office, open[0], "player")
					fixed += 1
			staff += office.staff.size()
			tickets += office.helpdesk.queue.tickets.size()
			left += office.helpdesk.queue.open_count()
		var runs: float = float(SEEDS.size())
		print("%-18s staff %4.1f  opened %5.1f  fixed by hand %4.1f  open at day end %4.1f" % [
			id, staff / runs, tickets / runs, fixed / runs, left / runs])


func _patch_report() -> void:
	for tier in TIER_BUDGET:
		print("PATCH at tier %d: %s" % [tier, ", ".join(_loadout(int(tier)).upgrades)])
	print("Careful PATCH player, %d days (per day: opened, by hand, by PATCH, backfires; open at the last evening; evenings judged ok/warning/final/fired over %d runs):" % [DAYS, SEEDS.size()])
	for id in Catalog.archetype_ids:
		var totals: Dictionary = {"opened": 0, "hand": 0, "patch": 0, "backfires": 0, "left": 0, "days": 0, "confidence": 0.0}
		var verdicts: Dictionary = {"ok": 0, "warning": 0, "final_warning": 0, "fired": 0}
		for seed_value in SEEDS:
			_play_job(id, seed_value, totals, verdicts)
		var runs: float = float(SEEDS.size())
		var days: float = float(totals.days)
		print("%-18s T%d  opened %5.1f  hand %4.1f  PATCH %4.1f  backfires %3.1f  open %4.1f  conf %3d  %d/%d/%d/%d" % [
			id, Job.create(id, 1).tier, totals.opened / days, totals.hand / days, totals.patch / days, totals.backfires / days,
			totals.left / runs, roundi(totals.confidence / runs), verdicts.ok, verdicts.warning, verdicts.final_warning, verdicts.fired])


## One job of up to DAYS days; adds its tallies to `totals` and `verdicts`.
func _play_job(id: String, seed_value: int, totals: Dictionary, verdicts: Dictionary) -> void:
	var job: RefCounted = Job.create(id, seed_value)
	var office: RefCounted = OfficeSim.create(job, _loadout(job.tier))
	var sent: Dictionary = {}
	for day in range(1, DAYS + 1):
		office.begin_day(day)
		var free_at: float = office.clock.stamp()
		var check_at: float = office.clock.stamp()
		while office.day_running:
			office.step(OfficeSim.TICK * 6.0)
			var now: float = office.clock.stamp()
			if now >= check_at:
				check_at = now + CHECK_MINUTES
				_ask_patch(office, sent)
			if now >= free_at:
				free_at = now + _work_by_hand(office, sent)
		var summary: Dictionary = office.day_summaries[-1]
		totals.opened += int(summary.opened)
		totals.hand += int(summary.by_player)
		totals.patch += int(summary.by_patch)
		totals.backfires += int(summary.backfires)
		totals.days += 1
		var verdict: String = CareerRules.judge_day(office)
		verdicts[verdict if verdicts.has(verdict) else "ok"] += 1
		if verdict == "warning" or verdict == "final_warning":
			office.summon_manager()
		if verdict == "fired" or day == DAYS:
			totals.left += office.helpdesk.queue.open_count()
			totals.confidence += office.metrics.confidence
			return


## Recovers the first active incident, else fixes the most urgent ticket
## PATCH has not been sent. Returns the minutes it took (0 when idle).
func _work_by_hand(office: RefCounted, sent: Dictionary) -> float:
	var desk: RefCounted = office.patch_desk
	for incident in desk.active_incidents():
		var ids: Array[String] = desk.recoveries_for(incident)
		if not ids.is_empty() and desk.recover(office, incident, ids[0]):
			return desk.recovery_effort(ids[0]) * office.patch.recovery_scale() + WALK_MINUTES
	for ticket in office.helpdesk.queue.by_urgency():
		if not sent.has(ticket.id):
			var minutes: float = office.helpdesk.fix_effort(ticket) + WALK_MINUTES
			office.helpdesk.resolve(office, ticket, "player")
			return minutes
	return 0.0


## Automates what keeps coming back, then hands PATCH the open tickets the
## player will not reach first (the most urgent stays for the player).
func _ask_patch(office: RefCounted, sent: Dictionary) -> void:
	var desk: RefCounted = office.patch_desk
	for issue in desk.categories(office):
		if _automated(desk, issue):
			continue
		var proposal: RefCounted = desk.propose_category(office, issue)
		if proposal == null:
			continue
		if proposal.action().scopes.has("building"):
			proposal.scope = "building"
		_guard(office, proposal)
		if proposal.shown_risk <= AUTOMATE_LIMIT:
			desk.approve(office, proposal, false)
	var open: Array = office.helpdesk.queue.by_urgency()
	for index in range(1, open.size()):
		var ticket: RefCounted = open[index]
		if sent.has(ticket.id) or ticket.status != "new":
			continue
		var proposal: RefCounted = desk.propose_ticket(office, ticket)
		if proposal == null:
			continue
		_guard(office, proposal)
		if proposal.shown_risk <= ONE_OFF_LIMIT:
			sent[ticket.id] = true
			desk.approve(office, proposal, true)


## Every safeguard PATCH has that applies to the proposal (as the card offers).
func _guard(office: RefCounted, proposal: RefCounted) -> void:
	for safeguard in office.patch.safeguards():
		var applies: bool = true
		match safeguard:
			"staged":
				applies = proposal.scope != "ticket"
			"dry_run":
				applies = proposal.scope == "ticket"
			"confirm_delete":
				applies = proposal.action().risk_class == "destructive"
		if applies and not proposal.safeguards.has(safeguard):
			proposal.safeguards.append(safeguard)
	proposal.refresh(office)


func _automated(desk: RefCounted, issue: String) -> bool:
	for automation in desk.automations:
		if automation.covers_issue(issue):
			return true
	return false


## The PATCH a careful career brings to `tier`: TIER_BUDGET points spent on
## the cheapest upgrade it can buy, again and again.
func _loadout(tier: int) -> RefCounted:
	var patch: RefCounted = PatchState.new()
	var budget: int = int(TIER_BUDGET[tier])
	while true:
		var best: String = ""
		for id in Catalog.upgrade_ids:
			var upgrade: Dictionary = Catalog.upgrade(id)
			if patch.has(id) or int(upgrade.cost) > budget:
				continue
			var ready: bool = true
			for need in upgrade.requires:
				ready = ready and patch.has(str(need))
			if ready and (best.is_empty() or int(upgrade.cost) < int(Catalog.upgrade(best).cost)):
				best = id
		if best.is_empty():
			return patch
		patch.upgrades.append(best)
		budget -= int(Catalog.upgrade(best).cost)
	return patch
