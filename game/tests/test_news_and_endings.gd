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
	t.ok(text.contains("at least 67% for the week. Yours is 66%."), text)
	run.stats["denied"] = 33
	t.ok(_memo_text(run, _yesterday(5)).contains("for the week. Yours is 68%."))


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
	t.eq(line, "Sam, Riley and Mom are staying with Sam's sister for now.")
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


# --- photos -------------------------------------------------------------------

func _seeded(rec: Dictionary, portrait_seed: int, age: int) -> Dictionary:
	rec["portrait_seed"] = portrait_seed
	rec["age"] = age
	return rec


func _item(paper: Dictionary, headline: String) -> Dictionary:
	for item: Dictionary in paper["items"]:
		if item["headline"] == headline:
			return item
	return {}


func _letter_from(letters: Array[Dictionary], sender: String) -> Dictionary:
	for letter in letters:
		if letter["from"] == sender:
			return letter
	return {}


func test_obituaries_carry_the_patient_s_photo() -> void:
	var y := _yesterday(2)
	var ana := _seeded(_rec(false), 4000000123, 40)
	y["deaths"] = [ana]
	var obituary := _item(NewsWriter.build_paper(_run(3), y, _rng()), "Obituaries")
	t.eq(obituary.get("portrait_seed", -1), 4000000123)
	t.eq(obituary.get("age", -1), 40)


func test_walt_s_story_carries_his_photo_wherever_it_runs() -> void:
	var y := _yesterday(1)
	y["decisions"] = [_seeded(_rec(false, "walt"), 777, 58)]
	var lead: Dictionary = NewsWriter.build_paper(_run(2), y, _rng())["lead"]
	t.eq(lead.get("portrait_seed", -1), 777, "on the front page")
	t.eq(lead.get("age", -1), 58)
	y["events"] = [30]
	var moved := _item(NewsWriter.build_paper(_run(2), y, _rng()), NewsWriter.SCRIPTED_LEADS["walt:denied"]["headline"])
	t.eq(moved.get("portrait_seed", -1), 777, "moved inside by an event")


func test_records_without_seeds_print_without_photos() -> void:
	var y := _yesterday(1)
	y["decisions"] = [_rec(false, "walt")]
	y["deaths"] = [_rec(false)]
	var paper := NewsWriter.build_paper(_run(2), y, _rng())
	t.ok(not (paper["lead"] as Dictionary).has("portrait_seed"), "no seed, no photo")
	t.ok(not _item(paper, "Obituaries").has("portrait_seed"))
	t.ok(not NewsWriter.build_letters(_run(2), y)[0].has("photo_seed"))


func test_the_families_letters_enclose_a_photo() -> void:
	var y := _yesterday(1)
	y["decisions"] = [_seeded(_rec(false, "walt"), 777, 58)]
	var karen := _letter_from(NewsWriter.build_letters(_run(2), y), "Karen Brennan")
	t.eq([karen.get("photo_seed", -1), karen.get("photo_age", -1)], [777, 58])
	y = _yesterday(6)
	y["decisions"] = [_seeded(_rec(false, "marcus"), 888, 52)]
	var denise := _letter_from(NewsWriter.build_letters(_run(7), y), "Denise Bell")
	t.eq([denise.get("photo_seed", -1), denise.get("photo_age", -1)], [888, 52])


# --- kindness -------------------------------------------------------------------

## Yesterday with one scripted patient, approved or denied, on their day.
func _scripted_day(id: String, approved: bool) -> Dictionary:
	var y := _yesterday(int(Scripted.get_case(id)["day"]))
	y["decisions"] = [_seeded(_rec(approved, id), 321, int(Scripted.get_case(id)["age"]))]
	return y


func _morning(id: String, approved: bool) -> Dictionary:
	var y := _scripted_day(id, approved)
	var run := _run(int(y["day"]) + 1)
	var paper := NewsWriter.build_paper(run, y, _rng())
	return {"paper": paper, "memo": "\n".join(NewsWriter.build_memo(run, y, paper)["paragraphs"]), "letters": NewsWriter.build_letters(run, y)}


func test_walt_approved_writes_and_makes_the_paper() -> void:
	var m := _morning("walt", true)
	var letter := _letter_from(m["letters"], "Walter Brennan")
	t.eq(Array(letter.get("paragraphs", [])), ["To the adjuster at Desk 11,", "The hospital says I go home Thursday. They told me the claim went through, and that it almost didn't.", "I don't know your name. They wouldn't give it to me.", "Thank you.", "Walter Brennan"])
	var item := _item(m["paper"], "Heart patient, 58, home after cardiac care")
	t.ok(not item.is_empty(), "the paper item")
	t.eq(item.get("portrait_seed", -1), 321, "with his photo")
	t.ok((m["memo"] as String).contains("A lapsed-coverage claim was paid yesterday. Lapsed means lapsed."))
	var denied := _morning("walt", false)
	t.ok(_letter_from(denied["letters"], "Walter Brennan").is_empty(), "no thank-you after a denial")
	t.ok(_item(denied["paper"], "Heart patient, 58, home after cardiac care").is_empty())
	t.ok(not (denied["memo"] as String).contains("Lapsed means lapsed."))


func test_lily_approved_sends_a_letter_from_her_father() -> void:
	var letter := _letter_from(_morning("lily", true)["letters"], "Tomas Navarro")
	t.ok(Array(letter.get("paragraphs", [])).has("She drew you a picture. It's on our fridge."), "%s" % [letter])
	t.ok(_letter_from(_morning("lily", false)["letters"], "Tomas Navarro").is_empty())


func test_dale_approved_leaves_a_note() -> void:
	var note := _letter_from(_morning("dale", true)["letters"], "Dale Pruitt")
	t.eq(Array(note.get("paragraphs", [])), ["Thanks for yesterday. Lunch is on me, whenever they give us one.", "Dale (Desk 12)"])
	t.ok(_morning("dale", false)["letters"].is_empty())


func test_priya_approved_makes_the_births_column() -> void:
	var m := _morning("priya", true)
	t.eq(_item(m["paper"], "Births").get("body", ""), "Born Friday at St. Agnes Medical Center, to Priya Raman: a girl, 6 lbs 2 oz.")
	t.ok((m["memo"] as String).contains("Congratulations to the Raman family. Maternity claims are among the plan's most expensive."))
	var denied := _morning("priya", false)
	t.ok(_item(denied["paper"], "Births").is_empty())
	t.ok(not (denied["memo"] as String).contains("Raman family"))


func test_marcus_approved_starts_the_trial() -> void:
	var m := _morning("marcus", true)
	var letter := _letter_from(m["letters"], "Marcus Bell")
	t.eq(Array(letter.get("paragraphs", [])), ["The trial coordinator called. I start Monday.", "Maybe it works, maybe it doesn't. I get to find out.", "Thank you.", "Marcus Bell"])
	var item := _item(m["paper"], NewsWriter.SCRIPTED_ITEMS["marcus:approved"]["headline"])
	t.ok(String(item.get("body", "")).contains("Marcus Bell, 52"), "the trial item")
	t.ok((m["memo"] as String).contains("An excluded service was approved yesterday. The Exclusions list is not a suggestion. It has been laminated."))
	var denied := _morning("marcus", false)
	t.ok(_letter_from(denied["letters"], "Marcus Bell").is_empty())
	t.ok(_item(denied["paper"], NewsWriter.SCRIPTED_ITEMS["marcus:approved"]["headline"]).is_empty())
	t.ok(not (denied["memo"] as String).contains("laminated"))


func test_eleanor_approved_gets_a_mention_upstairs_from_day_six() -> void:
	var line := "I mentioned your name upstairs. -R.H."
	for day in range(5, 8):
		var run := _run(day)
		run.scripted_outcomes["eleanor"] = "approved"
		t.eq(_memo_text(run, _yesterday(day - 1)).contains(line), day >= 6, "day %d" % day)
		run.scripted_outcomes["eleanor"] = "denied"
		t.ok(not _memo_text(run, _yesterday(day - 1)).contains(line), "day %d after a denial" % day)


# --- letters to the editor --------------------------------------------------------

func _named(approved: bool, name: String, cited_rule: String = "") -> Dictionary:
	var rec := _rec(approved)
	rec["name"] = name
	rec["cited_rule"] = cited_rule
	rec["blind"] = not approved and cited_rule == ""
	return rec


func _editor_letter(paper: Dictionary) -> Dictionary:
	return _item(paper, NewsWriter.LETTERS_HEADLINE)


func test_letters_to_the_editor_never_come_from_scripted_patients_the_player_or_the_dead() -> void:
	var writers := {}
	for seed_value in 200:
		var y := _yesterday(3)
		var player := _named(false, "Pat Doe")
		player["is_player"] = true
		player["scripted_id"] = "player"
		var dead := _named(false, "Bo Kim", "R-03")
		y["decisions"] = [_rec(false, "dale"), player, dead, _named(false, "Cy Diaz", "R-02"), _named(true, "Di Moss")]
		y["deaths"] = [dead]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var body: String = _editor_letter(NewsWriter.build_paper(_run(4), y, rng)).get("body", "")
		t.ok(body != "", "seed %d: a letter" % seed_value)
		for name in ["Ana Lee", "Pat Doe", "Bo Kim"]:
			t.ok(not body.contains(name), "seed %d: %s wrote in" % [seed_value, name])
		writers[body.get_slice(" - ", 1)] = true
	t.eq(writers.size(), 2, "only Cy and Di write: %s" % [writers.keys()])


func test_letters_to_the_editor_are_worded_by_the_ruling() -> void:
	var y := _yesterday(2)
	y["decisions"] = [_named(false, "Cy Diaz", "R-01")]
	t.eq(_editor_letter(NewsWriter.build_paper(_run(3), y, _rng()))["body"], "To the editor: Benevolence Mutual says my coverage lapsed. I was late on one payment. One. - Cy Diaz")
	y["decisions"] = [_named(false, "Cy Diaz")]
	t.eq(_editor_letter(NewsWriter.build_paper(_run(3), y, _rng()))["body"], NewsPool.EDITOR_LETTERS[""].format({"name": "Cy Diaz"}), "no reason given")
	for rule: String in ["R-02", "R-03", "R-04", "R-05", "R-06", "R-07"]:
		y["decisions"] = [_named(false, "Cy Diaz", rule)]
		t.eq(_editor_letter(NewsWriter.build_paper(_run(3), y, _rng()))["body"], NewsPool.EDITOR_LETTERS[rule].format({"name": "Cy Diaz"}), rule)
	y["decisions"] = [_named(true, "Di Moss")]
	var thanks := _editor_letter(NewsWriter.build_paper(_run(3), y, _rng()))
	t.eq(thanks["body"], "To the editor: I want to thank the person at Desk 11. I never got a name. - Di Moss", "nobody denied: a thank-you")
	y["decisions"] = [_rec(false, "lily")]
	t.ok(_editor_letter(NewsWriter.build_paper(_run(3), y, _rng())).is_empty(), "nobody to write")


func test_a_thank_you_runs_about_one_morning_in_four() -> void:
	var thanks := 0
	var mornings := 400
	for seed_value in mornings:
		var y := _yesterday(2)
		y["decisions"] = [_named(false, "Cy Diaz", "R-01"), _named(true, "Di Moss")]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		if _editor_letter(NewsWriter.build_paper(_run(3), y, rng)).get("letter", "") == "thanks":
			thanks += 1
	t.near(float(thanks) / mornings, 0.25, 0.07, "%d of %d" % [thanks, mornings])


func test_the_desk_number_note_follows_only_a_thank_you() -> void:
	var note := "A member's letter in today's Ledger thanks the person at Desk 11. Adjusters are reminded not to display desk numbers to members."
	var seen := {}
	for seed_value in 60:
		var y := _yesterday(2)
		y["decisions"] = [_named(false, "Cy Diaz", "R-01"), _named(true, "Di Moss")]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var run := _run(3)
		var paper := NewsWriter.build_paper(run, y, rng)
		var thanked: bool = _editor_letter(paper).get("letter", "") == "thanks"
		t.eq(_memo_text_with(run, y, paper).contains(note), thanked, "seed %d" % seed_value)
		seen[thanked] = true
	t.eq(seen.size(), 2, "both kinds of morning came up")
	t.ok(not _memo_text(_run(3), _yesterday(2)).contains(note), "no paper, no note")


func _memo_text_with(run: RunState, yesterday: Dictionary, paper: Dictionary) -> String:
	return "\n".join(NewsWriter.build_memo(run, yesterday, paper)["paragraphs"])


# --- the target and the ranking -----------------------------------------------------

func test_memos_from_day_two_name_the_target_and_the_promotion_line() -> void:
	var day1 := _memo_text(_run(1), {})
	t.ok(not day1.contains("Claims Integrity target"), "no target on day 1")
	t.ok(not day1.contains("Regional Director position"))
	var run := _run(2)
	run.stats["processed"] = 50
	run.stats["denied"] = 27
	var text := _memo_text(run, _yesterday(1))
	t.ok(text.contains("Claims Integrity target for today: 55% denials. Adjusters who meet it receive a $10 performance bonus."), text)
	t.ok(text.contains("A Regional Director position opens Monday. Candidates need a denial rate of at least 67% for the week. Yours is 54%."), text)
	t.ok(_memo_text(_run(4), _yesterday(3)).contains("target for today: 60% denials"), "each day its own target")
	t.ok(_memo_text(_run(6), _yesterday(5)).contains("target for today: 65% denials. Adjusters who meet it receive a $10 performance bonus."), "day 6 has a night to pay it")


func test_day_seven_promises_no_bonus_it_cannot_pay() -> void:
	var text := _memo_text(_run(7), _yesterday(6))
	t.ok(not text.contains("performance bonus"), text)
	t.ok(not text.contains("Claims Integrity target"), "day 7 has no night")
	t.ok(text.contains("Denial rates, week to date"), "the ranking still runs")
	t.ok(text.contains("Candidates need a denial rate of at least 67% for the week."), "and the promotion line")


func test_the_target_ranking_and_promotion_line_share_one_paragraph() -> void:
	for day in range(2, 8):
		var run := _run(day)
		run.stats["processed"] = 20
		run.stats["denied"] = 11
		var standing: PackedStringArray = []
		for paragraph: String in NewsWriter.build_memo(run, _yesterday(day - 1))["paragraphs"]:
			if paragraph.contains("Denial rates, week to date") or paragraph.contains("Regional Director") or paragraph.contains("Claims Integrity target"):
				standing.append(paragraph)
		t.eq(standing.size(), 1, "day %d: %s" % [day, standing])
		if standing.size() == 1:
			t.eq(standing[0], NewsWriter.standing(run), "day %d" % day)
			t.ok(standing[0].contains("Regional Director") and standing[0].contains("Desk 11 (you) 55%."), "day %d" % day)


func test_the_ranking_starts_on_day_two() -> void:
	t.ok(not _memo_text(_run(1), {}).contains("Denial rates, week to date"))
	var run := _run(2)
	run.stats["processed"] = 25
	run.stats["denied"] = 13
	t.ok(_memo_text(run, _yesterday(1)).contains("Denial rates, week to date: Desk 9 (L. Fitch) 91%. Desk 14 (G. Moreau) 86%. Desk 12 (D. Pruitt) 74%. Desk 11 (you) 52%."), _memo_text(run, _yesterday(1)))


func test_the_other_desks_creep_up_a_point_or_two_a_day() -> void:
	for seed_value in 30:
		for rival: Dictionary in NewsWriter.RIVAL_DESKS:
			var before := int(rival["rate"])
			for day in range(3, 8):
				var rate := NewsWriter.rival_rate(seed_value, rival["desk"], rival["rate"], day)
				t.ok(rate - before >= 1 and rate - before <= 2 or rate == 99, "seed %d desk %d day %d: %d after %d" % [seed_value, rival["desk"], day, rate, before])
				t.ok(rate <= 99, "never 100%")
				before = rate


func test_denying_dale_empties_his_desk_and_approving_him_costs_him_a_point() -> void:
	var run := _run(5)
	var usual := NewsWriter.rival_rate(run.run_seed, 12, 74, 5)
	run.scripted_outcomes["dale"] = "denied"
	var ranking := NewsWriter.ranking(run)
	t.ok(ranking.ends_with("Desk 12 vacant."), ranking)
	t.ok(not ranking.contains("Pruitt"))
	run.scripted_outcomes["dale"] = "approved"
	t.ok(NewsWriter.ranking(run).contains("Desk 12 (D. Pruitt) %d%%." % (usual - 1)), NewsWriter.ranking(run))


func test_the_ranking_puts_the_highest_rate_first() -> void:
	var run := _run(3)
	run.stats["processed"] = 10
	run.stats["denied"] = 10
	t.ok(NewsWriter.ranking(run).begins_with("Denial rates, week to date: Desk 11 (you) 100%."), NewsWriter.ranking(run))


func test_the_other_adjusters_are_not_patients() -> void:
	for rival: Dictionary in NewsWriter.RIVAL_DESKS:
		var last_name := String(rival["name"]).get_slice(" ", 1)
		t.ok(not Names.LAST.has(last_name), "%s is in the patient pool" % last_name)


# --- memo paragraphs ---------------------------------------------------------------

func test_day_three_memo_announces_the_appointment() -> void:
	var line := "R. Hargrove will be out Thursday morning for a family medical appointment. Please extend every courtesy."
	for day in range(1, 8):
		t.eq(_memo_text(_run(day), _yesterday(day - 1)).contains(line), day == 3, "day %d" % day)


func test_day_six_paper_always_covers_the_denybot_pilot() -> void:
	var headline: String = NewsPool.DENYBOT_PILOT["headline"]
	for item: Dictionary in NewsPool.FLAVOR:
		t.ok(item["headline"] != headline, "out of the random pool")
	for seed_value in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		t.ok(_headlines(NewsWriter.build_paper(_run(6), _yesterday(5), rng)["items"]).has(headline), "seed %d" % seed_value)
		rng.seed = seed_value
		t.ok(not _headlines(NewsWriter.build_paper(_run(5), _yesterday(4), rng)["items"]).has(headline), "only on day 6")


func test_day_seven_directive_says_how_long_denybot_has_run() -> void:
	t.ok(_memo_text(_run(7), _yesterday(6)).contains("Its accuracy is excellent. DenyBot has been in pilot since February."))


func test_scapegoat_warnings_at_70_and_90() -> void:
	var at70 := "Communications is preparing answers about individual adjusters. Please make sure every denial has a reason on file."
	var at90 := "If the press, the committee or a neighbor asks about your work, refer them to Communications. Do not discuss your caseload."
	var run := _run(4)
	run.discontent = 69.9
	var text := _memo_text(run, _yesterday(3))
	t.ok(not text.contains(at70) and not text.contains(at90), "below 70")
	run.discontent = 70.0
	text = _memo_text(run, _yesterday(3))
	t.ok(text.contains(at70) and not text.contains(at90), "70")
	run.discontent = 90.0
	text = _memo_text(run, _yesterday(3))
	t.ok(text.contains(at90) and not text.contains(at70), "90 replaces the 70 warning")


func test_day_one_memo_explains_discontent_and_leaves_prices_to_the_stamps() -> void:
	var text := _memo_text(_run(1), {})
	t.ok(text.contains("Public discontent is tracked on the meter above your window. Denials raise it; approvals lower it; it eases overnight. At 100%, the Company will act to protect its reputation, beginning with the adjuster responsible."), text)
	t.ok(text.contains("Each stamp shows what it pays you."))
	t.ok(not text.contains("$3 routine"), "no price list")
	t.ok(not _memo_text(_run(2), _yesterday(1)).contains("Public discontent is tracked"), "day 1 only")


func test_the_morning_after_the_hearing_the_company_braces() -> void:
	var line := "The Company is prepared to act decisively should public attention continue to rise."
	var y := _yesterday(4)
	y["events"] = [80]
	t.ok(_memo_text(_run(5), y).contains(line))
	y["events"] = [55]
	t.ok(not _memo_text(_run(5), y).contains(line), "not after the audit")
	t.ok(not _memo_text(_run(6), _yesterday(5)).contains(line), "only that morning")


func test_the_hearing_line_closes_the_compassion_day_paragraph() -> void:
	var run := _run(5)
	run.effects["compassion"] = true
	var y := _yesterday(4)
	y["events"] = [80]
	var paragraphs: PackedStringArray = NewsWriter.build_memo(run, y)["paragraphs"]
	var found := -1
	for i in paragraphs.size():
		if paragraphs[i].contains("today is Compassion Day"):
			found = i
	t.ok(found >= 0, "%s" % paragraphs)
	t.ok(paragraphs[found].ends_with("Please approve visibly. The Company is prepared to act decisively should public attention continue to rise."), paragraphs[found])
	for i in paragraphs.size():
		t.ok(i == found or not paragraphs[i].contains("act decisively"), "said once")


func test_sunday_staffing_on_day_seven() -> void:
	var line := "Sunday staffing: Desk 11 is the only desk scheduled today and will process all claims, including staff claims. Legal has reviewed this arrangement and found no conflict of interest."
	t.ok(_memo_text(_run(7), _yesterday(6)).contains(line))
	t.ok(not _memo_text(_run(6), _yesterday(5)).contains(line))


func test_sunday_staffing_leaves_room_for_a_colleague_who_comes_in_anyway() -> void:
	# Dale's day-7 note on your claim is signed from Desk 12.
	var run := _run(7)
	run.scripted_outcomes["dale"] = "approved"
	var text := _memo_text(run, _yesterday(6))
	t.ok(not text.contains("only desk open"), text)
	t.ok(text.contains("the only desk scheduled today"))


func test_performance_says_what_you_saved_and_what_you_missed() -> void:
	var y := _yesterday(3)
	var denied_a := _rec(false)
	denied_a["amount"] = 200000
	var denied_b := _rec(false)
	denied_b["amount"] = 12480
	var appealed := _rec(false)
	appealed["amount"] = 5000
	var missed_one := _rec(true)
	missed_one["missed_rule"] = "R-03"
	missed_one["citation"] = true
	var missed_two := _rec(true)
	missed_two["missed_rule"] = "R-01"
	missed_two["citation"] = true
	var eleanor := _rec(true, "eleanor")
	eleanor["missed_rule"] = "R-04"
	eleanor["citation"] = false
	y["decisions"] = [denied_a, denied_b, appealed, missed_one, missed_two, eleanor]
	y["overturned"] = [appealed]
	y["warnings"] = 2
	var text := _memo_text(_run(4), y)
	t.ok(text.contains("Your decisions saved the plan $212,480."), text)
	t.ok(text.contains("You approved 2 claims that had valid grounds for denial (R-01, R-03)."), text)
	t.ok(not text.contains("R-04)"), "the boss's mother is not a miss")
	y["decisions"] = [missed_one]
	y["overturned"] = []
	y["warnings"] = 1
	t.ok(not _memo_text(_run(4), y).contains("saved the plan"), "nothing denied, nothing saved")
