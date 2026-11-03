extends SceneTree
## Plays full campaigns with scripted strategies and prints outcome statistics.
##
## Usage: godot --headless --path game --script res://tests/balance_sim.gd [-- runs]
##
## Targets (spec): cite_or_approve reaches day 7 with discontent ~55-85% and lands
## just below the promotion line; deny_all_blind is scapegoated around day 4;
## approve_all is evicted around days 4-5; leaning on DenyBot can reach PROMOTED.

const STRATEGIES: PackedStringArray = [
	"approve_all", "kind_with_warnings", "deny_all_blind", "cite_or_approve",
	"cite_or_approve_denybot7", "cite_or_blind_routine", "cite_or_blind_all",
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
	var sum_savings := 0.0
	var sum_discontent := 0.0
	var sum_rate := 0.0
	var sum_deaths := 0.0
	var sum_family_dead := 0.0
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
		sum_savings += r["savings"]
		min_savings = mini(min_savings, r["min_savings"])
		sum_discontent += r["discontent"]
		sum_rate += r["rate"]
		sum_deaths += r["deaths"]
		sum_family_dead += r["family_dead"]
	print("== %s" % strategy)
	print("   reached day 7: %d%%   early game over: mean day %s" % [roundi(100.0 * day7 / runs), ("%.1f" % (early_days / early)) if early > 0 else "-"])
	print("   final savings %.0f (lowest night %d)   discontent %.0f%%   denial rate %.0f%%" % [sum_savings / runs, min_savings, sum_discontent / runs, 100.0 * sum_rate / runs])
	print("   patient deaths %.1f   family deaths %.2f" % [sum_deaths / runs, sum_family_dead / runs])
	var parts: PackedStringArray = []
	for key: String in endings:
		parts.append("%s %d%%" % [key, roundi(100.0 * int(endings[key]) / runs)])
	print("   endings: %s\n" % ", ".join(parts))


func _play(strategy: String, seed_value: int) -> Dictionary:
	var run := RunState.create("Sim", seed_value)
	var gen := ClaimGenerator.new(seed_value, "Sim")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var min_savings := run.savings
	while true:
		run.reset_today()
		var claims := gen.generate_day(run.day)
		for c in claims:
			if c.is_player:
				var ending := Endings.resolve_final(run, false)
				return _result(run, ending, true, min_savings)
			var choice := _choose(strategy, run, c, rng)
			if choice["cite"] != "" and choice["cite"] != Rules.R07 and rng.randf() < MISSES_PER_CITATION:
				ShiftLogic.compliance_fee(run)
			ShiftLogic.apply_decision(run, c, choice["approve"], choice["cite"])
		var night_rng := RandomNumberGenerator.new()
		night_rng.seed = hash([seed_value, run.day, "night"])
		var ledger := NightLogic.close_shift(run, night_rng)
		var ending := NightLogic.apply_ledger(run, _household(run, ledger))
		min_savings = mini(min_savings, run.savings)
		if ending != "":
			return _result(run, ending, false, min_savings)
	return {}


func _choose(strategy: String, run: RunState, c: Claim, rng: RandomNumberGenerator) -> Dictionary:
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
		"cite_or_blind_routine":
			if cite != "":
				return {"approve": false, "cite": cite}
			return {"approve": c.priority != Claim.Priority.ROUTINE, "cite": ""}
		"cite_or_blind_all":
			return {"approve": false, "cite": cite}
	return {"approve": true, "cite": ""}


## A careful household: medicine first; food or heat when someone is already
## hungry or cold (a second night would make them sick), or when there's plenty;
## always keeps tomorrow's rent in reserve if it can.
func _household(run: RunState, ledger: Dictionary) -> Dictionary:
	var budget: int = ledger["available"] - Economy.RENT
	var paid := {"food": false, "heat": false, "medicine": {}}
	var hungry := false
	var cold := false
	for m in run.family:
		if not m["alive"]:
			continue
		if m["sick"] and budget >= Economy.MEDICINE:
			paid["medicine"][m["id"]] = true
			budget -= Economy.MEDICINE
		hungry = hungry or int(m["hungry"]) > 0
		cold = cold or int(m["cold"]) > 0
	var plenty := Economy.RENT + Economy.FOOD + Economy.HEAT
	if budget >= Economy.FOOD and (hungry or budget - Economy.FOOD >= plenty):
		paid["food"] = true
		budget -= Economy.FOOD
	if budget >= Economy.HEAT and (cold or budget - Economy.HEAT >= plenty):
		paid["heat"] = true
	return paid


func _result(run: RunState, ending: String, reached_day7: bool, min_savings: int) -> Dictionary:
	var family_dead := 0
	for m in run.family:
		if not m["alive"]:
			family_dead += 1
	return {
		"ending": ending,
		"reached_day7": reached_day7,
		"day": run.day,
		"savings": run.savings,
		"min_savings": min_savings,
		"discontent": run.discontent,
		"rate": Endings.denial_rate(run),
		"deaths": run.stats["deaths"],
		"family_dead": family_dead,
	}
