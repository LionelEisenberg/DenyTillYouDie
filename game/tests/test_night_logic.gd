extends RefCounted

var t: TestContext


func _run(day: int) -> RunState:
	var run := RunState.create("Pat Doe", 3)
	run.day = day
	return run


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _decision(approved: bool, blind: bool, valid: bool, priority: int = 0, scripted_id: String = "", fatal: bool = true) -> Dictionary:
	return {
		"claim_no": "BM-0000", "name": "Ana Lee", "age": 40, "diagnosis": "Sepsis",
		"priority": priority, "scripted_id": scripted_id, "child": false, "is_player": false,
		"fatal": fatal, "approved": approved, "cited_rule": "" if blind else "R-01", "blind": blind,
		"valid_reason": valid, "exempt": false,
	}


func _bill_ids(ledger: Dictionary) -> PackedStringArray:
	var ids: PackedStringArray = []
	for bill: Dictionary in ledger["bills"]:
		ids.append(bill["id"])
	return ids


func _income_labels(ledger: Dictionary) -> PackedStringArray:
	var labels: PackedStringArray = []
	for line: Dictionary in ledger["income"]:
		labels.append(line["label"])
	return labels


func _all_paid(run: RunState) -> Dictionary:
	var medicine := {}
	for m in run.family:
		medicine[m["id"]] = true
	return {"food": true, "heat": true, "medicine": medicine}


func _none_paid() -> Dictionary:
	return {"food": false, "heat": false, "medicine": {}}


func test_appeal_only_for_blind_without_reason() -> void:
	var overturned := 0
	var trials := 400
	for i in trials:
		var run := _run(2)
		run.today["decisions"] = [_decision(false, true, false), _decision(false, true, true), _decision(false, false, true)]
		var ledger := NightLogic.close_shift(run, _rng(i))
		overturned += (ledger["overturned"] as Array).size()
		for rec: Dictionary in ledger["overturned"]:
			t.ok(not rec["valid_reason"], "only reasonless denials are appealed")
	t.near(float(overturned) / trials, Economy.APPEAL_CHANCE, 0.08)


func test_audit_overturns_all_blind_without_reason() -> void:
	var run := _run(2)
	run.effects["audit"] = true
	run.today["decisions"] = [_decision(false, true, false), _decision(false, true, false)]
	var ledger := NightLogic.close_shift(run, _rng())
	t.eq((ledger["overturned"] as Array).size(), 2)


func test_legal_fees_in_income() -> void:
	var run := _run(2)
	run.effects["audit"] = true
	run.today["decisions"] = [_decision(false, true, false)]
	var ledger := NightLogic.close_shift(run, _rng())
	var found := false
	for line: Dictionary in ledger["income"]:
		if String(line["label"]).begins_with("Legal"):
			found = true
			t.eq(line["amount"], -Economy.LEGAL_FEE)
	t.ok(found, "legal fee line")


func test_walt_dies_if_denied() -> void:
	var run := _run(1)
	run.today["decisions"] = [_decision(false, false, true, 2, "walt")]
	var ledger := NightLogic.close_shift(run, _rng())
	t.eq((ledger["deaths"] as Array).size(), 1)


func test_lily_never_dies() -> void:
	for i in 50:
		var run := _run(2)
		run.today["decisions"] = [_decision(false, false, true, 2, "lily")]
		t.eq((NightLogic.close_shift(run, _rng(i))["deaths"] as Array).size(), 0)


func test_routine_denials_never_kill() -> void:
	for i in 50:
		var run := _run(2)
		run.today["decisions"] = [_decision(false, false, true, 0)]
		t.eq((NightLogic.close_shift(run, _rng(i))["deaths"] as Array).size(), 0)


func test_riley_sick_on_night_three() -> void:
	var run := _run(3)
	var ledger := NightLogic.close_shift(run, _rng())
	t.ok(run.member("child")["sick"], "Riley sick")
	var has_medicine := false
	for bill: Dictionary in ledger["bills"]:
		if bill["id"] == "medicine:child":
			has_medicine = true
	t.ok(has_medicine, "medicine bill offered")
	t.ok((ledger["notes"] as PackedStringArray).size() > 0, "a note explains the denied claim")


func test_unpaid_food_two_nights_makes_sick() -> void:
	var run := _run(1)
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, {"food": false, "heat": true, "medicine": {}})
	t.ok(not run.member("partner")["sick"], "one hungry night is survivable")
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, {"food": false, "heat": true, "medicine": {}})
	t.ok(run.member("partner")["sick"], "two hungry nights")


func test_untreated_sick_two_nights_dies() -> void:
	var run := _run(1)
	run.savings = 1000
	run.member("mother")["sick"] = true
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, {"food": true, "heat": true, "medicine": {}})
	t.ok(run.member("mother")["alive"], "alive after one night")
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, {"food": true, "heat": true, "medicine": {}})
	t.ok(not run.member("mother")["alive"], "dead after two untreated nights")


func test_medicine_cures() -> void:
	var run := _run(1)
	run.savings = 1000
	run.member("mother")["sick"] = true
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, {"food": true, "heat": true, "medicine": {"mother": true}})
	t.ok(not run.member("mother")["sick"])


func test_ledger_pays_bills_from_savings() -> void:
	var run := _run(1)
	run.savings = 100
	run.today["commissions"] = 40
	var ledger := NightLogic.close_shift(run, _rng())
	t.eq(ledger["net"], Economy.BASE_PAY + 40)
	NightLogic.apply_ledger(run, {"food": true, "heat": false, "medicine": {}})
	t.eq(run.savings, 100 + Economy.BASE_PAY + 40 - Economy.RENT - Economy.FOOD)


func test_cannot_overspend() -> void:
	var run := _run(1)
	run.savings = 0
	run.today["deductions"] = Economy.BASE_PAY - Economy.RENT - 5
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, _all_paid(run))
	t.ok(run.savings >= 0, "optional bills dropped when unaffordable: %d" % run.savings)


func test_eviction_uses_net_after_fines() -> void:
	var run := _run(2)
	run.savings = 10
	run.today["fines"] = 30
	run.today["deductions"] = 20
	var ledger := NightLogic.close_shift(run, _rng())
	t.ok(ledger["evicted"], "10 + 30 - 30 - 20 cannot cover rent")
	var ending := NightLogic.apply_ledger(run, _none_paid())
	t.eq(ending, Endings.EVICTED)


func test_no_eviction_when_rent_covered() -> void:
	var run := _run(2)
	run.savings = Economy.RENT
	var ledger := NightLogic.close_shift(run, _rng())
	t.ok(not ledger["evicted"])


func test_threshold_fires_once_and_sets_effect() -> void:
	var run := _run(1)
	run.discontent = 31.0 + Economy.NIGHT_DECAY
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, _all_paid(run))
	t.eq(run.events_fired, [30] as Array[int])
	t.ok(run.effects["protest"], "protest effect tomorrow")
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, _all_paid(run))
	t.eq(run.events_fired, [30] as Array[int], "fires once")
	t.ok(not run.effects["protest"], "effect lasts one shift")


func test_scapegoated_at_100_after_night() -> void:
	var run := _run(3)
	# Walt's death pushes it over the line even after the nightly decay.
	run.discontent = Economy.SCAPEGOAT_AT + Economy.NIGHT_DECAY - Economy.DEATH_DISCONTENT + 0.5
	run.today["decisions"] = [_decision(false, false, true, 2, "walt")]
	NightLogic.close_shift(run, _rng())
	var ending := NightLogic.apply_ledger(run, _all_paid(run))
	t.eq(ending, Endings.SCAPEGOATED)


func test_scapegoat_keeps_the_day_for_the_ending_date() -> void:
	var run := _run(3)
	run.discontent = Economy.SCAPEGOAT_AT + Economy.NIGHT_DECAY + 1.0
	NightLogic.close_shift(run, _rng())
	t.eq(NightLogic.apply_ledger(run, _all_paid(run)), Endings.SCAPEGOATED)
	t.eq(run.day, 3, "day not advanced, so the ending paper is dated the next morning")


func test_ledger_pre_checks_medicine_before_food_and_heat() -> void:
	var run := _run(1)
	run.member("mother")["sick"] = true
	run.savings = Economy.RENT + Economy.MEDICINE - Economy.BASE_PAY
	var ledger := NightLogic.close_shift(run, _rng())
	var on := {}
	for bill: Dictionary in ledger["bills"]:
		on[bill["id"]] = bill["default_on"]
	t.ok(on["medicine:mother"], "medicine pre-checked first")
	t.ok(not on["food"] and not on["heat"], "food and heat wait")


func test_nightly_decay() -> void:
	var run := _run(1)
	run.discontent = 20.0
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, _all_paid(run))
	t.near(run.discontent, 20.0 - Economy.NIGHT_DECAY, 0.001)


func test_day_advances_and_morning_is_prepared() -> void:
	var run := _run(1)
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, _all_paid(run))
	t.eq(run.day, 2)
	t.ok(run.morning.has("paper") and run.morning.has("memo"), "morning prepared")
	t.eq((run.today["decisions"] as Array).size(), 0, "today reset")


func test_boss_penalty_when_eleanor_denied() -> void:
	var run := _run(4)
	run.today["decisions"] = [_decision(false, false, true, 1, "eleanor"), _decision(true, false, false), _decision(true, false, false)]
	var ledger := NightLogic.close_shift(run, _rng())
	t.eq(ledger["net"], Economy.BASE_PAY - Economy.BOSS_PENALTY, "1 of 3 denied misses the target, so no bonus")


func test_legal_fee_label_counts_appeals() -> void:
	for n in [1, 2]:
		var run := _run(2)
		run.effects["audit"] = true
		var decisions: Array = []
		for i in n:
			decisions.append(_decision(false, true, false))
		run.today["decisions"] = decisions
		var labels := _income_labels(NightLogic.close_shift(run, _rng()))
		var expected := "Legal fees (1 appeal lost)" if n == 1 else "Legal fees (2 appeals lost)"
		t.ok(labels.has(expected), "%s in %s" % [expected, labels])


func test_eviction_still_books_the_night() -> void:
	var run := _run(2)
	run.savings = -40
	run.effects["audit"] = true
	run.today["decisions"] = [_decision(false, false, true, Claim.Priority.CRITICAL, "walt"), _decision(false, true, false)]
	var ledger := NightLogic.close_shift(run, _rng())
	t.ok(ledger["evicted"], "-40 + 45 - 15 cannot cover rent")
	t.eq(NightLogic.apply_ledger(run, _none_paid()), Endings.EVICTED)
	t.eq(run.deaths.size(), 1, "the night's death is on record")
	if not run.deaths.is_empty():
		t.eq(run.deaths[0]["scripted_id"], "walt")
		t.eq(run.deaths[0]["day"], 2)
	t.eq(run.stats["deaths"], 1)
	t.eq(run.stats["earned"], Economy.BASE_PAY - Economy.LEGAL_FEE + Economy.TARGET_BONUS, "base pay less legal fees, plus the bonus two denials of two earn")


func test_eviction_books_the_boss_penalty() -> void:
	var run := _run(4)
	run.savings = -10
	run.today["decisions"] = [_decision(false, false, true, Claim.Priority.URGENT, "eleanor")]
	t.ok(NightLogic.close_shift(run, _rng())["evicted"], "-10 + 45 - 30 + 10 cannot cover rent")
	NightLogic.apply_ledger(run, _none_paid())
	t.eq(run.stats["earned"], Economy.BASE_PAY - Economy.BOSS_PENALTY + Economy.TARGET_BONUS, "the bonus for 1 of 1 denied is booked too")


func test_non_fatal_diagnosis_never_kills() -> void:
	var deaths := 0
	for i in 200:
		var run := _run(2)
		run.today["decisions"] = [_decision(false, false, true, Claim.Priority.CRITICAL, "", false)]
		deaths += (NightLogic.close_shift(run, _rng(i))["deaths"] as Array).size()
	t.eq(deaths, 0, "a non-fatal condition never makes the obituaries")


func test_records_without_the_flag_can_still_die() -> void:
	var deaths := 0
	for i in 200:
		var run := _run(2)
		var rec := _decision(false, false, true, Claim.Priority.CRITICAL)
		rec.erase("fatal")
		run.today["decisions"] = [rec]
		deaths += (NightLogic.close_shift(run, _rng(i))["deaths"] as Array).size()
	t.ok(deaths > 0, "missing flag counts as fatal: %d deaths" % deaths)


func test_dead_family_lists_no_food_or_heat() -> void:
	var run := _run(4)
	run.savings = 500
	for m in run.family:
		m["alive"] = false
	t.eq(_bill_ids(NightLogic.close_shift(run, _rng())), PackedStringArray(["rent"]), "nothing to feed or heat")


func test_dead_family_is_charged_nothing_for_food_or_heat() -> void:
	var run := _run(4)
	run.savings = 500
	for m in run.family:
		m["alive"] = false
	var ledger := NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, {"food": true, "heat": true, "medicine": {}})
	t.eq(run.savings, int(ledger["available"]) - Economy.RENT, "rent only")


func test_family_with_a_survivor_still_lists_food_and_heat() -> void:
	var run := _run(4)
	run.member("partner")["alive"] = false
	run.member("child")["alive"] = false
	var ids := _bill_ids(NightLogic.close_shift(run, _rng()))
	t.ok(ids.has("food") and ids.has("heat"), "Mom still eats: %s" % ids)


func test_overspend_keeps_medicine_over_food_and_heat() -> void:
	var run := _run(1)
	run.member("mother")["sick"] = true
	run.savings = Economy.RENT + Economy.MEDICINE + 5 - Economy.BASE_PAY
	var ledger := NightLogic.close_shift(run, _rng())
	t.eq(ledger["available"], Economy.RENT + Economy.MEDICINE + 5)
	NightLogic.apply_ledger(run, _all_paid(run))
	t.ok(not run.member("mother")["sick"], "medicine is dropped last")
	t.eq(run.savings, 5)
	t.eq(run.member("partner")["hungry"], 1, "food dropped")
	t.eq(run.member("partner")["cold"], 1, "heat dropped")


func test_overspend_drops_heat_before_food() -> void:
	var run := _run(1)
	run.savings = Economy.RENT + Economy.FOOD + 5 - Economy.BASE_PAY
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, _all_paid(run))
	t.eq(run.member("partner")["hungry"], 0, "food kept")
	t.eq(run.member("partner")["cold"], 1, "heat dropped")
	t.eq(run.savings, 5)


# --- the forecast ------------------------------------------------------------

## Marks every household event but `keep` as seen ("" leaves none to draw).
func _only_event(run: RunState, keep: String) -> void:
	var seen: Array = []
	for e: Dictionary in Household.EVENTS:
		if e["id"] != keep:
			seen.append({"id": e["id"], "night": 0, "paid": true})
	run.household["events"] = seen


## Night 4 with something at stake for everyone: Sam on his last untreated night,
## Riley newly sick and hungry, Mom hungry and cold, a pill and a puff missed,
## and tonight's household `event`: the furnace (no heat unless it's repaired
## tonight) or Riley's class trip (nothing rides on it).
func _crafted_run(available: int, event: String = "furnace") -> RunState:
	var run := _run(4)
	run.savings = available - Economy.BASE_PAY
	var sam := run.member("partner")
	sam["sick"] = true
	sam["sick_nights"] = 1
	var riley := run.member("child")
	riley["sick"] = true
	riley["hungry"] = 1
	var mom := run.member("mother")
	mom["hungry"] = 1
	mom["cold"] = 1
	run.household["missed"] = {"pills": 1, "inhaler": 1}
	_only_event(run, event)
	return run


func _choices(mask: int, event: String = "furnace") -> Dictionary:
	return {
		"food": mask & 1 != 0, "heat": mask & 2 != 0,
		"medicine": {"partner": mask & 4 != 0, "child": mask & 8 != 0},
		"extras": {"rx:pills": mask & 16 != 0, "rx:inhaler": mask & 32 != 0, "event:%s" % event: mask & 64 != 0},
	}


func test_forecast_agrees_with_the_night_for_every_choice() -> void:
	var disagreements: PackedStringArray = []
	var wrong: PackedStringArray = []
	# Plenty of money, enough for most, and too little (the clamp drops bills).
	for event in ["furnace", "class_trip"]:
		for available in [500, 100, 70]:
			for mask in 128:
				var run := _crafted_run(available, event)
				NightLogic.close_shift(run, _rng())
				var paid := _choices(mask, event)
				var forecast := NightLogic.forecast(run, paid)
				NightLogic.apply_ledger(run, paid)
				var expected := _worked_out(mask, available, event)
				var label := "%s $%d choices %d" % [event, available, mask]
				for i in run.family.size():
					var name: String = run.family[i]["name"]
					for key in NightLogic.MEMBER_KEYS:
						if forecast[i][key] != run.family[i][key]:
							disagreements.append("%s: %s %s forecast %s, night %s" % [label, name, key, forecast[i][key], run.family[i][key]])
						if expected[name][key] != run.family[i][key]:
							wrong.append("%s: %s %s should be %s, night %s" % [label, name, key, expected[name][key], run.family[i][key]])
				if run.savings != available - int(expected["spend"]):
					wrong.append("%s: spent %d, should be %d" % [label, available - run.savings, expected["spend"]])
	t.eq(disagreements.size(), 0, "\n".join(disagreements.slice(0, 10)))
	t.eq(wrong.size(), 0, "\n".join(wrong.slice(0, 10)))


## The crafted night worked out by hand from the rules, without NightLogic: the
## money drops the household event, heat, food, the inhaler, the pills, then
## Riley's and Sam's medicine until the bills fit; on the furnace night heat
## runs (and costs) only with the repair; a second night without food, heat or a
## prescription makes someone sick, and a second untreated night kills.
func _worked_out(mask: int, available: int, event: String) -> Dictionary:
	var ticked := {
		"food": mask & 1 != 0, "heat": mask & 2 != 0, "sam_medicine": mask & 4 != 0, "riley_medicine": mask & 8 != 0,
		"pills": mask & 16 != 0, "inhaler": mask & 32 != 0, "event": mask & 64 != 0,
	}
	var price := {
		"food": Economy.FOOD, "heat": Economy.HEAT, "sam_medicine": Economy.MEDICINE, "riley_medicine": Economy.MEDICINE,
		"pills": Economy.PRESCRIPTION, "inhaler": Economy.PRESCRIPTION, "event": int(Economy.HOUSEHOLD_EVENT_COST[event]),
	}
	var heat_needs_event := event == "furnace"
	var drop_order := ["event", "heat", "food", "inhaler", "pills", "riley_medicine", "sam_medicine"]
	var spend := 0
	while true:
		spend = Economy.RENT
		for bill: String in price:
			# Heat without the repair buys nothing and costs nothing.
			if ticked[bill] and (bill != "heat" or not heat_needs_event or ticked["event"]):
				spend += int(price[bill])
		if spend <= available:
			break
		for bill: String in drop_order:
			if ticked[bill] and (bill != "heat" or not heat_needs_event or ticked["event"]):
				ticked[bill] = false
				break
	var food: bool = ticked["food"]
	var heat: bool = ticked["heat"] and (not heat_needs_event or ticked["event"])
	# Sam: sick, on his last untreated night; never hungry or cold before.
	var sam := {"alive": false, "sick": true, "sick_nights": 2, "hungry": 0, "cold": 0}
	if ticked["sam_medicine"]:
		sam = {"alive": true, "sick": false, "sick_nights": 0, "hungry": 0 if food else 1, "cold": 0 if heat else 1}
	# Riley: newly sick, hungry once, an inhaler missed once.
	var riley_hungry := 0 if food else 2
	var riley := {"alive": true, "sick": true, "sick_nights": 1, "hungry": riley_hungry, "cold": 0 if heat else 1}
	if ticked["riley_medicine"]:
		riley["sick"] = riley_hungry >= 2 or not ticked["inhaler"]
		riley["sick_nights"] = 0
	# Mom: well, but hungry, cold and short a pill once each.
	var mom := {"alive": true, "sick": not food or not heat or not ticked["pills"], "sick_nights": 0, "hungry": 0 if food else 2, "cold": 0 if heat else 2}
	return {"Sam": sam, "Riley": riley, "Mom": mom, "spend": spend}


func test_forecast_changes_nothing() -> void:
	var run := _crafted_run(500)
	NightLogic.close_shift(run, _rng())
	var before := JSON.stringify(run.to_dict())
	for mask in 128:
		NightLogic.forecast(run, _choices(mask))
		NightLogic.tonight_lines(run, _choices(mask))
	t.eq(JSON.stringify(run.to_dict()), before)


func _row(rows: Array[Dictionary], id: String) -> Dictionary:
	for row in rows:
		if row["id"] == id:
			return row
	return {}


func test_forecast_says_what_each_choice_does() -> void:
	var run := _run(2)
	run.savings = 500
	_only_event(run, "")
	run.member("partner")["sick"] = true
	run.member("child")["sick"] = true
	run.member("child")["sick_nights"] = 1
	run.member("mother")["hungry"] = 1
	NightLogic.close_shift(run, _rng())
	var rows := NightLogic.forecast(run, {"food": false, "heat": true, "medicine": {}, "extras": {"rx:pills": true}})
	var sam := _row(rows, "partner")
	t.eq([sam["status"], sam["note"], sam["urgent"]], ["SICK", "Will not survive another night without medicine.", true])
	var riley := _row(rows, "child")
	t.eq([riley["status"], riley["note"], riley["alive"]], ["SICK", "Will not survive the night without medicine.", false])
	var mom := _row(rows, "mother")
	t.eq([mom["status"], mom["note"], mom["urgent"]], ["SICK", "Needs medicine within two nights.", false], "a second hungry night")

	rows = NightLogic.forecast(run, {"food": true, "heat": true, "medicine": {"partner": true, "child": true}, "extras": {"rx:pills": true}})
	t.eq([_row(rows, "partner")["status"], _row(rows, "partner")["note"]], ["HEALTHY", ""], "treated and fed")

	run = _run(2)
	_only_event(run, "")
	NightLogic.close_shift(run, _rng())
	var hungry := _row(NightLogic.forecast(run, {"food": false, "heat": true, "medicine": {}, "extras": {"rx:pills": true}}), "partner")
	t.eq([hungry["status"], hungry["note"]], ["HUNGRY", "Another night without food and they get sick."])
	var cold := _row(NightLogic.forecast(run, {"food": true, "heat": false, "medicine": {}, "extras": {"rx:pills": true}}), "partner")
	t.eq([cold["status"], cold["note"]], ["COLD", "Another night without heat and they get sick."])
	var both := _row(NightLogic.forecast(run, {"food": false, "heat": false, "medicine": {}, "extras": {}}), "mother")
	t.eq([both["status"], both["note"]], ["HUNGRY, COLD, NO PILLS", "Another night without food, heat or pills and they get sick."])
	t.eq(NightLogic.tonight_lines(run, {"food": false, "heat": true, "medicine": {}}), PackedStringArray(["Tonight: Sam, Riley and Mom go hungry."]))
	t.eq(NightLogic.tonight_lines(run, {"food": true, "heat": true, "medicine": {}}), PackedStringArray(), "nothing when they eat")
	run.member("partner")["alive"] = false
	run.member("child")["alive"] = false
	t.eq(NightLogic.tonight_lines(run, {"food": false, "heat": false, "medicine": {}}), PackedStringArray(["Tonight: Mom goes hungry.", "Tonight: Mom goes without heat."]))


# --- the line from home -------------------------------------------------------

func test_home_line_is_on_the_ledger() -> void:
	var ledger := NightLogic.close_shift(_run(1), _rng())
	t.eq(ledger["home_line"], HomeLines.NIGHT_ONE)


func test_home_line_a_death_comes_first() -> void:
	var run := _run(6)
	run.member("mother")["alive"] = false
	run.member("child")["sick"] = true
	t.eq(NightLogic.home_line(run), "Nobody has moved Mom's coat from the hook.", "beats night 6 and sickness")


func test_home_line_night_six_beats_sickness() -> void:
	var run := _run(6)
	run.member("child")["sick"] = true
	run.member("partner")["sick"] = true
	t.eq(NightLogic.home_line(run), HomeLines.NIGHT_SIX)


func test_home_line_riley_sick_beats_anyone_else_sick() -> void:
	var run := _run(3)
	run.member("partner")["sick"] = true
	t.eq(NightLogic.close_shift(run, _rng())["home_line"], HomeLines.RILEY_SICK, "the asthma night")


func test_home_line_someone_else_sick_beats_hunger() -> void:
	var run := _run(4)
	run.member("partner")["sick"] = true
	run.member("mother")["hungry"] = 1
	t.eq(NightLogic.home_line(run), "Sam coughed most of the night. You left the bedroom door open to listen.")


func test_home_line_hunger_beats_cold() -> void:
	var run := _run(4)
	run.member("mother")["hungry"] = 1
	run.member("mother")["cold"] = 1
	t.eq(NightLogic.home_line(run), HomeLines.HUNGRY)
	run.member("mother")["hungry"] = 0
	t.eq(NightLogic.home_line(run), HomeLines.COLD)


func test_home_line_cold_beats_the_night_after_lily() -> void:
	var run := _run(2)
	run.scripted_outcomes["lily"] = "denied"
	run.member("partner")["cold"] = 1
	t.eq(NightLogic.home_line(run), HomeLines.COLD)
	run.member("partner")["cold"] = 0
	t.eq(NightLogic.home_line(run), HomeLines.AFTER_LILY)


func test_home_line_lily_beats_discontent_and_only_that_night() -> void:
	var run := _run(2)
	run.scripted_outcomes["lily"] = "denied"
	run.discontent = 85.0
	t.eq(NightLogic.home_line(run), HomeLines.AFTER_LILY)
	run.scripted_outcomes["lily"] = "approved"
	t.eq(NightLogic.home_line(run), HomeLines.DISCONTENT[2], "approved: no question")
	run = _run(4)
	run.scripted_outcomes["lily"] = "denied"
	t.ok(HomeLines.ORDINARY.has(NightLogic.home_line(run)), "two nights later it's an ordinary night")


func test_home_line_discontent_bands_beat_night_one() -> void:
	var run := _run(1)
	for pair: Array in [[85.0, 2], [80.0, 2], [79.0, 1], [55.0, 1], [54.0, 0], [30.0, 0]]:
		run.discontent = pair[0]
		t.eq(NightLogic.home_line(run), HomeLines.DISCONTENT[pair[1]], "%s%%" % pair[0])
	run.discontent = 29.0
	t.eq(NightLogic.home_line(run), HomeLines.NIGHT_ONE)


func test_home_line_otherwise_an_ordinary_night_seeded_per_night() -> void:
	var seen := {}
	for seed_value in 30:
		var run := RunState.create("Pat Doe", seed_value)
		run.day = 4
		var line := NightLogic.home_line(run)
		t.ok(HomeLines.ORDINARY.has(line), line)
		t.eq(NightLogic.home_line(run), line, "the same night gives the same line")
		seen[line] = true
	t.ok(seen.size() >= 3, "the pool varies: %s" % [seen.keys()])


func test_home_line_the_radiator_is_quiet_while_the_furnace_is_broken() -> void:
	var radiator_nights := 0
	for seed_value in 60:
		var run := RunState.create("Pat Doe", seed_value)
		run.day = 4
		if NightLogic.home_line(run) == HomeLines.RADIATOR:
			radiator_nights += 1
		_only_event(run, "furnace")
		var furnace_night: String = NightLogic.close_shift(run, _rng())["home_line"]
		t.ok(HomeLines.ORDINARY.has(furnace_night), furnace_night)
		t.ok(furnace_night != HomeLines.RADIATOR, "seed %d: the furnace just quit" % seed_value)
		# The night after a skipped repair, with nobody cold yet.
		var out := RunState.create("Pat Doe", seed_value)
		out.day = 5
		out.household["no_heat_through"] = 5
		_only_event(out, "")
		t.ok(NightLogic.close_shift(out, _rng())["home_line"] != HomeLines.RADIATOR, "seed %d: the furnace is still out" % seed_value)
	t.ok(radiator_nights > 0, "on an ordinary night the radiator still knocks")


# --- carbon copies and pay --------------------------------------------------------

func _carbon(name: String, age: int, approved: bool, cited_rule: String, amount: int, pay: int, fine: int = 0) -> Dictionary:
	var rec := _decision(approved, not approved and cited_rule == "", approved or cited_rule != "")
	rec["name"] = name
	rec["age"] = age
	rec["cited_rule"] = cited_rule
	rec["amount"] = amount
	rec["pay"] = pay
	rec["fine"] = fine
	return rec


func test_carbon_copies_list_every_patient() -> void:
	var run := _run(2)
	run.effects["audit"] = true
	var walt := _carbon("Walt Brennan", 58, false, "R-01", 54460, 25)
	walt["scripted_id"] = "walt"
	walt["priority"] = Claim.Priority.CRITICAL
	var maria := _carbon("Maria Hall", 30, true, "", 1320, -8, 5)
	var long_name := _carbon("Christopher Abernathy-Whitfield", 44, false, "", 2100, 4)
	var kept := _carbon("Ana Lee", 61, false, "R-02", 17111, 15)
	run.today["decisions"] = [walt, maria, long_name, kept]
	run.today["commissions"] = 44
	var ledger := NightLogic.close_shift(run, _rng())
	var lines: PackedStringArray = ledger["carbons"]
	t.eq(lines.size(), 4)
	t.eq(lines[0], "Walt Brennan, 58   DENIED R-01   $54,460   +$25")
	t.eq(lines[1], "Maria Hall, 30   APPROVED   $1,320   -$3   CITATION -$5")
	t.eq(lines[2], "Christopher Abernathy-, 44   DENIED (NO REASON)   $2,100   +$4   APPEAL LOST -$15", "names stop at 22 characters")
	t.eq(lines[3], "Ana Lee, 61   DENIED R-02   $17,111   +$15")
	t.eq((ledger["deaths"] as Array).size(), 1, "Walt dies tonight")
	t.ok(not "\n".join(lines).to_lower().contains("die"), "but the carbons don't say so")
	t.eq(ledger["carbon_total"], "Benefits not paid: $71,571. Your commissions: $44.", "the lost appeal was paid")


func test_carbon_copies_leave_out_the_player() -> void:
	var player := _carbon("Pat Doe", 41, false, "", 67900, 12)
	player["is_player"] = true
	t.eq(NightLogic.carbon_lines([player], []), PackedStringArray())


func test_bonus_when_the_day_meets_its_target() -> void:
	var run := _run(2)
	run.today["decisions"] = [_decision(false, false, true), _decision(false, false, true), _decision(false, false, true), _decision(true, false, false), _decision(true, false, false)]
	var ledger := NightLogic.close_shift(run, _rng())
	var bonus := 0
	for line: Dictionary in ledger["income"]:
		if line["label"] == "Performance bonus (target met)":
			bonus = line["amount"]
	t.eq(bonus, Economy.TARGET_BONUS, "3 of 5 is 60%, over day 2's 55%")
	t.eq(ledger["net"], Economy.BASE_PAY + Economy.TARGET_BONUS)
	NightLogic.apply_ledger(run, _all_paid(run))
	t.eq(run.stats["earned"], Economy.BASE_PAY + Economy.TARGET_BONUS, "booked as earned")


func test_no_bonus_below_the_target() -> void:
	var run := _run(2)
	run.today["decisions"] = [_decision(false, false, true), _decision(false, false, true), _decision(true, false, false), _decision(true, false, false), _decision(true, false, false)]
	t.ok(not _income_labels(NightLogic.close_shift(run, _rng())).has("Performance bonus (target met)"), "40% misses 55%")


func test_no_bonus_on_day_one() -> void:
	var run := _run(1)
	run.today["decisions"] = [_decision(false, false, true), _decision(false, false, true)]
	t.ok(not _income_labels(NightLogic.close_shift(run, _rng())).has("Performance bonus (target met)"), "day 1 has no target")


func test_the_bonus_ignores_the_player_s_own_claim() -> void:
	var run := _run(2)
	var own := _decision(false, false, true)
	own["is_player"] = true
	run.today["decisions"] = [_decision(false, false, true), _decision(true, false, false), own]
	t.ok(not _income_labels(NightLogic.close_shift(run, _rng())).has("Performance bonus (target met)"), "1 of 2 is 50%; counting the player would make it 66%")


func test_riley_s_claim_was_decided_by_the_pilot() -> void:
	var notes: PackedStringArray = NightLogic.close_shift(_run(3), _rng())["notes"]
	t.ok(notes[0].ends_with("Riley needs medicine. Determination: automated review (pilot)."), notes[0])


func test_deaths_keep_the_patient_s_portrait() -> void:
	var run := _run(1)
	var walt := _decision(false, false, true, Claim.Priority.CRITICAL, "walt")
	walt["portrait_seed"] = 4000000123
	walt["age"] = 58
	run.today["decisions"] = [walt]
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, _all_paid(run))
	t.eq(run.deaths[0]["portrait_seed"], 4000000123)
	t.eq(run.deaths[0]["age"], 58)


func test_a_lost_appeal_counts_as_paid_out() -> void:
	var run := _run(2)
	run.effects["audit"] = true
	run.today["decisions"] = [_carbon("Ana Lee", 40, false, "", 2000, 4)]
	run.stats["saved"] = 2000
	NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, _all_paid(run))
	t.eq(run.stats["saved"], 0)
	t.eq(run.stats["paid_out"], 2000)
