extends RefCounted

var t: TestContext


func _run(day: int = 1) -> RunState:
	var run := RunState.create("Pat Doe", 1)
	run.day = day
	return run


func _claim(priority: int, lapsed: bool = false, age: int = 40) -> Claim:
	var c := Claim.new()
	c.day = 1
	c.age = age
	c.priority = priority
	c.name = "Ana Lee"
	c.card_name = "Ana Lee"
	c.member_id = "BMH-100-0001"
	c.card_member_id = c.member_id
	c.provider = "Riverside General Hospital"
	c.date_of_service = DateUtil.game_date(1) - 5
	c.member_since = DateUtil.game_date(1) - 900
	c.coverage_through = c.date_of_service - 1 if lapsed else DateUtil.game_date(1) + 200
	c.bill_lines = [Claim.make_line("er_visit")]
	c.amount = c.bill_total()
	return c


func test_cited_denial_pays_commission_by_priority() -> void:
	for p in 3:
		var run := _run()
		var r := ShiftLogic.apply_decision(run, _claim(p, true), false, "R-01")
		t.eq(r["pay"], Economy.COMMISSION[p], "priority %d" % p)
		t.eq(run.stats["cited"], 1)


func test_blind_denial_pays_half() -> void:
	var run := _run()
	var r := ShiftLogic.apply_decision(run, _claim(Claim.Priority.URGENT), false, "")
	t.eq(r["pay"], Economy.BLIND_COMMISSION[1])
	t.eq(run.stats["blind"], 1)


func test_wrong_rule_counts_as_blind() -> void:
	var run := _run(3)
	var r := ShiftLogic.apply_decision(run, _claim(Claim.Priority.ROUTINE, true), false, "R-03")
	t.eq(r["pay"], Economy.BLIND_COMMISSION[0], "R-03 does not apply to a lapsed card")


func test_approval_costs_by_priority() -> void:
	for p in 3:
		var run := _run()
		var r := ShiftLogic.apply_decision(run, _claim(p), true, "")
		t.eq(r["pay"], -Economy.APPROVAL_COST[p], "priority %d" % p)
		t.eq(run.today["deductions"], Economy.APPROVAL_COST[p])


func test_denial_discontent_by_priority() -> void:
	for p in 3:
		var run := _run()
		var before := run.discontent
		ShiftLogic.apply_decision(run, _claim(p, true), false, "R-01")
		t.near(run.discontent - before, Economy.DISCONTENT_DENY[p], 0.001, "priority %d" % p)


func test_child_denial_discontent_x1_5() -> void:
	var run := _run()
	var r := ShiftLogic.apply_decision(run, _claim(Claim.Priority.CRITICAL, true, 7), false, "R-01")
	t.near(r["discontent"], Economy.DISCONTENT_DENY[2] * Economy.CHILD_MULT, 0.001)


func test_denybot_doubles_discontent_and_counts_as_cited() -> void:
	var run := _run(7)
	var r := ShiftLogic.apply_decision(run, _claim(Claim.Priority.URGENT), false, "R-07")
	t.near(r["discontent"], Economy.DISCONTENT_DENY[1] * Economy.DENYBOT_MULT, 0.001)
	t.eq(r["pay"], Economy.COMMISSION[1])


func test_protest_adds_one_per_denial() -> void:
	var run := _run()
	run.effects["protest"] = true
	var r := ShiftLogic.apply_decision(run, _claim(Claim.Priority.ROUTINE, true), false, "R-01")
	t.near(r["discontent"], Economy.DISCONTENT_DENY[0] + Economy.PROTEST_EXTRA, 0.001)


func test_compassion_day_free_approvals_double_relief() -> void:
	var run := _run()
	run.effects["compassion"] = true
	run.discontent = 50.0
	var r := ShiftLogic.apply_decision(run, _claim(Claim.Priority.URGENT), true, "")
	t.eq(r["pay"], 0)
	t.near(r["discontent"], -Economy.DISCONTENT_APPROVE[1] * Economy.COMPASSION_RELIEF_MULT, 0.001)
	for i in 4:
		var cited := ShiftLogic.apply_decision(run, _claim(Claim.Priority.ROUTINE, true), true, "")
		t.ok(not cited["citation"] and cited["pay"] == 0, "no citations or fines on Compassion Day")


func test_missed_denial_two_warnings_then_fine() -> void:
	var run := _run()
	var results: Array[Dictionary] = []
	for i in 4:
		results.append(ShiftLogic.apply_decision(run, _claim(Claim.Priority.ROUTINE, true), true, ""))
	t.ok(results[0]["citation"] and results[0]["fine"] == 0, "first is a warning")
	t.eq(results[1]["warning"], 2)
	t.eq(results[1]["fine"], 0)
	t.eq(results[2]["fine"], Economy.CITATION_FINE)
	t.eq(results[3]["pay"], -Economy.APPROVAL_COST[0] - Economy.CITATION_FINE)
	t.eq(run.today["fines"], Economy.CITATION_FINE * 2)


func test_clean_approval_is_never_cited() -> void:
	var run := _run()
	var r := ShiftLogic.apply_decision(run, _claim(Claim.Priority.ROUTINE), true, "")
	t.ok(not r["citation"])


func test_exempt_claim_never_cited() -> void:
	var run := _run()
	var c := _claim(Claim.Priority.URGENT, true)
	c.exempt_from_citation = true
	var r := ShiftLogic.apply_decision(run, c, true, "")
	t.ok(not r["citation"])


func test_compliance_fee_per_miss() -> void:
	var run := _run()
	t.eq(ShiftLogic.compliance_fee(run), Economy.COMPLIANCE_FEE)
	ShiftLogic.compliance_fee(run)
	t.eq(run.today["fees"], Economy.COMPLIANCE_FEE * 2)
	t.eq(ShiftLogic.pay_so_far(run), Economy.BASE_PAY - Economy.COMPLIANCE_FEE * 2)


func test_discontent_clamps_at_zero() -> void:
	var run := _run()
	run.discontent = 0.5
	ShiftLogic.apply_decision(run, _claim(Claim.Priority.CRITICAL), true, "")
	t.eq(run.discontent, 0.0)


func test_decisions_are_recorded_for_the_night() -> void:
	var run := _run()
	var c := _claim(Claim.Priority.CRITICAL, true)
	c.scripted_id = "walt"
	ShiftLogic.apply_decision(run, c, false, "")
	var rec: Dictionary = run.today["decisions"][0]
	t.eq(rec["approved"], false)
	t.eq(rec["blind"], true)
	t.eq(rec["valid_reason"], true)
	t.eq(run.scripted_outcomes["walt"], "denied")
	t.eq(run.stats["processed"], 1)


func test_player_claim_is_not_counted_in_stats() -> void:
	var run := _run(7)
	var c := _claim(Claim.Priority.CRITICAL, true)
	c.is_player = true
	ShiftLogic.apply_decision(run, c, false, "R-01")
	t.eq(run.stats["processed"], 0)
	t.eq(run.scripted_outcomes["player"], "denied")


func test_run_state_round_trip() -> void:
	var run := RunState.create("Pat Doe", 77)
	run.day = 4
	run.savings = 123
	run.discontent = 41.5
	run.family[1]["sick"] = true
	run.family[1]["sick_nights"] = 1
	run.events_fired = [30]
	run.effects["audit"] = true
	run.scripted_outcomes["walt"] = "denied"
	run.deaths.append({"name": "Walt Brennan", "age": 58, "diagnosis": "Heart attack", "day": 1})
	run.morning = {"memo": {"subject": "Hello", "paragraphs": ["a", "b"]}}
	var copy := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	t.eq(copy.player_name, "Pat Doe")
	t.eq(copy.run_seed, 77)
	t.eq(copy.day, 4)
	t.eq(typeof(copy.day), TYPE_INT, "day stays an int after JSON")
	t.eq(copy.savings, 123)
	t.near(copy.discontent, 41.5, 0.001)
	t.eq(copy.family[1]["sick"], true)
	t.eq(typeof(copy.family[1]["sick_nights"]), TYPE_INT)
	t.eq(copy.events_fired, [30] as Array[int])
	t.eq(copy.effects["audit"], true)
	t.eq(copy.scripted_outcomes["walt"], "denied")
	t.eq(copy.deaths[0]["name"], "Walt Brennan")
	t.eq(copy.morning["memo"]["subject"], "Hello")
