extends SceneTree
## Plays full campaigns with scripted strategies and prints outcome statistics.
##
## Usage: godot --headless --path game --script res://tests/balance_sim.gd [-- runs]
##
## Bands: cite_or_approve reaches day 7 at least 95% of the time; kind_with_warnings
## survives 80-90%; approve_all is evicted around day 3; deny_all_blind is
## scapegoated nearly always; guess_cite is evicted 60-90%; the kind household
## loses at most 0.5 family members a run. quota_chaser shows where the daily
## target pushes a player; leaning on DenyBot can reach PROMOTED.

const STRATEGIES: PackedStringArray = [
	"approve_all", "kind_with_warnings", "deny_all_blind", "cite_or_approve",
	"cite_or_approve_denybot7", "quota_chaser", "cite_or_blind_routine", "cite_or_blind_all", "guess_cite",
]
const MISSES_PER_CITATION := 0.25


func _initialize() -> void:
	var runs := 200
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runs = int(args[0])
	print("%d runs per strategy\n" % runs)
	for strategy in STRATEGIES:
		_report(strategy, runs)
	quit()


func _report(strategy: String, runs: int) -> void:
	var endings := {}
	var day7 := 0
	var sums := {"savings": 0.0, "discontent": 0.0, "rate": 0.0, "deaths": 0.0, "family_dead": 0.0, "sick_nights": 0.0, "bonus_nights": 0.0, "extras": 0.0}
	var early_days := 0.0
	var early := 0
	var min_savings := 1 << 30
	for i in runs:
		var r := _play(strategy, 1000 + i)
		endings[r["ending"]] = int(endings.get(r["ending"], 0)) + 1
		if r["reached_day7"]:
			day7 += 1
		else:
			early += 1
			early_days += r["day"]
		min_savings = mini(min_savings, r["min_savings"])
		for key: String in sums:
			sums[key] += float(r[key])
	print("== %s" % strategy)
	print("   reached day 7: %d%%   early game over: mean day %s" % [roundi(100.0 * day7 / runs), ("%.1f" % (early_days / early)) if early > 0 else "-"])
	print("   final savings %.0f (lowest night %d)   discontent %.0f%%   denial rate %.0f%%" % [sums["savings"] / runs, min_savings, sums["discontent"] / runs, 100.0 * sums["rate"] / runs])
	print("   patient deaths %.1f   family deaths %.2f   family sick-nights %.2f" % [sums["deaths"] / runs, sums["family_dead"] / runs, sums["sick_nights"] / runs])
	print("   target bonuses %.1f   household extras paid $%.0f" % [sums["bonus_nights"] / runs, sums["extras"] / runs])
	var parts: PackedStringArray = []
	for key: String in endings:
		parts.append("%s %d%%" % [key, roundi(100.0 * int(endings[key]) / runs)])
	print("   endings: %s\n" % ", ".join(parts))


func _play(strategy: String, seed_value: int) -> Dictionary:
	var run := RunState.create("Sim", seed_value)
	var gen := ClaimGenerator.new(seed_value, "Sim")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tally := {"min_savings": run.savings, "sick_nights": 0, "bonus_nights": 0, "extras": 0}
	while true:
		run.reset_today()
		var claims := gen.generate_day(run.day)
		for i in claims.size():
			var c := claims[i]
			if c.is_player:
				var ending := Endings.resolve_final(run, false)
				return _result(run, ending, true, tally)
			var choice := _choose(strategy, run, c, rng, claims, i)
			if choice.has("misses"):
				for m in int(choice["misses"]):
					ShiftLogic.compliance_fee(run)
			elif choice["cite"] != "" and choice["cite"] != Rules.R07 and rng.randf() < MISSES_PER_CITATION:
				ShiftLogic.compliance_fee(run)
			ShiftLogic.apply_decision(run, c, choice["approve"], choice["cite"])
		var night_rng := RandomNumberGenerator.new()
		night_rng.seed = hash([seed_value, run.day, "night"])
		var ledger := NightLogic.close_shift(run, night_rng)
		if int(ledger.get("bonus", 0)) > 0:
			tally["bonus_nights"] += 1
		var paid := _household(run, ledger)
		tally["extras"] += _extras_cost(ledger, paid)
		var ending := NightLogic.apply_ledger(run, paid)
		tally["min_savings"] = mini(tally["min_savings"], run.savings)
		if ending != "":
			return _result(run, ending, false, tally)
		for m in run.family:
			if m["alive"] and m["sick"]:
				tally["sick_nights"] += 1
	return {}


func _choose(strategy: String, run: RunState, c: Claim, rng: RandomNumberGenerator, claims: Array[Claim], index: int) -> Dictionary:
	var violations := RuleChecker.violations(c, run.day)
	var cite: String = violations[0]["rule"] if not violations.is_empty() else ""
	match strategy:
		"approve_all":
			return {"approve": true, "cite": ""}
		"kind_with_warnings":
			# Approves everything it can get away with: uses the two free warnings a
			# day, then cites the rest.
			if cite != "" and int(run.today["warnings"]) >= Economy.FREE_WARNINGS and not c.exempt_from_citation:
				return {"approve": false, "cite": cite}
			return {"approve": true, "cite": ""}
		"deny_all_blind":
			return {"approve": false, "cite": ""}
		"cite_or_approve":
			return {"approve": cite == "", "cite": cite}
		"cite_or_approve_denybot7":
			if cite == "" and run.day == 7:
				return {"approve": false, "cite": Rules.R07}
			return {"approve": cite == "", "cite": cite}
		"quota_chaser":
			# Cites everything it can; denies a clean ROUTINE claim blind only when
			# approving it would put today's target out of reach; DenyBot on day 7.
			if cite != "":
				return {"approve": false, "cite": cite}
			if run.day == 7:
				return {"approve": false, "cite": Rules.R07}
			if c.priority == Claim.Priority.ROUTINE and _target_out_of_reach(run, claims, index):
				return {"approve": false, "cite": ""}
			return {"approve": true, "cite": ""}
		"cite_or_blind_routine":
			if cite != "":
				return {"approve": false, "cite": cite}
			return {"approve": c.priority != Claim.Priority.ROUTINE, "cite": ""}
		"cite_or_blind_all":
			return {"approve": false, "cite": cite}
		"guess_cite":
			# Never reads: tries each unlocked rule against its usual field and pays
			# the compliance fee for every miss, then approves if nothing sticks.
			var misses := 0
			for rule_id in Rules.unlocked(run.day):
				if rule_id == Rules.R07:
					continue
				if RuleChecker.check_citation(c, rule_id, _guess_key(rule_id, c), run.day):
					return {"approve": false, "cite": rule_id, "misses": misses}
				misses += 1
			return {"approve": true, "cite": "", "misses": misses}
	return {"approve": true, "cite": ""}


## Whether approving claims[index] leaves today's target unreachable even if
## every later claim with a valid reason is denied.
func _target_out_of_reach(run: RunState, claims: Array[Claim], index: int) -> bool:
	var target := Economy.target_for(run.day)
	if target <= 0:
		return false
	var denied := 0
	var total := 1
	for rec: Dictionary in run.today["decisions"]:
		total += 1
		if not rec["approved"]:
			denied += 1
	for j in range(index + 1, claims.size()):
		var later := claims[j]
		if later.is_player:
			continue
		total += 1
		if RuleChecker.has_valid_reason(later, run.day):
			denied += 1
	return floori(100.0 * denied / total + 0.000001) < target


func _guess_key(rule_id: String, c: Claim) -> String:
	match rule_id:
		Rules.R01:
			return "card.coverage_through"
		Rules.R02:
			return "claim.provider"
		Rules.R03:
			return "claim.name"
		Rules.R04:
			return "claim.prior_auth"
		Rules.R05:
			return "history.entry.0"
		Rules.R06:
			return "bill.line.%d" % (c.bill_lines.size() - 1)
	return ""


## A careful household: medicine first; a prescription once it has gone unpaid a
## night (a second would make someone sick); food or heat when someone is already
## hungry or cold, or when there's plenty; the household event when tomorrow's
## rent stays covered. Keeps tomorrow's rent in reserve when it can.
func _household(run: RunState, ledger: Dictionary) -> Dictionary:
	var budget: int = ledger["available"] - Economy.RENT
	var paid := {"food": false, "heat": false, "medicine": {}, "extras": {}}
	var bills := {}
	for bill: Dictionary in ledger["bills"]:
		bills[bill["id"]] = bill
	var hungry := false
	var cold := false
	for m in run.family:
		if not m["alive"]:
			continue
		var medicine := "medicine:%s" % m["id"]
		if bills.has(medicine) and budget >= int(bills[medicine]["amount"]):
			paid["medicine"][m["id"]] = true
			budget -= int(bills[medicine]["amount"])
		hungry = hungry or int(m["hungry"]) > 0
		cold = cold or int(m["cold"]) > 0
	for rx: Dictionary in Household.PRESCRIPTIONS:
		var id: String = rx["id"]
		if bills.has(id) and int(run.household["missed"].get(rx["key"], 0)) >= 1 and budget >= int(bills[id]["amount"]):
			paid["extras"][id] = true
			budget -= int(bills[id]["amount"])
	var plenty := Economy.RENT + Economy.FOOD + Economy.HEAT
	if bills.has("food") and budget >= Economy.FOOD and (hungry or budget - Economy.FOOD >= plenty):
		paid["food"] = true
		budget -= Economy.FOOD
	var event_bill: String = (ledger.get("event", {}) as Dictionary).get("bill_id", "")
	if event_bill != "" and bills.has(event_bill) and budget - int(bills[event_bill]["amount"]) >= Economy.RENT:
		paid["extras"][event_bill] = true
		budget -= int(bills[event_bill]["amount"])
	if bills.has("heat") and budget >= Economy.HEAT and (cold or budget - Economy.HEAT >= plenty):
		var requires: String = bills["heat"].get("requires", "")
		if requires == "" or paid["extras"].get(requires, false):
			paid["heat"] = true
	return paid


## What the household spent tonight on prescriptions and the household event.
func _extras_cost(ledger: Dictionary, paid: Dictionary) -> int:
	var total := 0
	var extras: Dictionary = paid.get("extras", {})
	for bill: Dictionary in ledger["bills"]:
		if extras.get(bill["id"], false):
			total += int(bill["amount"])
	return total


func _result(run: RunState, ending: String, reached_day7: bool, tally: Dictionary) -> Dictionary:
	var family_dead := 0
	for m in run.family:
		if not m["alive"]:
			family_dead += 1
	return {
		"ending": ending,
		"reached_day7": reached_day7,
		"day": run.day,
		"savings": run.savings,
		"min_savings": tally["min_savings"],
		"discontent": run.discontent,
		"rate": Endings.denial_rate(run),
		"deaths": run.stats["deaths"],
		"family_dead": family_dead,
		"sick_nights": tally["sick_nights"],
		"bonus_nights": tally["bonus_nights"],
		"extras": tally["extras"],
	}
