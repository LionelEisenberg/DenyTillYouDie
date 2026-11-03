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


func _decision(approved: bool, blind: bool, valid: bool, priority: int = 0, scripted_id: String = "") -> Dictionary:
	return {
		"claim_no": "BM-0000", "name": "Ana Lee", "age": 40, "diagnosis": "Sepsis",
		"priority": priority, "scripted_id": scripted_id, "child": false, "is_player": false,
		"approved": approved, "cited_rule": "" if blind else "R-01", "blind": blind,
		"valid_reason": valid, "exempt": false,
	}


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
	run.discontent = 99.0
	run.today["decisions"] = [_decision(false, false, true, 2, "walt")]
	NightLogic.close_shift(run, _rng())
	var ending := NightLogic.apply_ledger(run, _all_paid(run))
	t.eq(ending, Endings.SCAPEGOATED)


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
