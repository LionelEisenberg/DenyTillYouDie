extends RefCounted
## The last front page and what follows it: follow-ups, obituaries, the real
## numbers, one last document per ending, faces in print, and day 7's favors.

var t: TestContext
var gs: Node
var tree: SceneTree
var screen: ScreenBase

const SPEC_FOLLOW_UPS := {
	"walt": ["Walter Brennan is back at the hardware store, three days a week.", "Walter Brennan's daughter is still paying for the ICU."],
	"lily": ["Lily Navarro, 7, finished her first round of chemotherapy. The nurses let her ring the bell early.", "The fundraiser for Lily Navarro, 7, closed at $3,210."],
	"dale": ["Dale Pruitt still owes you lunch.", "Dale Pruitt works on the fourth floor now. He takes the stairs."],
	"eleanor": ["Eleanor Hargrove is walking again. Her son has not mentioned it.", "Eleanor Hargrove had her hip replaced. Her son paid cash."],
	"priya": ["Priya Raman had a girl, 6 lbs 2 oz. Her name is June.", "Priya Raman had a girl. The hospital has her on a payment plan."],
	"marcus": ["Marcus Bell started the trial on Monday. It is too early to say.", "Marcus Bell's daughter graduates in May."],
}
const DOCUMENT_KINDS := {
	"scapegoated": "memo", "evicted": "notice", "fired": "statement", "employee_of_the_month": "plaque",
	"promoted": "memo", "taken_care_of": "claim_note", "covered": "memo",
}


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	gs.save_path_override = TestContext.save_path()
	_clean_files()


func after_each() -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = null
	await tree.process_frame
	_clean_files()
	gs.save_path_override = ""


func _clean_files() -> void:
	gs.delete_save()
	gs.delete_retry()
	gs.clear_record()


func _run(day: int) -> RunState:
	var run := RunState.create("Pat Doe", 5)
	run.day = day
	return run


func _stat(page: Dictionary, label: String) -> String:
	for pair: Array in page["stats"]:
		if pair[0] == label:
			return pair[1]
	return ""


func _family_line(page: Dictionary) -> String:
	var epilogue: PackedStringArray = page["epilogue"]
	return epilogue[epilogue.size() - 1]


func _player_record(approved: bool, cited_rule: String) -> Dictionary:
	return {"claim_no": "BM-1", "name": "Pat Doe", "age": 41, "diagnosis": "Hypertensive crisis", "priority": 2,
		"scripted_id": "player", "child": false, "is_player": true, "fatal": true, "approved": approved,
		"cited_rule": cited_rule, "blind": not approved and cited_rule == "", "valid_reason": true, "exempt": false}


func _open(s: ScreenBase) -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
		await tree.process_frame
	screen = s
	screen.fast = true
	screen.theme = UiTheme.build()
	tree.root.add_child(screen)
	await tree.process_frame
	await tree.process_frame


func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	if node is Label:
		found.append(node as Label)
	for child in node.get_children():
		found.append_array(_labels(child))
	return found


func _texts(node: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	for l in _labels(node):
		texts.append(l.text)
	return texts


func _count(node: Node, type_name: String) -> int:
	var n := 1 if node.is_class(type_name) or (node.get_script() != null and (node.get_script() as Script).get_global_name() == type_name) else 0
	for child in node.get_children():
		n += _count(child, type_name)
	return n


## A seed whose face has skin tone `index`. With `dark_brows`, also brows that
## are clearly darker than the skin at the window (by the print's feature knee).
func _seed_for_skin(index: int, dark_brows: bool = false) -> int:
	var probe := PortraitView.new()
	for s in 20000:
		probe.show_patient(s, 40, false)
		if probe._skin != Palette.SKIN_TONES[index]:
			continue
		if dark_brows and probe._brow_col.get_luminance() > probe._skin.get_luminance() * (1.0 - NewsPhoto.PRINT_FEATURE_KNEE):
			continue
		probe.free()
		return s
	probe.free()
	return -1


## How the cells PortraitView painted in `color` printed: {count, mean (tone
## index, 0 ink .. 3 paper), counts per tone}.
func _printed(photo: NewsPhoto, color: Color) -> Dictionary:
	var counts := [0, 0, 0, 0]
	var total := 0
	var sum := 0
	for i in photo._np_cells.size():
		if photo._np_figure[i] == 1 and photo._np_cells[i].is_equal_approx(color):
			counts[photo._np_tones[i]] += 1
			sum += photo._np_tones[i]
			total += 1
	return {"count": total, "mean": float(sum) / maxi(total, 1), "counts": counts}


## The tone most of `printed`'s cells came out in; a tie goes to the darker tone
## with `darker`, else to the lighter one.
func _dominant(printed: Dictionary, darker: bool) -> int:
	var counts: Array = printed["counts"]
	var best := 0 if darker else 3
	for tone in (range(4) if darker else range(3, -1, -1)):
		if counts[tone] > counts[best]:
			best = tone
	return best


# --- follow-ups, obituaries, numbers ---------------------------------------

func test_each_scripted_outcome_yields_its_follow_up() -> void:
	for case_data: Dictionary in Scripted.CASES:
		var id: String = case_data["id"]
		for i in 2:
			var outcome: String = ["approved", "denied"][i]
			var run := _run(7)
			run.scripted_outcomes[id] = outcome
			var expected: String = SPEC_FOLLOW_UPS[id][i]
			t.eq(Endings.follow_ups(run), PackedStringArray([expected]), "%s %s" % [id, outcome])
			var page := Endings.build(run, Endings.FIRED)
			t.eq(page["follow_ups"], PackedStringArray([expected]), "%s %s on the page" % [id, outcome])


func test_unseen_cases_yield_no_follow_up() -> void:
	var run := _run(3)
	t.eq(Endings.follow_ups(run).size(), 0, "nobody reached yet")
	run.scripted_outcomes = {"lily": "denied", "walt": "approved", "player": "denied"}
	var lines := Endings.follow_ups(run)
	t.eq(lines.size(), 2, "only the two cases reached: %s" % lines)
	t.eq(lines[0], SPEC_FOLLOW_UPS["walt"][0], "in the order they came in")
	t.eq(lines[1], SPEC_FOLLOW_UPS["lily"][1])


func test_obituaries_list_every_death() -> void:
	var run := _run(5)
	t.ok(not Endings.build(run, Endings.EVICTED).has("obituaries"), "omitted when nobody died")
	run.deaths = [
		{"name": "Walt Brennan", "age": 58, "diagnosis": "Heart attack", "day": 1, "scripted_id": "walt"},
		{"name": "Ana Lee", "age": 71, "diagnosis": "Stroke", "day": 2, "scripted_id": ""},
		{"name": "Bo Kim", "age": 9, "diagnosis": "Sepsis", "day": 4, "scripted_id": ""},
	]
	var obits: String = Endings.build(run, Endings.EVICTED)["obituaries"]
	t.eq(obits, "Walter Brennan, 58. Ana Lee, 71. Bo Kim, 9.")
	t.ok(not obits.to_lower().contains("benevolence") and not obits.to_lower().contains("insur"), "never names the insurer")


func test_evicted_family_line_differs_from_the_alive_line() -> void:
	var run := _run(4)
	var evicted := _family_line(Endings.build(run, Endings.EVICTED))
	var alive := _family_line(Endings.build(run, Endings.FIRED))
	t.ok(evicted != alive, "%s / %s" % [evicted, alive])
	t.ok(not evicted.contains("at home"), evicted)
	run.member("mother")["alive"] = false
	t.ok(_family_line(Endings.build(run, Endings.EVICTED)).begins_with("Mom did not make it through the week."), "the dead variant stays")


func test_own_claim_stat_reads_the_players_record() -> void:
	var run := _run(7)
	t.eq(_stat(Endings.build(run, Endings.EVICTED), "Your own claim"), "", "no row before the player's claim")
	var denied := _player_record(false, "R-05")
	denied["pay"] = 25
	run.today["decisions"] = [_player_record(true, ""), denied]
	t.eq(_stat(Endings.build(run, Endings.PROMOTED), "Your own claim"), "Approved", "the first player record wins")
	run.today["decisions"] = [denied]
	t.eq(_stat(Endings.build(run, Endings.PROMOTED), "Your own claim"), "Denied (R-05), +$25")
	run.today["decisions"] = [_player_record(false, "")]
	t.eq(_stat(Endings.build(run, Endings.EMPLOYEE_OF_MONTH), "Your own claim"), "Denied (uncited)", "records without pay still read")
	# The real thing, through GameState.
	gs.new_run("Pat Doe", 9)
	gs.run.day = 7
	gs.begin_day()
	var mine: Claim = gs.claims_today[gs.claims_today.size() - 1]
	gs.decide(mine, false, "R-05")
	t.ok(_stat(Endings.build(gs.run, gs.run.ending), "Your own claim").begins_with("Denied (R-05)"), "from today's decisions")


func test_benefits_denied_and_your_share() -> void:
	var run := _run(7)
	run.stats["earned"] = 480
	run.stats["saved"] = 480000
	var page := Endings.build(run, Endings.PROMOTED)
	t.eq(_stat(page, "Benefits denied"), "$480,000")
	t.eq(_stat(page, "Your share"), "0.1%")
	t.eq(Endings.share_text(300, 500000), "0.06%", "small shares keep a digit")
	t.eq(Endings.share_text(5000, 100000), "5.0%")
	t.eq(Endings.share_text(-20, 5000), "0%", "nothing earned")
	t.eq(Endings.share_text(200, 0), "-", "nothing denied")
	t.eq(_stat(Endings.build(_run(7), Endings.FIRED), "Benefits denied"), "$0", "an old run without the stat")


# --- documents -------------------------------------------------------------

func test_every_ending_hands_over_a_document() -> void:
	t.eq(Endings.ALL.size(), 7, "seven endings on file")
	var run := _run(7)
	for id: String in Endings.ALL:
		var page := Endings.build(run, id)
		t.ok(page.has("document"), "%s has a document" % id)
		t.eq(String(page.get("document", {}).get("kind", "")), DOCUMENT_KINDS[id], "%s document kind" % id)
	t.ok(not Endings.build(run, "").has("document"), "no ending, no document")


func test_fired_statement_is_the_real_bill() -> void:
	var run := _run(7)
	var bill := ClaimGenerator.new(run.run_seed, run.player_name).make_player_claim(7)
	var page := Endings.build(run, Endings.FIRED)
	var doc: Dictionary = page["document"]
	t.eq(doc["balance"], bill.amount, "balance due is the bill's total")
	t.eq((doc["lines"] as Array).size(), bill.bill_lines.size(), "every line itemized")
	t.eq(doc["provider"], "Harbor Point Medical Center")
	t.eq(doc["stamp"], "RESCINDED", "the stamp's big word")
	t.eq(doc["stamp_code"], "COVERAGE", "over its code: COVERAGE RESCINDED")
	t.ok(JSON.stringify(page["epilogue"]).contains(Fmt.money(bill.amount)), "the epilogue quotes the same bill")


func test_evicted_notice_says_what_you_were_short() -> void:
	gs.new_run("Pat Doe", 42)
	# Nobody seen today: the night has the savings plus base pay, $12 in all.
	gs.run.savings = 12 - Economy.BASE_PAY
	gs.begin_day()
	gs.close_shift()
	t.eq(gs.apply_ledger({"food": true, "heat": true, "medicine": {}}), Endings.EVICTED)
	var available: int = gs.run.today["ledger"]["available"]
	var doc: Dictionary = Endings.build(gs.run, Endings.EVICTED)["document"]
	if available > 0 and available < Economy.RENT:
		t.eq(doc["amount"], Economy.RENT - available, "rent minus that night's available ($%d)" % available)
	t.eq(doc["amount"], Endings.rent_past_due(available))
	t.eq(doc["title"], "NOTICE TO VACATE - UNIT 4B, 1120 CALLOWAY ST.")
	t.ok(int(Endings.build(_run(3), Endings.EVICTED)["document"]["amount"]) > 0, "positive even without a ledger")
	t.eq(Endings.rent_past_due(10), Economy.RENT - 10, "short $15 of a $25 rent")
	t.eq(Endings.rent_past_due(0), Economy.RENT, "nothing toward it: the whole rent")
	t.eq(Endings.rent_past_due(-15), Economy.RENT, "a night in the red still owes one week's rent, not more")
	t.eq(Endings.rent_past_due(-380), Economy.RENT)
	t.eq(Endings.rent_past_due(Economy.RENT - 1), 1)
	for available_tonight in range(-500, Economy.RENT + 5, 7):
		var due := Endings.rent_past_due(available_tonight)
		t.ok(due >= 1 and due <= Economy.RENT, "between $1 and the rent: $%d with $%d available" % [due, available_tonight])


func test_documents_carry_their_text() -> void:
	var run := _run(7)
	var promoted: Dictionary = Endings.build(run, Endings.PROMOTED)["document"]
	t.eq(promoted["to"], "Adjuster #4472, Desk 11")
	t.eq(promoted["from"], "Pat Doe, Regional Director, Claims Integrity")
	t.eq(promoted["date"], "03/09/2026")
	t.eq(promoted["subject"], "Welcome to Claims Integrity (R-01)")
	t.eq(promoted["signature"], "Pat Doe", "signed with your name")
	t.ok((promoted["paragraphs"] as PackedStringArray).has("Effective today, the denial target is 80%."))
	t.ok((promoted["paragraphs"] as PackedStringArray).has("Rent is due tonight. We care.*"))
	var scapegoat: Dictionary = Endings.build(run, Endings.SCAPEGOATED)["document"]
	var text := " ".join(scapegoat["paragraphs"])
	t.eq(scapegoat["to"], "Adjuster #4472, Desk 11")
	t.ok(String(scapegoat["from"]).begins_with("R. Hargrove"), scapegoat["from"])
	t.ok(text.contains("Your predecessor at Desk 11 is no longer with the Company. Their decisions did not reflect our values."), text)
	t.ok(text.contains("Your denial target is 77%."), text)
	var plaque: Dictionary = Endings.build(run, Endings.EMPLOYEE_OF_MONTH)["document"]
	t.eq(plaque["title"], "EMPLOYEE OF THE MONTH - MARCH 2026")
	t.eq(plaque["engraving"], "Accuracy is a form of compassion.")
	t.eq(plaque["note"], "Plaque charged to Desk 11 supplies.\n-Facilities")
	t.eq(plaque["photo_seed"], hash("Pat Doe"))
	var note: Dictionary = Endings.build(run, Endings.TAKEN_CARE_OF)["document"]
	t.ok(note["claim"] is Claim and String((note["claim"] as Claim).name).ends_with(" Hargrove"), "Monday's claim is one of R.H.'s")
	t.eq(note["note"], "Handle this one personally.\n-R.H.")


func test_mondays_claim_always_has_grounds_for_denial() -> void:
	# Seeds 107 and 119 once lost their only grounds (a name mismatch) to the
	# rename; every seed here must keep some.
	for s in range(100, 160):
		var run := RunState.create("Pat Doe", s)
		run.day = 7
		var c: Claim = Endings.build(run, Endings.TAKEN_CARE_OF)["document"]["claim"]
		t.ok(c.name.ends_with(" Hargrove") and c.card_name == c.name, "seed %d: one of R.H.'s people, on the claim and the card: %s" % [s, c.name])
		t.ok(RuleChecker.has_valid_reason(c, 6), "seed %d: %s's claim can still be denied" % [s, c.name])
		t.ok(not c.is_player and c.scripted_id == "", "seed %d: an ordinary member" % s)


# --- faces in print --------------------------------------------------------

func test_ending_photos() -> void:
	var run := _run(7)
	var player_claim := ClaimGenerator.new(run.run_seed, run.player_name).make_player_claim(7)
	for id: String in [Endings.SCAPEGOATED, Endings.FIRED, Endings.EMPLOYEE_OF_MONTH, Endings.PROMOTED]:
		var photo: Dictionary = Endings.build(run, id)["photo"]
		t.eq(photo["seed"], player_claim.portrait_seed, "%s: the player's own face" % id)
		t.eq(photo["age"], Scripted.PLAYER["age"], "%s: aged 41" % id)
	t.ok(not Endings.build(run, Endings.EVICTED).has("photo"), "eviction runs no photo")
	t.eq(Endings.build(run, Endings.EMPLOYEE_OF_MONTH)["photo"]["frame"], "brass")
	t.eq(Endings.build(run, Endings.SCAPEGOATED)["photo"]["caption"], "Pat Doe, in a company ID photo.")
	t.eq(Endings.build(run, Endings.PROMOTED)["photo"]["outfit"], "suit")
	var fired: Dictionary = Endings.build(run, Endings.FIRED)["photo"]
	t.eq(fired["outfit"], "gown")
	t.ok(String(fired["caption"]).contains("leaving Harbor Point Medical Center"), fired["caption"])
	var dale: Claim
	for c in ClaimGenerator.new(run.run_seed, run.player_name).generate_day(3):
		if c.scripted_id == "dale":
			dale = c
	t.eq(Endings.build(run, Endings.COVERED)["photo"]["seed"], dale.portrait_seed, "Dale's own face")
	t.ok(Endings.build(run, Endings.TAKEN_CARE_OF).has("photo"), "the Regional Director's headshot")


func test_news_photo_prints_three_tones_on_every_skin_tone() -> void:
	var photos: Array[NewsPhoto] = []
	for i in Palette.SKIN_TONES.size():
		var s := _seed_for_skin(i)
		t.ok(s >= 0, "found a seed for skin tone %d" % i)
		var photo := NewsPhoto.halftone(s, 40, 2)
		t.eq(photo.custom_minimum_size, Vector2(80, 96), "block 2 prints 80x96")
		t.eq(photo._skin, Palette.SKIN_TONES[i], "skin tone %d" % i)
		tree.root.add_child(photo)
		t.eq(photo.size, Vector2(80, 96), "and sizes itself to it")
		photos.append(photo)
	await tree.process_frame
	await tree.process_frame
	for i in photos.size():
		var used := photos[i].tones_used()
		t.ok(used.size() >= 3, "skin tone %d prints in %d tones" % [i, used.size()])
		for tone in used:
			t.ok(NewsPhoto.PRINT_TONES.has(tone), "only newsprint tones")
		t.eq(photos[i]._np_tones[0], NewsPhoto.PRINT_PAPER_TONE, "the wall drops out to paper")
		photos[i].queue_free()
	var big := NewsPhoto.halftone(1, 50, 3)
	tree.root.add_child(big)
	t.eq(big.size, Vector2(120, 144), "block 3 prints 120x144")
	big.queue_free()


func test_dark_skin_keeps_its_features_in_print() -> void:
	var photos: Array[NewsPhoto] = []
	for i in Palette.SKIN_TONES.size():
		var s := _seed_for_skin(i, true)
		t.ok(s >= 0, "a face with skin tone %d and dark brows" % i)
		var photo := NewsPhoto.halftone(s, 40, 2)
		tree.root.add_child(photo)
		photos.append(photo)
	await tree.process_frame
	await tree.process_frame
	var skin_means: Array[float] = []
	for i in photos.size():
		var p := photos[i]
		var skin := _printed(p, p._skin)
		t.ok(skin["count"] > 50, "skin tone %d: the face printed" % i)
		skin_means.append(skin["mean"])
		var features := {
			"brows": _printed(p, p._brow_col),
			"mouth": _printed(p, p._skin.darkened(0.55)),
			"lids": _printed(p, p._skin.darkened(0.34)),
		}
		for feature: String in features:
			var printed: Dictionary = features[feature]
			t.ok(printed["count"] > 0, "skin tone %d: the %s printed" % [i, feature])
			# Even where neither is a solid tone, the skin's dominant tone is
			# lighter than the feature's (ties counted against the test).
			if feature != "lids":
				t.ok(_dominant(skin, true) > _dominant(printed, false), "skin tone %d: %s print darker than the skin: %s vs %s" % [i, feature, printed["counts"], skin["counts"]])
			t.ok(skin["mean"] - printed["mean"] >= 0.5, "skin tone %d: %s at least half a tone darker: %.2f vs %.2f" % [i, feature, printed["mean"], skin["mean"]])
		p.queue_free()
	for i in range(1, skin_means.size()):
		t.ok(skin_means[i] < skin_means[i - 1] - 0.1, "a darker skin still prints darker: tone %d at %.2f, tone %d at %.2f" % [i, skin_means[i], i - 1, skin_means[i - 1]])
	t.ok(skin_means[0] <= 2.5, "the lightest face is not blank paper: %.2f" % skin_means[0])
	t.ok(skin_means[skin_means.size() - 1] >= 1.0, "the darkest face is not solid ink: %.2f" % skin_means[skin_means.size() - 1])


func test_print_levels_anchor_on_the_skin() -> void:
	var skin := 0.4
	var level := NewsPhoto.print_skin_level(skin)
	t.near(NewsPhoto.print_level(skin, 0.05, 0.8, skin, level), level, 0.0001, "the skin prints at its level")
	t.near(NewsPhoto.print_level(0.8, 0.05, 0.8, skin, level), 3.0, 0.0001, "the lightest color prints as paper")
	t.near(NewsPhoto.print_level(0.05, 0.05, 0.8, skin, level), 0.0, 0.0001, "the darkest as ink")
	var shading := NewsPhoto.print_level(skin * 0.88, 0.05, 0.8, skin, level)
	t.ok(shading < level and shading >= level - NewsPhoto.PRINT_SHADING_DROP, "the face's own shading sits just below the skin: %.2f" % shading)
	var feature := NewsPhoto.print_level(skin * 0.75, 0.05, 0.8, skin, level)
	t.ok(feature <= level - 1.0, "a feature prints a full tone below it: %.2f vs %.2f" % [feature, level])
	t.near(NewsPhoto.print_skin_level(Palette.SKIN_TONES[5].get_luminance()), NewsPhoto.PRINT_SKIN_DARK, 0.0001)
	t.near(NewsPhoto.print_skin_level(Palette.SKIN_TONES[0].get_luminance()), NewsPhoto.PRINT_SKIN_LIGHT, 0.0001)


func test_news_photo_drops_a_translucent_shadow_to_paper() -> void:
	var photo := NewsPhoto.new(2)
	photo._np_cells.resize(PortraitView.GRID_W * PortraitView.GRID_H)
	photo._np_figure.resize(photo._np_cells.size())
	photo._np_figure.fill(0)
	photo._np_recording = true
	photo._b(0, 0, 4, 4, Color(0, 0, 0, 0.22))
	t.eq(photo._np_figure.count(1), 0, "a shadow on bare paper stays paper")
	photo._b(0, 0, 2, 2, Palette.WALL.darkened(0.2))
	t.eq(photo._np_figure.count(1), 0, "so does the wall's own shadow")
	photo._b(0, 0, 2, 2, Palette.SKIN_TONES[2])
	t.eq(photo._np_figure.count(1), 4, "skin is figure")
	photo._b(0, 0, 1, 1, Color(1, 1, 1, 0.16))
	t.ok(photo._np_cells[0] != Palette.SKIN_TONES[2], "a lens tints the face under it")
	photo._np_recording = false
	photo.free()


func test_a_seeded_obituary_prints_a_photo() -> void:
	gs.new_run("Pat Doe", 5)
	var items: Array = [
		{"headline": "Obituaries", "body": "Ana Lee, 71, died Tuesday of a stroke.", "portrait_seed": 77, "age": 71},
		{"headline": "BMH +1.0%", "body": "Shares rose."},
	]
	var with_photo := NewspaperScreen.new()
	with_photo.paper = {"date": "Wednesday, March 4, 2026", "lead": {"headline": "Lead", "sub": "Sub"}, "items": items}
	await _open(with_photo)
	t.eq(with_photo.photos.size(), 1, "one face printed")
	t.eq(with_photo.photos[0].size, Vector2(80, 96))
	t.eq(_count(with_photo, "NewsPhoto"), 1)
	var plain := NewspaperScreen.new()
	plain.paper = {"date": "Wednesday, March 4, 2026", "lead": {"headline": "Lead", "sub": "Sub"}, "items": [items[1]]}
	await _open(plain)
	t.eq(plain.photos.size(), 0, "no seed, no photo")
	t.eq(_count(plain, "NewsPhoto"), 0)
	var lead := NewspaperScreen.new()
	lead.paper = {"date": "Tuesday, March 3, 2026", "lead": {"headline": "Man dies", "sub": "Sub", "portrait_seed": 5, "age": 58}, "items": [items[1]]}
	await _open(lead)
	t.eq(lead.photos.size(), 1, "the lead's photo")
	t.eq(lead.photos[0].size, Vector2(120, 144), "printed bigger")


# --- day 7's favors --------------------------------------------------------

func test_favors_decide_the_approved_ending() -> void:
	var run := _run(7)
	t.eq(Endings.resolve_final(run, true), Endings.FIRED, "nobody owes you")
	run.scripted_outcomes["dale"] = "approved"
	t.eq(Endings.resolve_final(run, true), Endings.COVERED, "Dale covers")
	run.scripted_outcomes["eleanor"] = "approved"
	t.eq(Endings.resolve_final(run, true), Endings.TAKEN_CARE_OF, "R.H. outranks Dale")
	run.scripted_outcomes.erase("dale")
	t.eq(Endings.resolve_final(run, true), Endings.TAKEN_CARE_OF, "R.H. alone")
	run.scripted_outcomes["eleanor"] = "denied"
	t.eq(Endings.resolve_final(run, true), Endings.FIRED, "a denied Eleanor owes you nothing")


func test_full_discontent_scapegoats_whatever_was_owed() -> void:
	for outcomes: Dictionary in [{}, {"dale": "approved"}, {"eleanor": "approved"}, {"eleanor": "approved", "dale": "approved"}]:
		var run := _run(7)
		run.discontent = 100.0
		run.scripted_outcomes = outcomes.duplicate()
		for approve: bool in [true, false]:
			t.eq(Endings.resolve_final(run, approve), Endings.SCAPEGOATED, "%s approve=%s" % [outcomes, approve])


func test_denying_with_a_note_keeps_the_ending_and_adds_a_line() -> void:
	var run := _run(7)
	run.stats["processed"] = 40
	run.stats["denied"] = 10
	run.scripted_outcomes["eleanor"] = "approved"
	t.eq(Endings.resolve_final(run, false), Endings.EMPLOYEE_OF_MONTH)
	t.ok((Endings.build(run, Endings.EMPLOYEE_OF_MONTH)["epilogue"] as PackedStringArray).has("R.H. sent flowers."))
	run.stats["denied"] = 30
	t.eq(Endings.resolve_final(run, false), Endings.PROMOTED)
	t.ok((Endings.build(run, Endings.PROMOTED)["epilogue"] as PackedStringArray).has("R.H. sent flowers."))
	run.scripted_outcomes = {"dale": "approved"}
	t.ok((Endings.build(run, Endings.PROMOTED)["epilogue"] as PackedStringArray).has("Dale said he would have taken it."))
	run.scripted_outcomes = {}
	var plain: PackedStringArray = Endings.build(run, Endings.PROMOTED)["epilogue"]
	t.ok(not plain.has("R.H. sent flowers.") and not plain.has("Dale said he would have taken it."), "no favor, no line")


func test_the_new_endings_have_pages() -> void:
	var run := _run(7)
	run.scripted_outcomes = {"eleanor": "approved", "dale": "approved"}
	var care := Endings.build(run, Endings.TAKEN_CARE_OF)
	t.eq(care["paper"]["headline"], "Benevolence Mutual reports record quarter")
	t.ok((care["epilogue"] as PackedStringArray).has("Your claim was approved at the Regional Director's discretion. Nobody mentioned it again."))
	t.ok((care["epilogue"] as PackedStringArray).has("On Monday your first claim had a sticky note on it: Handle this one personally. -R.H."))
	var covered := Endings.build(run, Endings.COVERED)
	for line in ["Dale Pruitt approved your claim at Desk 12.", "On Tuesday a memo reminded all staff that favoritism toward colleagues is grounds for termination.", "Dale cleared out his desk on Wednesday. He said you would have done the same."]:
		t.ok((covered["epilogue"] as PackedStringArray).has(line), line)
	for page: Dictionary in [care, covered]:
		t.eq((page["follow_ups"] as PackedStringArray).size(), 2, "%s follow-ups" % page["id"])
		t.ok(page["survived"], "%s: you live" % page["id"])


func test_begin_day_sets_the_favor_note_only_on_day_7_for_the_players_claim() -> void:
	gs.new_run("Pat Doe", 5)
	for setup: Array in [[{"eleanor": "approved"}, Endings.RH_NOTE], [{"eleanor": "approved", "dale": "approved"}, Endings.RH_NOTE], [{"dale": "approved"}, Endings.DALE_NOTE], [{"eleanor": "denied", "dale": "denied"}, ""]]:
		gs.run.scripted_outcomes = (setup[0] as Dictionary).duplicate()
		for day in [4, 6, 7]:
			gs.run.day = day
			gs.begin_day()
			for c: Claim in gs.claims_today:
				var favor := c.sticky_note == Endings.RH_NOTE or c.sticky_note == Endings.DALE_NOTE
				if day == 7 and c.is_player:
					t.eq(c.sticky_note, setup[1], "%s: the player's claim" % [setup[0]])
				else:
					t.ok(not favor, "day %d %s: no favor note on %s" % [day, setup[0], c.name])
				if c.scripted_id == "eleanor":
					t.eq(c.sticky_note, "Handle this one personally.\n-R.H.", "Eleanor keeps her own note")


# --- the paged ending screen -----------------------------------------------

func test_ending_screen_pages_through_to_the_title() -> void:
	gs.new_run("Pat Doe", 9)
	gs.run.day = 7
	gs.begin_day()
	gs.decide(gs.claims_today[gs.claims_today.size() - 1], false, "R-05")
	var ending := EndingScreen.new()
	await _open(ending)
	var payloads: Array = []
	ending.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	t.eq(ending.pages.size(), 3, "front page, inside page, document: all built in fast mode")
	t.ok(ending.pages[0].visible and not ending.pages[1].visible and not ending.pages[2].visible, "page 1 first")
	t.eq(ending._back.text, "NEXT PAGE")
	t.eq(ending._back.focus_mode, Control.FOCUS_ALL, "NEXT PAGE takes focus")
	t.ok(not ending._retry.visible, "no retry before the last page")
	ending._advance()
	t.ok(ending.pages[1].visible and not ending.pages[0].visible, "page 2")
	t.ok(_texts(ending.pages[1]).has("ALSO IN TODAY'S LEDGER"), "the inside page")
	ending._advance()
	t.ok(ending.pages[2].visible, "the document")
	t.eq(ending._back.text, "RETURN TO TITLE")
	t.ok(ending._retry.visible, "a retry is offered")
	t.eq(ending._retry.text, "RETRY DAY 7 (SUNDAY MORNING)")
	t.eq(ending._record.text, "OUTCOME 1 OF 7 ON FILE")
	t.ok(payloads.is_empty(), "paging never finishes the screen")
	ending._retry.pressed.emit()
	t.eq(payloads, [{"action": "retry", "day": 7}], "retry finishes with the day")


func test_return_to_title_finishes_plainly() -> void:
	gs.new_run("Pat Doe", 9)
	gs.run.ending = Endings.EVICTED
	var ending := EndingScreen.new()
	await _open(ending)
	var payloads: Array = []
	ending.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	ending._advance()
	ending._advance()
	t.ok(not ending._retry.visible, "nothing to retry without a retry file")
	ending._back.pressed.emit()
	t.eq(payloads, [{}])


func test_every_ending_screen_prints_its_photo_and_document() -> void:
	gs.new_run("Pat Doe", 9)
	var bill := ClaimGenerator.new(9, "Pat Doe").make_player_claim(7)
	var expect := {
		Endings.SCAPEGOATED: ["Pat Doe, in a company ID photo.", "Your denial target is 77%."],
		Endings.EVICTED: ["NOTICE TO VACATE - UNIT 4B, 1120 CALLOWAY ST."],
		Endings.FIRED: ["BALANCE DUE: %s" % Fmt.money(bill.amount)],
		Endings.EMPLOYEE_OF_MONTH: ["EMPLOYEE OF THE MONTH - MARCH 2026", "Accuracy is a form of compassion.", "Plaque charged to Desk 11 supplies.\n-Facilities"],
		Endings.PROMOTED: ["Effective today, the denial target is 80%.", "Pat Doe, Regional Director, Claims Integrity"],
		Endings.TAKEN_CARE_OF: ["R. Hargrove, Regional Director, Claims Integrity."],
		Endings.COVERED: ["Favoritism toward colleagues", "Dale Pruitt, in a company ID photo."],
	}
	for id: String in Endings.ALL:
		gs.run.ending = id
		var ending := EndingScreen.new()
		await _open(ending)
		var texts := _texts(ending)
		for text: String in expect[id]:
			t.ok(texts.has(text), "%s shows \"%s\"" % [id, text])
		var front_photos := _count(ending.pages[0], "NewsPhoto")
		t.eq(front_photos, 0 if id == Endings.EVICTED else 1, "%s front-page photo" % id)
	gs.run.ending = Endings.TAKEN_CARE_OF
	var care := EndingScreen.new()
	await _open(care)
	t.eq(_count(care.pages[2], "DocumentView"), 2, "Monday's claim form and R.H.'s note")
	t.ok(_texts(care.pages[2]).has("Handle this one personally.\n-R.H."))


## The canvas-space box around `c`, turned or not.
func _box(c: Control) -> Rect2:
	var xf := c.get_global_transform()
	var box := Rect2(xf * Vector2.ZERO, Vector2.ZERO)
	for corner: Vector2 in [Vector2(c.size.x, 0), c.size, Vector2(0, c.size.y)]:
		box = box.expand(xf * corner)
	return box


## The canvas-space box around the text a one-line Label actually draws.
func _text_box(l: Label) -> Rect2:
	var font := l.get_theme_font("font")
	var width := minf(font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x, l.size.x)
	var x := 0.0
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = (l.size.x - width) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = l.size.x - width
	var xf := l.get_global_transform()
	return Rect2(xf * Vector2(x, 0), Vector2(width, l.size.y))


func test_the_last_documents_read_as_written() -> void:
	gs.new_run("Pat Doe", 9)
	gs.run.ending = Endings.FIRED
	var fired := EndingScreen.new()
	await _open(fired)
	t.ok(fired.stamp != null and fired.pages[2].is_ancestor_of(fired.stamp), "Harbor Point's statement is stamped")
	t.eq(fired.stamp.word, "RESCINDED", "RESCINDED in big type")
	t.eq(fired.stamp.code, "COVERAGE", "over COVERAGE")
	t.ok(fired.stamp.word != "DENIED", "the hospital's statement never says DENIED")
	gs.run.ending = Endings.TAKEN_CARE_OF
	var care := EndingScreen.new()
	await _open(care)
	care._advance()
	care._advance()
	await tree.process_frame
	await tree.process_frame
	var note := _box(care.claim_note)
	var form := _box(care.claim_form)
	t.ok(note.intersects(form), "R.H.'s note is stuck on Monday's claim")
	t.ok(note.end.x > form.end.x and note.position.y < form.position.y, "on its top-right corner, above and past it")
	var checked := 0
	for l in _labels(care.claim_form):
		if l.text.strip_edges() == "":
			continue
		checked += 1
		t.ok(not note.intersects(_text_box(l)), "the note leaves \"%s\" readable" % l.text)
	t.ok(checked >= 10, "checked the header and every field: %d" % checked)
	t.ok(Rect2(Vector2.ZERO, Vector2(1920, 1080 - EndingScreen.BAR_H)).encloses(note.merge(form)), "and both fit above the buttons")
