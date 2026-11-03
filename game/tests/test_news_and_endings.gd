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
		"scripted_id": scripted_id, "child": false, "is_player": false, "fatal": true, "approved": approved,
		"cited_rule": "", "blind": not approved, "valid_reason": true, "exempt": false}


func _run(day: int) -> RunState:
	var run := RunState.create("Pat Doe", 5)
	run.day = day
	return run


func _memo_text(run: RunState, yesterday: Dictionary) -> String:
	return "\n".join(NewsWriter.build_memo(run, yesterday)["paragraphs"])


func _headlines(items: Array) -> PackedStringArray:
	var headlines: PackedStringArray = []
	for item: Dictionary in items:
		headlines.append(item["headline"])
	return headlines


## The value shown next to `label` on an ending page, or "" if it isn't there.
func _stat(page: Dictionary, label: String) -> String:
	for pair: Array in page["stats"]:
		if pair[0] == label:
			return pair[1]
	return ""


## The epilogue's closing line about the family.
func _family_line(page: Dictionary) -> String:
	var epilogue: PackedStringArray = page["epilogue"]
	return epilogue[epilogue.size() - 1]


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


func test_scripted_story_survives_an_event_lead() -> void:
	for id in ["walt", "lily", "marcus"]:
		var y := _yesterday(2)
		y["events"] = [30]
		y["decisions"] = [_rec(false, id)]
		var paper := NewsWriter.build_paper(_run(3), y, _rng())
		t.eq(paper["lead"]["headline"], NewsPool.EVENT_LEADS[30]["headline"], "%s: event leads" % id)
		var story: String = NewsWriter.SCRIPTED_LEADS["%s:denied" % id]["headline"]
		t.ok(JSON.stringify(paper["items"]).contains(story), "%s's story still runs" % id)


func test_lily_approved_dips_the_stock() -> void:
	var y := _yesterday(2)
	for i in 6:
		y["decisions"].append(_rec(false))
	y["decisions"].append(_rec(true, "lily"))
	var paper := NewsWriter.build_paper(_run(3), y, _rng())
	t.near(paper["stock"]["change"], NewsWriter.LILY_DIP, 0.001, "ticker matches the story")


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


func test_two_events_one_night_both_make_the_paper() -> void:
	for pair: Array in [[30, 55], [55, 80]]:
		var y := _yesterday(2)
		y["events"] = pair
		var paper := NewsWriter.build_paper(_run(3), y, _rng())
		t.eq(paper["lead"]["headline"], NewsPool.EVENT_LEADS[pair[1]]["headline"], "%s: the bigger event leads" % [pair])
		var headlines := _headlines(paper["items"])
		t.ok(headlines.has(NewsPool.EVENT_LEADS[pair[0]]["headline"]), "%s: the other event still runs: %s" % [pair, headlines])


func test_three_events_one_night() -> void:
	var y := _yesterday(2)
	y["events"] = [30, 55, 80]
	y["decisions"] = [_rec(false, "walt")]
	var paper := NewsWriter.build_paper(_run(3), y, _rng())
	t.eq(paper["lead"]["headline"], NewsPool.EVENT_LEADS[80]["headline"])
	var headlines := _headlines(paper["items"])
	t.eq(headlines[0], NewsPool.EVENT_LEADS[55]["headline"], "biggest first")
	t.eq(headlines[1], NewsPool.EVENT_LEADS[30]["headline"])
	t.eq(headlines[2], NewsWriter.SCRIPTED_LEADS["walt:denied"]["headline"], "then the displaced story")


func test_memo_explains_every_effect_in_order() -> void:
	var protest := "Protesters have gathered at the entrance."
	var audit := "Regulators are auditing today's denials. Uncited denials of claims with no valid grounds will be overturned, and legal fees will apply."
	var compassion := "today is Compassion Day."
	var run := _run(3)
	run.effects = {"protest": true, "audit": true, "compassion": false}
	var paragraphs: PackedStringArray = NewsWriter.build_memo(run, _yesterday(2))["paragraphs"]
	var text := "\n".join(paragraphs)
	t.ok(text.contains(protest) and text.contains(audit), "protest and audit explained: %s" % text)
	t.ok(text.find(protest) < text.find(audit), "protest first")
	t.ok(not text.contains(compassion))
	var separate := 0
	for p in paragraphs:
		if p.begins_with("Protesters") or p.begins_with("Regulators"):
			separate += 1
	t.eq(separate, 2, "one paragraph each")

	run.effects = {"protest": false, "audit": true, "compassion": true}
	text = _memo_text(run, _yesterday(2))
	t.ok(text.contains(audit) and text.contains(compassion), "audit and compassion explained: %s" % text)
	t.ok(text.find(audit) < text.find(compassion), "audit before compassion")
	t.ok(not text.contains(protest))


func test_audit_memo_matches_the_rule() -> void:
	var run := _run(4)
	run.effects["audit"] = true
	var text := _memo_text(run, _yesterday(3))
	t.ok(text.contains("Uncited denials of claims with no valid grounds will be overturned"), text)
	t.ok(not text.contains("Any denial without a cited reason"), "the old, wrong rule is gone")


func test_condolences_name_everyone() -> void:
	var y := _yesterday(4)
	y["family_deaths"] = ["Sam", "Riley", "Mom"]
	var text := _memo_text(_run(5), y)
	t.ok(text.contains("on the loss of Sam, Riley and Mom."), text)
	y["family_deaths"] = ["Mom"]
	t.ok(_memo_text(_run(5), y).contains("on the loss of Mom."))


func test_day5_memo_says_records_may_rename_the_condition() -> void:
	var text := _memo_text(_run(5), _yesterday(4))
	t.ok(text.contains("A condition on record before the card's MEMBER SINCE date is pre-existing and excluded under grandfathered plan terms. Records may list it under another name."), text)
	t.ok(not text.contains("Related conditions count"))


func test_stock_never_prints_flat() -> void:
	# 9 of 20 denied puts the trend at zero, so the noise alone sets the number.
	var flat: PackedStringArray = []
	for seed_value in 300:
		var y := _yesterday(2)
		for i in 20:
			y["decisions"].append(_rec(i >= 9))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var paper := NewsWriter.build_paper(_run(3), y, rng)
		var change: float = paper["stock"]["change"]
		var headline: String = _headlines(paper["items"])[(paper["items"] as Array).size() - 2]
		if absf(change) < 0.05 or headline == "BMH +0.0%" or headline == "BMH -0.0%":
			flat.append("seed %d: %s" % [seed_value, headline])
	t.eq(flat.size(), 0, "flat tickers: %s" % ", ".join(flat))


func test_flat_stock_leans_with_the_denial_rate() -> void:
	t.near(NewsWriter._never_flat(0.0, 0.6), 0.1, 0.0001, "more denials than the norm: up")
	t.near(NewsWriter._never_flat(-0.0, 0.3), -0.1, 0.0001, "more approvals: down")
	t.near(NewsWriter._never_flat(0.0, 0.45), 0.1, 0.0001, "right at the norm: up")
	t.near(NewsWriter._never_flat(-0.3, 0.9), -0.3, 0.0001, "a real move is kept")
	t.near(NewsWriter._never_flat(0.1, 0.2), 0.1, 0.0001)


func test_rate_percent_rounds_down() -> void:
	var run := _run(7)
	run.stats["processed"] = 48
	run.stats["denied"] = 32
	t.eq(Endings.rate_percent(run), 66, "32 of 48 is 66.7%, shown as 66%")
	run.stats["denied"] = 33
	t.eq(Endings.rate_percent(run), 68)
	run.stats["processed"] = 100
	run.stats["denied"] = 29
	t.eq(Endings.rate_percent(run), 29, "float error never costs a point")
	run.stats["processed"] = 0
	t.eq(Endings.rate_percent(run), 0)


func test_promotion_follows_the_displayed_percent() -> void:
	var run := _run(7)
	run.stats["processed"] = 48
	run.stats["denied"] = 32
	t.eq(Endings.resolve_final(run, false), Endings.EMPLOYEE_OF_MONTH, "66% misses a 67% line")
	t.eq(_stat(Endings.build(run, Endings.EMPLOYEE_OF_MONTH), "Denial rate"), "66%")
	run.stats["denied"] = 33
	t.eq(Endings.resolve_final(run, false), Endings.PROMOTED)
	var page := Endings.build(run, Endings.PROMOTED)
	t.eq(_stat(page, "Denial rate"), "68%")
	t.ok(String(page["paper"]["sub"]).contains("a 68% denial rate"), page["paper"]["sub"])


func test_day6_memo_shows_the_percent_promotion_uses() -> void:
	var run := _run(6)
	run.stats["processed"] = 48
	run.stats["denied"] = 32
	var text := _memo_text(run, _yesterday(5))
	t.ok(text.contains("at least 67%. Yours is currently 66%."), text)
	run.stats["denied"] = 33
	t.ok(_memo_text(run, _yesterday(5)).contains("Yours is currently 68%."))


func test_ending_stats_labels_and_money() -> void:
	var run := _run(7)
	run.stats["earned"] = -43
	run.stats["deaths"] = 2
	var page := Endings.build(run, Endings.EVICTED)
	t.eq(_stat(page, "Money earned"), "-$43", "never $-43")
	t.eq(_stat(page, "Patients who died"), "2")
	t.eq(_stat(page, "Deaths in the paper"), "", "old label gone")
	run.stats["earned"] = 1234
	t.eq(_stat(Endings.build(run, Endings.FIRED), "Money earned"), "$1,234")


func test_evicted_family_is_not_at_home() -> void:
	var run := _run(4)
	var line := _family_line(Endings.build(run, Endings.EVICTED))
	t.eq(line, "Sam, Riley and Mom are staying with relatives.")
	run.member("child")["alive"] = false
	line = _family_line(Endings.build(run, Endings.EVICTED))
	t.eq(line, "Riley did not make it through the week. Sam and Mom are left.")
	run.member("mother")["sick"] = true
	line = _family_line(Endings.build(run, Endings.EVICTED))
	t.ok(line.ends_with("Mom still needs medicine."), line)


func test_surviving_endings_keep_the_family_at_home() -> void:
	var run := _run(7)
	for id in [Endings.FIRED, Endings.PROMOTED, Endings.SCAPEGOATED]:
		t.eq(_family_line(Endings.build(run, id)), "Sam, Riley and Mom are still at home.", id)
	t.eq(_family_line(Endings.build(run, Endings.EMPLOYEE_OF_MONTH)), "Sam, Riley and Mom were at the service.")
