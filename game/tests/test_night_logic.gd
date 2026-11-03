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
	run.today["decisions"] = [_decision(false, false, true, 1, "eleanor")]
	var ledger := NightLogic.close_shift(run, _rng())
	t.eq(ledger["net"], Economy.BASE_PAY - Economy.BOSS_PENALTY)


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
	t.eq(run.stats["earned"], Economy.BASE_PAY - Economy.LEGAL_FEE, "base pay less legal fees")


func test_eviction_books_the_boss_penalty() -> void:
	var run := _run(4)
	run.savings = -10
	run.today["decisions"] = [_decision(false, false, true, Claim.Priority.URGENT, "eleanor")]
	t.ok(NightLogic.close_shift(run, _rng())["evicted"], "-10 + 45 - 30 cannot cover rent")
	NightLogic.apply_ledger(run, _none_paid())
	t.eq(run.stats["earned"], Economy.BASE_PAY - Economy.BOSS_PENALTY)


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
