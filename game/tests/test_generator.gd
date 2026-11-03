extends RefCounted

var t: TestContext

## Lines only a hospital (or the cancer institute, or an orthopedic surgeon) bills.
const HOSPITAL_LEVEL: PackedStringArray = [
	"er_visit", "icu_stay", "inpatient_stay", "observation", "appendectomy", "acl_surgery",
	"hip_replacement", "gallbladder", "cardiac_cath", "stent", "stroke_tpa", "dialysis", "chemo", "radiation",
]
const CLINICS: PackedStringArray = ["Northgate Family Clinic", "Harborview Urgent Care", "Elm Street Pediatrics"]


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


## A pre-existing record needs a patient old enough to have one and a clear gap
## before enrollment: no "diagnosed at four weeks old", no "the day before".
func test_pre_existing_records_are_plausibly_dated() -> void:
	var gen := ClaimGenerator.new(41, "Pat Doe")
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var planted := 0
	var children := 0
	for i in 6000:
		var c := gen.random_claim(5 + i % 3, rng)
		t.ok(c.member_since <= c.date_of_service - 20, "%s enrolled %d days before service" % [c.claim_no, c.date_of_service - c.member_since])
		for entry: Dictionary in c.history:
			var when := int(entry["date"])
			if entry["condition"] != c.condition or when >= c.member_since:
				continue
			planted += 1
			if c.is_child():
				children += 1
			t.ok(when >= c.card_dob + 365, "%s: %s on record at %d days old" % [c.claim_no, entry["label"], when - c.card_dob])
			t.ok(when <= c.member_since - 30, "%s: %s on record %d days before member since" % [c.claim_no, entry["label"], c.member_since - when])
	t.ok(planted > 500, "pre-existing records checked: %d" % planted)
	t.ok(children > 10, "children's pre-existing records checked: %d" % children)


## Nothing in a history predates the patient's first birthday or postdates today:
## filler respects each entry's min_age, and decoys follow the same rule.
func test_history_entries_fit_the_patients_age() -> void:
	var gen := ClaimGenerator.new(43, "Pat Doe")
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var min_age := {}
	for entry: Dictionary in Medical.FILLER_HISTORY:
		min_age[entry["condition"]] = int(entry["min_age"])
	for i in 3000:
		var c := gen.random_claim(5 + i % 3, rng)
		t.ok(not c.history.is_empty(), "%s has a medical history" % c.claim_no)
		for entry: Dictionary in c.history:
			var when := int(entry["date"])
			var years := int(min_age.get(entry["condition"], 1))
			t.ok(when >= c.card_dob + years * 365, "%s: %s at %d days old" % [c.claim_no, entry["label"], when - c.card_dob])
			t.ok(when < DateUtil.game_date(c.day), "%s: %s dated in the future" % [c.claim_no, entry["label"]])


func test_claim_numbers_unique_within_a_day() -> void:
	var repeats: PackedStringArray = []
	for seed_value in 400:
		var gen := ClaimGenerator.new(seed_value, "Pat Doe")
		for day in range(1, 8):
			var seen := {}
			for c in gen.generate_day(day):
				if seen.has(c.claim_no):
					repeats.append("seed %d day %d %s" % [seed_value, day, c.claim_no])
				seen[c.claim_no] = true
	t.eq(repeats.size(), 0, ", ".join(repeats))


## A family clinic, urgent care or pediatric office doesn't bill an ER visit, a
## surgery, an ICU stay, chemo or dialysis.
func test_providers_bill_what_they_can_provide() -> void:
	var gen := ClaimGenerator.new(51, "Pat Doe")
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var seen := {}
	for i in 4000:
		var c := gen.random_claim(1 + i % 7, rng)
		seen[c.provider] = true
		var billed: Array[String] = []
		for line in c.bill_lines:
			billed.append(line["id"])
		if CLINICS.has(c.provider):
			for proc_id in billed:
				t.ok(not HOSPITAL_LEVEL.has(proc_id), "%s: %s bills %s" % [c.claim_no, c.provider, proc_id])
		if c.provider == "Elm Street Pediatrics":
			t.ok(c.is_child(), "%s: pediatrics treating a %d-year-old" % [c.claim_no, c.age])
		if not Medical.is_in_network(c.provider):
			t.ok(c.provider != "University Children's Hospital" or c.is_child(), "%s: adult at the children's hospital" % c.claim_no)
			continue
		if billed.has("oncology_consult"):
			t.eq(c.provider, "Westbrook Cancer Institute", "%s: cancer care" % c.claim_no)
		elif ClaimGenerator.ORTHO_DIAGNOSES.has(c.diagnosis_id) and not billed.has("er_visit"):
			t.eq(c.provider, "Lakeside Orthopedics", "%s: orthopedics without an ER visit" % c.claim_no)
	for p: String in ["Northgate Family Clinic", "Harborview Urgent Care", "Elm Street Pediatrics", "Lakeside Orthopedics", "Westbrook Cancer Institute"]:
		t.ok(seen.has(p), "nobody went to %s" % p)
	var hospitals := 0
	for h in ClaimGenerator.HOSPITALS:
		if seen.has(h):
			hospitals += 1
	t.eq(hospitals, ClaimGenerator.HOSPITALS.size(), "every hospital sees patients")


func test_claims_record_their_diagnosis_id() -> void:
	var gen := ClaimGenerator.new(21, "Pat Doe")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var non_fatal := 0
	for i in 500:
		var c := gen.random_claim(1 + i % 7, rng)
		var dx := Medical.diagnosis(c.diagnosis_id)
		t.ok(not dx.is_empty(), "%s has diagnosis id '%s'" % [c.claim_no, c.diagnosis_id])
		t.eq(c.diagnosis, dx.get("label", ""), c.claim_no)
		t.eq(c.summary()["fatal"], dx.get("fatal", true), "%s (%s)" % [c.claim_no, c.diagnosis_id])
		if not c.summary()["fatal"]:
			non_fatal += 1
	t.ok(non_fatal > 0, "some random claims are not fatal: %d" % non_fatal)
	for day in range(1, 8):
		for c in gen.generate_day(day):
			var dx := Medical.diagnosis(c.diagnosis_id)
			t.eq(dx.get("condition", ""), c.condition, "%s (%s)" % [c.claim_no, c.scripted_id])
	var claims := gen.generate_day(7)
	t.eq(claims[claims.size() - 1].diagnosis_id, Scripted.PLAYER["dx"], "player claim")


## His daughter's letter says he paid in for nineteen years; the card has to agree.
func test_walt_member_for_nineteen_years() -> void:
	var slot: int = Scripted.get_case("walt")["slot"]
	for seed_value in [1, 2, 3, 14, 2026]:
		var walt: Claim = ClaimGenerator.new(seed_value, "Pat Doe").generate_day(1)[slot]
		t.eq(walt.scripted_id, "walt")
		var years := DateUtil.age_on(walt.member_since, walt.date_of_service)
		t.ok(years >= 18 and years <= 20, "seed %d: member for %d years" % [seed_value, years])
		t.ok(walt.coverage_through < walt.date_of_service, "seed %d: still lapsed" % seed_value)


func test_marcus_is_end_stage() -> void:
	var slot: int = Scripted.get_case("marcus")["slot"]
	var marcus: Claim = ClaimGenerator.new(14, "Pat Doe").generate_day(6)[slot]
	t.eq(marcus.scripted_id, "marcus")
	t.eq(marcus.diagnosis, "Colon cancer, stage IV")
	t.eq(marcus.diagnosis_id, "colon_cancer")
	t.eq(marcus.summary()["diagnosis"], "Colon cancer, stage IV")


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
