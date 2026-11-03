extends RefCounted

var t: TestContext


func _fingerprint(claims: Array[Claim]) -> String:
	var parts: PackedStringArray = []
	for c in claims:
		parts.append("%s|%s|%d|%d" % [c.claim_no, c.name, c.amount, c.portrait_seed])
	return ",".join(parts)


func test_deterministic_by_seed() -> void:
	var a := ClaimGenerator.new(1234, "Pat Doe")
	var b := ClaimGenerator.new(1234, "Pat Doe")
	var c := ClaimGenerator.new(9999, "Pat Doe")
	for day in range(1, 8):
		t.eq(_fingerprint(a.generate_day(day)), _fingerprint(b.generate_day(day)), "day %d" % day)
	t.ok(_fingerprint(a.generate_day(3)) != _fingerprint(c.generate_day(3)), "different seeds differ")


func test_patient_counts_per_day() -> void:
	var gen := ClaimGenerator.new(7, "Pat Doe")
	var expected := [5, 6, 7, 7, 8, 8, 8]
	for day in range(1, 8):
		t.eq(gen.generate_day(day).size(), expected[day - 1], "day %d" % day)


func test_violation_share_near_target() -> void:
	var gen := ClaimGenerator.new(42, "Pat Doe")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for day in range(1, 8):
		var hits := 0
		var n := 2000
		for i in n:
			if RuleChecker.has_valid_reason(gen.random_claim(day, rng), day):
				hits += 1
		var share := float(hits) / n
		t.near(share, ClaimGenerator.VIOLATION_TARGET[day - 1], 0.05, "day %d share" % day)


func test_random_claims_only_break_unlocked_rules() -> void:
	var gen := ClaimGenerator.new(5, "Pat Doe")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for day in range(1, 8):
		var unlocked := Rules.unlocked(day)
		for i in 400:
			var c := gen.random_claim(day, rng)
			for v in RuleChecker.violations(c, 7):
				t.ok(unlocked.has(v["rule"]), "day %d claim breaks locked %s" % [day, v["rule"]])


func test_at_most_one_rule_broken_per_random_claim() -> void:
	var gen := ClaimGenerator.new(6, "Pat Doe")
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for i in 600:
		var c := gen.random_claim(7, rng)
		var rules := {}
		for v in RuleChecker.violations(c, 7):
			rules[v["rule"]] = true
		t.ok(rules.size() <= 1, "claim %s breaks %s" % [c.claim_no, rules.keys()])


## The history shows full dates, so a same-condition entry must never share
## MEMBER SINCE's date: every pre-existing call is decidable from the paper.
func test_history_dates_never_tie_member_since() -> void:
	var gen := ClaimGenerator.new(31, "Pat Doe")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 3000:
		var c := gen.random_claim(5 + i % 3, rng)
		for entry: Dictionary in c.history:
			if entry["condition"] == c.condition:
				t.ok(DateUtil.fmt(int(entry["date"])) != DateUtil.fmt(c.member_since), "%s: %s ties member since" % [c.claim_no, entry["label"]])


func test_bill_totals_match_amount() -> void:
	var gen := ClaimGenerator.new(11, "Pat Doe")
	for day in range(1, 8):
		for c in gen.generate_day(day):
			t.eq(c.bill_total(), c.amount, c.claim_no)
			t.ok(c.bill_lines.size() >= 2 and c.bill_lines.size() <= 5, "%s line count" % c.claim_no)


func test_dob_matches_age() -> void:
	var gen := ClaimGenerator.new(12, "Pat Doe")
	for day in range(1, 8):
		for c in gen.generate_day(day):
			t.eq(DateUtil.age_on(c.card_dob, DateUtil.game_date(day)), c.age, c.claim_no)
			t.ok(c.member_since > c.card_dob, "%s enrolled after birth" % c.claim_no)
			t.ok(c.date_of_service < DateUtil.game_date(day), "%s service in the past" % c.claim_no)


func test_children_have_parent_voice() -> void:
	var gen := ClaimGenerator.new(13, "Pat Doe")
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var children := 0
	for i in 500:
		var c := gen.random_claim(5, rng)
		t.eq(c.parent_speaks, c.is_child(), c.claim_no)
		if c.is_child():
			children += 1
	t.ok(children > 20 and children < 120, "children: %d" % children)


func test_scripted_case_in_slot_and_valid() -> void:
	var gen := ClaimGenerator.new(14, "Pat Doe")
	var expected_ids := ["walt", "lily", "dale", "eleanor", "priya", "marcus"]
	for day in range(1, 7):
		var case_data := Scripted.for_day(day)
		t.eq(case_data["id"], expected_ids[day - 1])
		var c: Claim = gen.generate_day(day)[case_data["slot"]]
		t.eq(c.scripted_id, case_data["id"], "day %d slot" % day)
		var rules: Array[String] = []
		for v in RuleChecker.violations(c, day):
			rules.append(v["rule"])
		t.eq(rules, [Rules.new_rule_on(day)["id"]] as Array[String], "%s breaks exactly the new rule" % c.scripted_id)


func test_eleanor_is_exempt_with_note() -> void:
	var gen := ClaimGenerator.new(15, "Pat Doe")
	var c: Claim = gen.generate_day(4)[Scripted.for_day(4)["slot"]]
	t.ok(c.exempt_from_citation)
	t.ok(c.sticky_note.contains("R.H."))


func test_player_claim_last_on_day_seven() -> void:
	var gen := ClaimGenerator.new(16, "Pat Doe")
	var claims := gen.generate_day(7)
	var mine: Claim = claims[claims.size() - 1]
	t.ok(mine.is_player)
	t.eq(mine.name, "Pat Doe")
	t.eq(mine.card_name, "Pat Doe")
	t.ok(mine.amount >= 50000, "amount %d" % mine.amount)
	var rules: Array[String] = []
	for v in RuleChecker.violations(mine, 7):
		rules.append(v["rule"])
	t.ok(rules.has("R-02"), "out of network")
	t.ok(rules.has("R-05"), "pre-existing")
	for c in claims:
		if c != mine:
			t.ok(not c.is_player)
