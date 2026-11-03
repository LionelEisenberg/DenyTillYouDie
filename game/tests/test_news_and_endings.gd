extends RefCounted

var t: TestContext


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	return rng


func _yesterday(day: int) -> Dictionary:
	return {"day": day, "decisions": [], "overturned": [], "deaths": [], "events": [], "family_deaths": [],
		"fines": 0, "warnings": 0, "legal": 0, "penalty": 0}


func _rec(approved: bool, scripted_id: String = "") -> Dictionary:
	return {"claim_no": "BM-1", "name": "Ana Lee", "age": 40, "diagnosis": "Stroke", "priority": 2,
		"scripted_id": scripted_id, "child": false, "is_player": false, "approved": approved,
		"cited_rule": "", "blind": not approved, "valid_reason": true, "exempt": false}


func _run(day: int) -> RunState:
	var run := RunState.create("Pat Doe", 5)
	run.day = day
	return run


func test_event_leads_paper() -> void:
	var y := _yesterday(2)
	y["events"] = [55]
	var paper := NewsWriter.build_paper(_run(3), y, _rng())
	t.eq(paper["lead"]["headline"], NewsPool.EVENT_LEADS[55]["headline"])


func test_obituary_for_each_death() -> void:
	var y := _yesterday(2)
	var a := _rec(false)
	a["name"] = "Ana Lee"
	var b := _rec(false)
	b["name"] = "Bo Kim"
	y["deaths"] = [a, b]
	var paper := NewsWriter.build_paper(_run(3), y, _rng())
	var text := JSON.stringify(paper["items"])
	t.ok(text.contains("Ana Lee"), "Ana's obituary")
	t.ok(text.contains("Bo Kim"), "Bo's obituary")


func test_lily_denied_story() -> void:
	var y := _yesterday(2)
	y["decisions"] = [_rec(false, "lily")]
	var paper := NewsWriter.build_paper(_run(3), y, _rng())
	t.ok(String(paper["lead"]["headline"]).contains("3,210"), "fundraiser headline")


func test_stock_rises_with_denials() -> void:
	var harsh := _yesterday(2)
	var kind := _yesterday(2)
	for i in 6:
		harsh["decisions"].append(_rec(false))
		kind["decisions"].append(_rec(true))
	t.ok(NewsWriter.build_paper(_run(3), harsh, _rng())["stock"]["change"] > 0.0, "denials lift the stock")
	t.ok(NewsWriter.build_paper(_run(3), kind, _rng())["stock"]["change"] < 0.0, "approvals sink it")


func test_paper_has_date_and_items() -> void:
	var paper := NewsWriter.build_paper(_run(2), _yesterday(1), _rng())
	t.eq(paper["date"], "Tuesday, March 3, 2026")
	t.ok((paper["items"] as Array).size() >= 2, "at least two items")


func test_memo_announces_new_rule() -> void:
	for day in range(1, 8):
		var memo := NewsWriter.build_memo(_run(day), _yesterday(day - 1))
		var text: String = "\n".join(memo["paragraphs"]) + String(memo["subject"])
		t.ok(text.contains(Rules.new_rule_on(day)["id"]), "day %d memo names its rule" % day)


func test_memo_reports_fines_and_appeals() -> void:
	var y := _yesterday(2)
	y["fines"] = 20
	y["warnings"] = 4
	y["legal"] = 40
	y["overturned"] = [_rec(false), _rec(false)]
	var memo := NewsWriter.build_memo(_run(3), y)
	var text := "\n".join(memo["paragraphs"])
	t.ok(text.contains("$20"), "fines")
	t.ok(text.contains("$40"), "legal fees")


func test_memo_explains_todays_effect() -> void:
	var run := _run(4)
	run.effects["audit"] = true
	var text := "\n".join(NewsWriter.build_memo(run, _yesterday(3))["paragraphs"])
	t.ok(text.to_lower().contains("audit"), "audit explained")


func test_walt_letter_after_denial() -> void:
	var y := _yesterday(1)
	y["decisions"] = [_rec(false, "walt")]
	var letters := NewsWriter.build_letters(_run(2), y)
	t.eq(letters.size(), 1)
	t.ok(JSON.stringify(letters[0]).contains("Brennan"))
	t.eq(NewsWriter.build_letters(_run(2), _yesterday(1)).size(), 0, "no letter otherwise")


func test_final_approve_is_fired() -> void:
	var run := _run(7)
	t.eq(Endings.resolve_final(run, true), Endings.FIRED)


func test_final_deny_high_rate_promoted() -> void:
	var run := _run(7)
	run.stats["processed"] = 40
	run.stats["denied"] = int(ceil(40 * Economy.PROMOTION_RATE))
	t.eq(Endings.resolve_final(run, false), Endings.PROMOTED)


func test_final_deny_low_rate_employee_of_month() -> void:
	var run := _run(7)
	run.stats["processed"] = 40
	run.stats["denied"] = int(40 * Economy.PROMOTION_RATE) - 2
	t.eq(Endings.resolve_final(run, false), Endings.EMPLOYEE_OF_MONTH)


func test_final_claim_scapegoats_over_100() -> void:
	var run := _run(7)
	run.discontent = 104.0
	run.stats["processed"] = 40
	run.stats["denied"] = 40
	t.eq(Endings.resolve_final(run, false), Endings.SCAPEGOATED)
	t.eq(Endings.resolve_final(run, true), Endings.SCAPEGOATED)


func test_every_ending_builds_a_page() -> void:
	var run := _run(7)
	run.member("child")["alive"] = false
	for id in [Endings.SCAPEGOATED, Endings.EVICTED, Endings.FIRED, Endings.EMPLOYEE_OF_MONTH, Endings.PROMOTED]:
		var page := Endings.build(run, id)
		t.ok(String(page["title"]) != "", "%s title" % id)
		t.ok(String(page["paper"]["headline"]) != "", "%s headline" % id)
		t.ok((page["epilogue"] as PackedStringArray).size() >= 2, "%s epilogue" % id)
		t.ok(JSON.stringify(page["epilogue"]).contains("Riley"), "%s mentions the family" % id)
		t.ok((page["stats"] as Array).size() >= 5, "%s stats" % id)
