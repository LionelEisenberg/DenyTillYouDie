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


## Everything a patient brings to the window, lines and exhibit included.
func _full_fingerprint(claims: Array[Claim]) -> String:
	var parts: PackedStringArray = []
	for c in claims:
		parts.append("%s|%s|%s|%d|%d|%s|%s|%s|%s" % [c.claim_no, c.card_name, c.name, c.amount, c.portrait_seed,
			c.arrival_line, c.reaction_approved, c.reaction_denied, str(c.exhibit)])
	return "\n".join(parts)


func _rules_of(c: Claim, day: int) -> Array[String]:
	var ids: Array[String] = []
	for v in RuleChecker.violations(c, day):
		ids.append(v["rule"])
	return ids


func _breaks(c: Claim, rule_id: String, day: int) -> bool:
	return _rules_of(c, day).has(rule_id)


func _is_random(c: Claim) -> bool:
	return c.scripted_id == "" and not c.is_player


# --- training claims and the new rule's example (item 1) -------------------

## Day 1 teaches the desk: the first patient is a plain lapse with nothing else
## to find, the second is clean, and Walt still comes third.
func test_day_one_opens_with_a_lapse_then_a_clean_claim() -> void:
	var year_end := DateUtil.from_ymd(2026, 12, 31)
	var failures: PackedStringArray = []
	for seed_value in 300:
		var claims := ClaimGenerator.new(seed_value, "Pat Doe").generate_day(1)
		var lapsed := claims[0]
		var clean := claims[1]
		var gap := lapsed.date_of_service - lapsed.coverage_through
		var problems: PackedStringArray = []
		if _rules_of(lapsed, 7) != (["R-01"] as Array[String]):
			problems.append("slot 0 breaks %s" % [_rules_of(lapsed, 7)])
		if gap < 10 or gap > 40:
			problems.append("slot 0 lapsed %d days before service" % gap)
		if not _rules_of(clean, 7).is_empty():
			problems.append("slot 1 breaks %s" % [_rules_of(clean, 7)])
		if clean.coverage_through != year_end:
			problems.append("slot 1 coverage ends %s" % DateUtil.fmt(clean.coverage_through))
		for c: Claim in [lapsed, clean]:
			if c.priority != Claim.Priority.ROUTINE or c.is_child() or not _is_random(c):
				problems.append("%s is %s, age %d, scripted '%s'" % [c.claim_no, c.priority_name(), c.age, c.scripted_id])
			# No decoys: no prior-auth procedure, no record of the claimed condition.
			if c.prior_auth != "":
				problems.append("%s carries a prior-auth decoy" % c.claim_no)
			for entry: Dictionary in c.history:
				if entry["condition"] == c.condition:
					problems.append("%s carries a history decoy" % c.claim_no)
		if claims[2].scripted_id != "walt":
			problems.append("Walt is not third")
		if not problems.is_empty():
			failures.append("seed %d: %s" % [seed_value, "; ".join(problems)])
	t.eq(failures.size(), 0, "\n".join(failures))


## Days 2-6: whenever anyone that day breaks the new rule, the first patient
## does. Nobody is regenerated: the first later patient who breaks it just
## trades places with the first, and the scripted case keeps its slot.
func test_the_new_rule_is_shown_by_the_first_patient() -> void:
	var swapped := 0
	var failures: PackedStringArray = []
	for seed_value in 300:
		var gen := ClaimGenerator.new(seed_value, "Pat Doe")
		for day in range(2, 7):
			var rule: String = Rules.new_rule_on(day)["id"]
			var claims := gen.generate_day(day)
			var case_data := Scripted.for_day(day)
			# The order they were generated in: each slot's name from the week's
			# list (names are unique, so they identify the patients).
			var by_name := {}
			for c in claims:
				by_name[c.card_name] = c
			var order: PackedStringArray = []
			var raw_order: PackedStringArray = []
			var raw: Array[Claim] = []
			for i in claims.size():
				order.append(claims[i].card_name)
				raw_order.append(case_data["name"] if i == int(case_data["slot"]) else gen.week_names()[ClaimGenerator.week_index(day, i)])
				if not by_name.has(raw_order[i]):
					failures.append("seed %d day %d: %s is missing, so someone was replaced" % [seed_value, day, raw_order[i]])
					break
				raw.append(by_name[raw_order[i]])
			if raw.size() != claims.size():
				continue
			var expected := raw_order.duplicate()
			if not _breaks(raw[0], rule, day):
				for i in range(1, raw.size()):
					if _is_random(raw[i]) and _breaks(raw[i], rule, day):
						expected[0] = raw_order[i]
						expected[i] = raw_order[0]
						swapped += 1
						break
			if order != expected:
				failures.append("seed %d day %d: order %s, expected %s" % [seed_value, day, order, expected])
			var anyone := false
			for c in claims:
				anyone = anyone or (_is_random(c) and _breaks(c, rule, day))
			if anyone and not _breaks(claims[0], rule, day):
				failures.append("seed %d day %d: first patient doesn't break %s" % [seed_value, day, rule])
			if claims[int(case_data["slot"])].scripted_id != case_data["id"]:
				failures.append("seed %d day %d: %s moved" % [seed_value, day, case_data["id"]])
	t.eq(failures.size(), 0, "\n".join(failures))
	t.ok(swapped > 100, "patients moved up: %d" % swapped)


func test_a_day_regenerates_identically() -> void:
	for seed_value in [1, 77, 2026]:
		for day in range(1, 8):
			var gen := ClaimGenerator.new(seed_value, "Pat Doe")
			t.eq(_full_fingerprint(gen.generate_day(day)), _full_fingerprint(gen.generate_day(day)), "seed %d day %d, same generator" % [seed_value, day])
			t.eq(_full_fingerprint(ClaimGenerator.new(seed_value, "Pat Doe").generate_day(day)), _full_fingerprint(gen.generate_day(day)), "seed %d day %d, new generator" % [seed_value, day])


# --- names and lines without repeats (item 5) -------------------------------

func test_no_name_repeats_in_a_week() -> void:
	var repeats: PackedStringArray = []
	for seed_value in 200:
		var gen := ClaimGenerator.new(seed_value, "Pat Doe")
		var seen := {}
		for day in range(1, 8):
			for c in gen.generate_day(day):
				if seen.has(c.card_name):
					repeats.append("seed %d day %d: %s" % [seed_value, day, c.card_name])
				seen[c.card_name] = true
	t.eq(repeats.size(), 0, ", ".join(repeats))


func test_week_names_leave_out_the_player_and_the_scripted_patients() -> void:
	var names := ClaimGenerator.new(5, "Nobody").week_names()
	t.ok(names.size() >= ClaimGenerator.week_index(8, 0), "a name for every patient: %d" % names.size())
	var firsts := {}
	for full in names:
		firsts[full.get_slice(" ", 0)] = true
	t.eq(firsts.size(), names.size(), "no first name twice")
	# A player who happens to have one of those names never meets a namesake,
	# however they typed it.
	for pair: Array in [[names[3], names[3]], ["  %s " % names[7].to_upper(), names[7]]]:
		var theirs := ClaimGenerator.new(5, pair[0]).week_names()
		t.ok(not theirs.has(pair[1]), "'%s' is left out for player '%s'" % [pair[1], pair[0]])
		t.eq(theirs.size(), names.size())
	for case_data: Dictionary in Scripted.CASES:
		for seed_value in 50:
			t.ok(not ClaimGenerator.new(seed_value, "Pat Doe").week_names().has(case_data["name"]), "seed %d: %s" % [seed_value, case_data["name"]])


## Which deck a dealt line came from, by the pools that hold it.
func _deck_of(c: Claim, line: String, kind: String) -> String:
	var voice := "parent" if c.parent_speaks else "adult"
	var tier := clampi(c.priority, 0, 2)
	if kind == "arrival":
		var template := line.replace(c.first_name(), "{child}") if c.parent_speaks else line
		if Lines.dx_pool(c.diagnosis_id, c.parent_speaks).has(template):
			return "dx:%s:%s|%s" % [c.diagnosis_id, voice, template]
		if Lines.arrival_pool(tier, c.parent_speaks).has(template):
			return "arrival:%s:%d|%s" % [voice, tier, template]
		return ""
	var pool := Lines.reaction_pool(tier, kind == "approved", c.parent_speaks)
	if not pool.has(line):
		return ""
	return ("%s:parent|%s" % [kind, line]) if c.parent_speaks else ("%s:adult:%d|%s" % [kind, tier, line])


func _pool_size(deck: String) -> int:
	var parts := deck.split(":")
	match parts[0]:
		"dx":
			return Lines.dx_pool(parts[1], parts[2] == "parent").size()
		"arrival":
			return Lines.arrival_pool(int(parts[2]), parts[1] == "parent").size()
	if parts[1] == "parent":
		return Lines.reaction_pool(0, parts[0] == "approved", true).size()
	return Lines.reaction_pool(int(parts[2]), parts[0] == "approved", false).size()


## Every random patient gets an arrival line and both reactions, dealt from
## decks: within a week a line comes round again only once its deck is used up.
func test_lines_repeat_only_after_their_deck_runs_out() -> void:
	var failures: PackedStringArray = []
	var dx_lines := 0
	var dx_eligible := 0
	for seed_value in 200:
		var gen := ClaimGenerator.new(seed_value, "Pat Doe")
		var drawn := {}
		for day in range(1, 8):
			for c in gen.generate_day(day):
				if not _is_random(c):
					t.eq(c.reaction_approved + c.reaction_denied, "", "%s keeps its own reactions" % c.scripted_id)
					continue
				for kind: String in ["arrival", "approved", "denied"]:
					var line: String = {"arrival": c.arrival_line, "approved": c.reaction_approved, "denied": c.reaction_denied}[kind]
					var tagged := _deck_of(c, line, kind)
					if tagged == "":
						failures.append("seed %d: %s line '%s' is in no pool for %s" % [seed_value, kind, line, c.claim_no])
						continue
					var deck := tagged.get_slice("|", 0)
					if not drawn.has(deck):
						drawn[deck] = []
					(drawn[deck] as Array).append(tagged.get_slice("|", 1))
				if not Lines.dx_pool(c.diagnosis_id, c.parent_speaks).is_empty():
					dx_eligible += 1
					if _deck_of(c, c.arrival_line, "arrival").begins_with("dx:"):
						dx_lines += 1
		for deck: String in drawn:
			var lines: Array = drawn[deck]
			var distinct := {}
			for line: String in lines:
				distinct[line] = true
			var expected := mini(lines.size(), _pool_size(deck))
			if distinct.size() != expected:
				failures.append("seed %d %s: %d dealt, %d distinct, deck of %d" % [seed_value, deck, lines.size(), distinct.size(), _pool_size(deck)])
	t.eq(failures.size(), 0, "\n".join(failures.slice(0, 20)))
	var share := float(dx_lines) / maxi(dx_eligible, 1)
	t.ok(share > 0.2 and share < 0.45, "diagnosis lines used for %d of %d eligible patients" % [dx_lines, dx_eligible])


## A day generated on its own deals the same names and lines as that day in a
## full week, because both are dealt by the patient's place in the week.
func test_a_day_alone_matches_the_full_week() -> void:
	for seed_value in [3, 77, 2026]:
		var week := ClaimGenerator.new(seed_value, "Pat Doe")
		var full := {}
		for day in range(1, 8):
			full[day] = _full_fingerprint(week.generate_day(day))
		for day in [5, 1, 7, 3]:
			t.eq(_full_fingerprint(ClaimGenerator.new(seed_value, "Pat Doe").generate_day(day)), full[day], "seed %d day %d" % [seed_value, day])


func test_diagnosis_lines_belong_to_real_diagnoses() -> void:
	t.ok(Lines.DX_ARRIVAL.size() >= 15, "diagnoses with their own lines: %d" % Lines.DX_ARRIVAL.size())
	for id: String in Lines.DX_ARRIVAL:
		var dx := Medical.diagnosis(id)
		t.ok(not dx.is_empty(), "'%s' is a diagnosis" % id)
		var voices: Dictionary = Lines.DX_ARRIVAL[id]
		for voice: String in voices:
			t.ok(voice in ["adult", "parent"], "%s: voice %s" % [id, voice])
			t.eq((voices[voice] as Array).size(), 2, "%s %s lines" % [id, voice])
			t.ok(bool(dx.get("child_ok" if voice == "parent" else "adult_ok", false)), "%s can't have a %s voice" % [id, voice])


## Random patients' arrival lines are dealt, so the desk never has to pick one.
func test_random_patients_arrive_with_a_line_and_scripted_ones_with_theirs() -> void:
	var gen := ClaimGenerator.new(41, "Pat Doe")
	for day in range(1, 8):
		for c in gen.generate_day(day):
			t.ok(c.arrival_line != "", "%s has an arrival line" % c.claim_no)
			if c.parent_speaks:
				t.ok(c.arrival_line.contains(c.first_name()) or not c.arrival_line.contains("{child}"), "%s: %s" % [c.claim_no, c.arrival_line])
			t.ok(not c.arrival_line.contains("{"), "%s: no placeholder left in '%s'" % [c.claim_no, c.arrival_line])
			if c.scripted_id != "" and not c.is_player:
				t.eq(c.arrival_line, Scripted.get_case(c.scripted_id)["line"])


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
