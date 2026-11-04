class_name ClaimGenerator
extends RefCounted
## Builds each day's patients from a seed, so reloading a morning replays the same day.
##
## Random claims break at most one rule, chosen from the rules unlocked that day;
## clean claims carry decoys (cards that expire soon, prior-auth procedures with an
## auth number, conditions diagnosed after enrollment) so the player has to read.
## The provider follows from what was billed: a family clinic never bills surgery.
##
## Day 1 opens with two training claims: a plain lapse (R-01 and nothing else)
## and a clean claim. On days 2-6 the first patient breaks the day's new rule
## whenever anyone that day does. Names come from one list per run and lines
## from per-run decks, both dealt by the patient's place in the week, so nobody
## repeats and any single day regenerates on its own.

const PATIENTS_PER_DAY: Array[int] = [5, 6, 7, 7, 8, 8, 7]
const VIOLATION_TARGET: Array[float] = [0.40, 0.50, 0.55, 0.60, 0.60, 0.65, 0.65]
const NEW_RULE_SHARE := 0.45
const PRIORITY_WEIGHTS: Array[float] = [0.55, 0.33, 0.12]
const CHILD_SHARE := 0.12
const PLAN_YEAR_END := Vector3i(2026, 12, 31)

const AGE_RANGES: Dictionary = {
	"hip_fx": [62, 92], "heart_attack": [42, 88], "afib": [45, 90], "stroke": [48, 90],
	"kidney_failure": [40, 85], "breast_cancer": [32, 80], "colon_cancer": [40, 85],
	"hypertension": [35, 85], "croup": [2, 6], "ear_infection": [2, 10],
}
const ADULT_AGES := [18, 88]
const CHILD_AGES := [2, 15]
const HOSPITALS: PackedStringArray = ["Riverside General Hospital", "St. Agnes Medical Center", "Mercer County Hospital"]
const ORTHO_DIAGNOSES: PackedStringArray = ["wrist_fx", "ankle_sprain", "acl_tear", "hip_fx"]
## Procedures only a hospital bills (or the cancer institute, or orthopedics).
const HOSPITAL_PROCS: PackedStringArray = [
	"er_visit", "icu_stay", "inpatient_stay", "observation", "appendectomy", "acl_surgery",
	"hip_replacement", "gallbladder", "cardiac_cath", "stent", "stroke_tpa", "dialysis", "chemo", "radiation",
]
## Share of children with office or urgent-care problems seen by the pediatrician.
const PEDIATRICS_SHARE := 0.6
## Coverage starts at least this many days before the date of service.
const ENROLLMENT_LEAD := 20
## A pre-existing record (R-05) is dated at least a year after birth, and between
## PRE_EXISTING_GAP and PRE_EXISTING_SPAN days before MEMBER SINCE.
const RECORD_MIN_AGE_DAYS := 365
const PRE_EXISTING_GAP := 30
const PRE_EXISTING_SPAN := 1400
## The youngest patient with a pre-existing condition: on record at one, enrolled
## after that, and a claim after that.
const PRE_EXISTING_MIN_AGE := 3
const VOWELS := "aeiou"
## Day 1's first patient: coverage ended this many days before the date of service.
const TRAINING_GAP := Vector2i(10, 40)
## Share of patients with a Lines.DX_ARRIVAL line who open with it instead of the deck.
const DX_LINE_SHARE := 0.4
## Names drawn per run: at least one for every patient in the week.
const WEEK_NAMES := 49

var run_seed: int
var player_name: String
var _names: PackedStringArray = []
## Shuffled line decks by key ("arrival:adult:0", "denied:parent", "dx:croup:parent"...).
var _decks: Dictionary = {}
## Day -> what each of its patients draws lines by (see _profile).
var _profiles: Dictionary = {}


func _init(seed_value: int, player: String) -> void:
	run_seed = seed_value
	player_name = player


## Every patient for `day`, in arrival order. Day 7 ends with the player's own claim.
func generate_day(day: int) -> Array[Claim]:
	var claims := _generate_raw(day)
	_deal_lines(day, claims)
	_make_claim_numbers_unique(claims)
	_example_first(claims, day)
	return claims


## A patient's place in the week, counting from 0 at day 1's first slot. Names
## and lines are dealt by it.
static func week_index(day: int, slot: int) -> int:
	var index := slot
	for d in range(1, day):
		index += PATIENTS_PER_DAY[d - 1]
	return index


## The run's patient names, one per place in the week: distinct first names and
## distinct full names, never a scripted patient's or the player's own.
func week_names() -> PackedStringArray:
	if not _names.is_empty():
		return _names
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "names"])
	var firsts := _shuffled(Array(Names.FIRST), rng)
	var lasts := _shuffled(Array(Names.LAST), rng)
	var taken := {player_name.strip_edges().to_lower(): true}
	for case_data: Dictionary in Scripted.CASES:
		taken[String(case_data["name"]).to_lower()] = true
	var next_last := 0
	for i in maxi(WEEK_NAMES, week_index(PATIENTS_PER_DAY.size() + 1, 0)):
		var first: String = firsts[i % firsts.size()]
		var full := ""
		for attempt in lasts.size():
			full = "%s %s" % [first, lasts[next_last % lasts.size()]]
			next_last += 1
			if not taken.has(full.to_lower()):
				break
		taken[full.to_lower()] = true
		_names.append(full)
	return _names


## The day's claims in generation order, before lines are dealt or anyone is
## moved up. The same seed always gives the same claims.
func _generate_raw(day: int) -> Array[Claim]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, day])
	var scripted := Scripted.for_day(day)
	var claims: Array[Claim] = []
	for i in PATIENTS_PER_DAY[day - 1]:
		if not scripted.is_empty() and i == int(scripted["slot"]):
			claims.append(make_scripted(scripted, day, rng))
		elif day == 1 and i < 2:
			claims.append(_training_claim(day, rng, _name_for(day, i), i == 0))
		else:
			claims.append(random_claim(day, rng, _name_for(day, i)))
	if day == 7:
		claims.append(make_player_claim(day))
	return claims


## A random patient. `full_name` (generate_day passes the week's name for the
## slot) replaces the name drawn from the pools; the draw still happens, so the
## rest of the claim comes out the same either way.
func random_claim(day: int, rng: RandomNumberGenerator, full_name: String = "") -> Claim:
	var rule := ""
	if rng.randf() < VIOLATION_TARGET[day - 1]:
		rule = _pick_rule(day, rng)
	var want_child := rng.randf() < CHILD_SHARE
	var dx := _pick_diagnosis(_pick_priority(rng), want_child, rule, rng)
	var child := want_child and bool(dx["child_ok"])
	if not child and not dx["adult_ok"]:
		child = true
	var drawn := "%s %s" % [Names.FIRST[rng.randi_range(0, Names.FIRST.size() - 1)], Names.LAST[rng.randi_range(0, Names.LAST.size() - 1)]]
	if full_name == "":
		full_name = drawn
	var age := _pick_age(dx, child, rng)
	if rule == Rules.R05:
		age = maxi(age, PRE_EXISTING_MIN_AGE)
	var c := _build(day, dx, age, full_name, rng)
	if rule == "":
		_add_decoys(c, dx, rng)
	else:
		_plant(c, rule, dx, rng)
	# Picked last, from the final bill. An R-02 plant has already chosen one.
	if c.provider == "":
		c.provider = _pick_provider(c, rng)
	c.amount = c.bill_total()
	return c


func make_scripted(case_data: Dictionary, day: int, rng: RandomNumberGenerator) -> Claim:
	var dx := Medical.diagnosis(case_data["dx"])
	var c := _build(day, dx, case_data["age"], case_data["name"], rng)
	c.scripted_id = case_data["id"]
	c.diagnosis = case_data.get("diagnosis", c.diagnosis)
	c.arrival_line = case_data["line"]
	c.sticky_note = case_data.get("sticky_note", "")
	c.exempt_from_citation = case_data.get("exempt", false)
	match case_data["rule"]:
		Rules.R01:
			c.coverage_through = c.date_of_service - 3
			c.member_since = mini(c.member_since, c.coverage_through - 1800)
		Rules.R03:
			c.name = case_data["claim_name"]
		Rules.R04:
			c.prior_auth = ""
		Rules.R05:
			c.member_since = DateUtil.from_ymd(2026, 1, 1)
			c.history.append({"date": DateUtil.from_ymd(2025, 11, 10), "label": dx["history_label"], "condition": dx["condition"]})
			_sort_history(c)
		Rules.R06:
			c.bill_lines.append(Claim.make_line(case_data["addon"]))
	if case_data.has("member_years"):
		var years := float(case_data["member_years"])
		c.member_since = c.date_of_service - roundi(years * 365.25) - rng.randi_range(10, 150)
	if case_data.has("provider"):
		c.provider = case_data["provider"]
	else:
		c.provider = _pick_provider(c, rng)
	c.amount = c.bill_total()
	c.exhibit = _exhibit(case_data.get("exhibit", {}), c)
	return c


## Day 1's first two patients, for learning the desk: an adult ROUTINE claim
## whose only fault is coverage that ended TRAINING_GAP days before the date of
## service (`lapsed`), or one with nothing wrong at all. Neither carries decoys.
func _training_claim(day: int, rng: RandomNumberGenerator, full_name: String, lapsed: bool) -> Claim:
	var pool: Array[Dictionary] = []
	for candidate: Dictionary in Medical.DIAGNOSES:
		if candidate["priority"] == Claim.Priority.ROUTINE and candidate["adult_ok"]:
			pool.append(candidate)
	var dx: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var c := _build(day, dx, _pick_age(dx, false, rng), full_name, rng)
	if lapsed:
		c.coverage_through = c.date_of_service - rng.randi_range(TRAINING_GAP.x, TRAINING_GAP.y)
		if c.member_since >= c.coverage_through - 30:
			c.member_since = maxi(c.card_dob + 30, c.coverage_through - rng.randi_range(200, 900))
	c.provider = _pick_provider(c, rng)
	c.amount = c.bill_total()
	return c


## A scripted case's exhibit template made concrete: "{date}" becomes the date
## of service, and each "log" entry a row dated that many days from it.
static func _exhibit(template: Dictionary, c: Claim) -> Dictionary:
	if template.is_empty():
		return {}
	var service := DateUtil.fmt(c.date_of_service)
	var rows: Array = []
	for pair: Array in template.get("rows", []):
		rows.append([String(pair[0]), String(pair[1]).replace("{date}", service)])
	for entry: Array in template.get("log", []):
		rows.append([DateUtil.fmt(c.date_of_service + int(entry[0])), String(entry[1])])
	return {
		"kind": String(template.get("kind", "log")),
		"title": String(template.get("title", "")),
		"subtitle": String(template.get("subtitle", "")),
		"rows": rows,
		"body": String(template.get("body", "")),
		"signature": String(template.get("signature", "")),
		"image": String(template.get("image", "")),
	}


func make_player_claim(day: int) -> Claim:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "player"])
	var dx := Medical.diagnosis(Scripted.PLAYER["dx"])
	var c := _build(day, dx, Scripted.PLAYER["age"], player_name, rng)
	c.is_player = true
	c.scripted_id = "player"
	c.provider = Scripted.PLAYER["provider"]
	c.arrival_line = Scripted.PLAYER["line"]
	c.portrait_seed = hash(player_name)
	c.date_of_service = DateUtil.game_date(day) - 1
	c.member_since = DateUtil.game_date(1)
	c.prior_auth = ""
	c.history = [
		{"date": DateUtil.game_date(1) - 10, "label": dx["history_label"], "condition": dx["condition"]},
		{"date": DateUtil.game_date(1) - 10, "label": "Pre-employment physical", "condition": "hx_physical"},
	]
	c.amount = c.bill_total()
	return c


# --- building blocks -------------------------------------------------------

## The claim before any rule is broken. The provider is left blank: it depends on
## what ends up on the bill.
func _build(day: int, dx: Dictionary, age: int, full_name: String, rng: RandomNumberGenerator) -> Claim:
	var c := Claim.new()
	var today := DateUtil.game_date(day)
	var ymd := DateUtil.to_ymd(today)
	c.day = day
	c.age = age
	c.claim_no = "BM-%02d%02d-%04d" % [ymd.y, ymd.z, rng.randi_range(1000, 9999)]
	c.name = full_name
	c.card_name = full_name
	c.card_dob = _dob_for_age(age, today, rng)
	c.dob = c.card_dob
	c.card_member_id = "BMH-%03d-%04d" % [rng.randi_range(100, 999), rng.randi_range(0, 9999)]
	c.member_id = c.card_member_id
	c.plan = Medical.PLANS[rng.randi_range(0, Medical.PLANS.size() - 1)]
	c.date_of_service = today - rng.randi_range(2, 40)
	c.member_since = maxi(c.card_dob + 30, today - rng.randi_range(240, 3200))
	c.member_since = mini(c.member_since, c.date_of_service - ENROLLMENT_LEAD)
	c.coverage_through = DateUtil.from_ymd(PLAN_YEAR_END.x, PLAN_YEAR_END.y, PLAN_YEAR_END.z)
	c.diagnosis = dx["label"]
	c.diagnosis_id = dx["id"]
	c.condition = dx["condition"]
	c.priority = dx["priority"]
	for proc_id: String in dx["procs"]:
		c.bill_lines.append(Claim.make_line(proc_id))
	_refresh_prior_auth(c, rng)
	c.history = _filler_history(c, today, rng)
	c.portrait_seed = rng.randi()
	c.line_seed = rng.randi()
	c.parent_speaks = c.is_child()
	c.amount = c.bill_total()
	return c


func _plant(c: Claim, rule: String, dx: Dictionary, rng: RandomNumberGenerator) -> void:
	match rule:
		Rules.R01:
			c.coverage_through = c.date_of_service - rng.randi_range(1, 75)
			if c.member_since >= c.coverage_through - 30:
				c.member_since = maxi(c.card_dob + 30, c.coverage_through - rng.randi_range(200, 900))
		Rules.R02:
			var pool: PackedStringArray = []
			for p in Medical.PROVIDERS_OUT:
				if c.is_child() or not p.contains("Children"):
					pool.append(p)
			c.provider = pool[rng.randi_range(0, pool.size() - 1)]
		Rules.R03:
			_clerical_error(c, rng)
		Rules.R04:
			if not _has_pa_line(c):
				var addons: Array = dx["pa_addons"]
				c.bill_lines.append(Claim.make_line(addons[rng.randi_range(0, addons.size() - 1)]))
			c.prior_auth = ""
		Rules.R05:
			_plant_pre_existing(c, dx, rng)
		Rules.R06:
			var excluded: Array = dx["excluded_addons"]
			c.bill_lines.append(Claim.make_line(excluded[rng.randi_range(0, excluded.size() - 1)]))


## A record of the claimed condition before MEMBER SINCE, dated after the patient's
## first birthday and at least PRE_EXISTING_GAP days before enrollment. A child
## enrolled as a baby leaves no room for that, so their card says they joined later.
func _plant_pre_existing(c: Claim, dx: Dictionary, rng: RandomNumberGenerator) -> void:
	var earliest := c.card_dob + RECORD_MIN_AGE_DAYS
	if c.member_since - PRE_EXISTING_GAP < earliest:
		var first := earliest + PRE_EXISTING_GAP
		var last := c.date_of_service - ENROLLMENT_LEAD
		if first > last:
			push_error("%s: patient aged %d is too young for a pre-existing condition" % [c.claim_no, c.age])
		c.member_since = rng.randi_range(first, maxi(first, last))
	var when := rng.randi_range(maxi(earliest, c.member_since - PRE_EXISTING_SPAN), c.member_since - PRE_EXISTING_GAP)
	c.history.append({"date": when, "label": dx["history_label"], "condition": dx["condition"]})
	_sort_history(c)


## Harmless details that look like they might be violations.
func _add_decoys(c: Claim, dx: Dictionary, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.25:
		var service := DateUtil.to_ymd(c.date_of_service)
		var months_ahead := rng.randi_range(1, 2)
		var month := service.y + months_ahead
		var year := service.x
		if month > 12:
			month -= 12
			year += 1
		c.coverage_through = DateUtil.from_ymd(year, month, 1) - 1
	var pa_addons: Array = dx["pa_addons"]
	if not pa_addons.is_empty() and rng.randf() < 0.3:
		c.bill_lines.append(Claim.make_line(pa_addons[rng.randi_range(0, pa_addons.size() - 1)]))
		_refresh_prior_auth(c, rng)
	if dx["chronic"] and rng.randf() < 0.25:
		# Diagnosed after enrollment (and, like any record, after the first birthday).
		var first := maxi(c.member_since + 1, c.card_dob + RECORD_MIN_AGE_DAYS)
		var last := c.date_of_service - 1
		if last >= first:
			c.history.append({"date": rng.randi_range(first, last), "label": dx["history_label"], "condition": dx["condition"]})
			_sort_history(c)


func _clerical_error(c: Claim, rng: RandomNumberGenerator) -> void:
	match rng.randi_range(0, 2):
		0:
			c.name = _typo(c.card_name, rng)
		1:
			var digits: Array[int] = []
			for i in c.card_member_id.length():
				if c.card_member_id[i].is_valid_int():
					digits.append(i)
			var pos: int = digits[rng.randi_range(0, digits.size() - 1)]
			var old := int(c.card_member_id[pos])
			var replacement := (old + rng.randi_range(1, 9)) % 10
			c.member_id = c.card_member_id.substr(0, pos) + str(replacement) + c.card_member_id.substr(pos + 1)
		2:
			var shifts := [1, -1, 2, -3, 365, -365]
			c.dob = c.card_dob + int(shifts[rng.randi_range(0, shifts.size() - 1)])


func _typo(full_name: String, rng: RandomNumberGenerator) -> String:
	var parts := full_name.split(" ")
	for attempt in 20:
		var idx := rng.randi_range(0, parts.size() - 1)
		var word := parts[idx]
		if word.length() < 4:
			continue
		var mutated := word
		var pos := rng.randi_range(1, word.length() - 2)
		match rng.randi_range(0, 3):
			0:
				mutated = word.substr(0, pos) + word[pos + 1] + word[pos] + word.substr(pos + 2)
			1:
				mutated = word.substr(0, pos) + word.substr(pos + 1)
			2:
				mutated = word.substr(0, pos) + word[pos] + word.substr(pos)
			3:
				var vowel_positions: Array[int] = []
				for i in range(1, word.length()):
					if VOWELS.contains(word[i]):
						vowel_positions.append(i)
				if not vowel_positions.is_empty():
					var vp: int = vowel_positions[rng.randi_range(0, vowel_positions.size() - 1)]
					var options := VOWELS.replace(word[vp], "")
					mutated = word.substr(0, vp) + options[rng.randi_range(0, options.length() - 1)] + word.substr(vp + 1)
		if mutated != word:
			var copy := parts.duplicate()
			copy[idx] = mutated
			return " ".join(copy)
	return full_name + "e"


func _pick_rule(day: int, rng: RandomNumberGenerator) -> String:
	var pool: Array[String] = []
	for id in Rules.unlocked(day):
		if id != Rules.R07:
			pool.append(id)
	var newest: Dictionary = Rules.new_rule_on(day)
	if pool.size() > 1 and not newest.is_empty() and pool.has(newest["id"]):
		if rng.randf() < NEW_RULE_SHARE:
			return newest["id"]
		pool.erase(newest["id"])
	return pool[rng.randi_range(0, pool.size() - 1)]


func _pick_priority(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	var acc := 0.0
	for i in PRIORITY_WEIGHTS.size():
		acc += PRIORITY_WEIGHTS[i]
		if roll < acc:
			return i
	return Claim.Priority.ROUTINE


func _pick_diagnosis(priority: int, child: bool, rule: String, rng: RandomNumberGenerator) -> Dictionary:
	for relax in 3:
		var pool: Array[Dictionary] = []
		for dx in Medical.DIAGNOSES:
			if relax < 1 and dx["priority"] != priority:
				continue
			var fits_age: bool = dx["child_ok"] if (child and relax < 2) else dx["adult_ok"]
			if fits_age and _supports(dx, rule):
				pool.append(dx)
		if not pool.is_empty():
			return pool[rng.randi_range(0, pool.size() - 1)]
	push_error("No diagnosis supports rule %s" % rule)
	return Medical.DIAGNOSES[0]


func _supports(dx: Dictionary, rule: String) -> bool:
	match rule:
		Rules.R04:
			if not (dx["pa_addons"] as Array).is_empty():
				return true
			for proc_id: String in dx["procs"]:
				if Medical.PROCEDURES[proc_id]["pa"]:
					return true
			return false
		Rules.R05:
			return dx["chronic"]
		Rules.R06:
			return not (dx["excluded_addons"] as Array).is_empty()
	return true


func _pick_age(dx: Dictionary, child: bool, rng: RandomNumberGenerator) -> int:
	var span: Array = AGE_RANGES.get(dx["id"], CHILD_AGES if child else ADULT_AGES)
	if child and int(span[0]) >= Claim.CHILD_AGE:
		span = CHILD_AGES
	if not child and int(span[1]) < Claim.CHILD_AGE:
		span = ADULT_AGES
	var lo := int(span[0])
	var hi := int(span[1])
	if child:
		hi = mini(hi, Claim.CHILD_AGE - 1)
	else:
		lo = maxi(lo, 18)
	return rng.randi_range(lo, hi)


## Who billed the claim, judged from the final bill: cancer care comes from the
## cancer institute, orthopedics without an ER visit from the orthopedic group,
## anything hospital-level from a hospital. Only what's left (office and
## urgent-care problems) goes to the pediatrician, urgent care or family clinic.
func _pick_provider(c: Claim, rng: RandomNumberGenerator) -> String:
	var billed: Array[String] = []
	for line in c.bill_lines:
		billed.append(line["id"])
	if billed.has("oncology_consult"):
		return "Westbrook Cancer Institute"
	if ORTHO_DIAGNOSES.has(c.diagnosis_id) and not billed.has("er_visit"):
		return "Lakeside Orthopedics"
	for proc_id in billed:
		if HOSPITAL_PROCS.has(proc_id):
			return HOSPITALS[rng.randi_range(0, HOSPITALS.size() - 1)]
	if c.is_child() and rng.randf() < PEDIATRICS_SHARE:
		return "Elm Street Pediatrics"
	if billed.has("urgent_care"):
		return "Harborview Urgent Care"
	return "Northgate Family Clinic"


func _dob_for_age(age: int, today: int, rng: RandomNumberGenerator) -> int:
	var now := DateUtil.to_ymd(today)
	var month := rng.randi_range(1, 12)
	var day_of_month := rng.randi_range(1, 28)
	var dob := DateUtil.from_ymd(now.x - age, month, day_of_month)
	if DateUtil.age_on(dob, today) != age:
		dob = DateUtil.from_ymd(now.x - age - 1, month, day_of_month)
	return dob


## One to three unrelated old entries (one for toddlers), each dated after the
## patient was old enough for it (FILLER_HISTORY `min_age`) and at least a month ago.
func _filler_history(c: Claim, today: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var latest := today - 30
	var pool: Array[Dictionary] = []
	for entry: Dictionary in Medical.FILLER_HISTORY:
		if c.card_dob + int(entry["min_age"]) * 365 <= latest:
			pool.append(entry)
	var count := mini(rng.randi_range(1, 3) if c.age >= 4 else 1, pool.size())
	var entries: Array[Dictionary] = []
	for i in count:
		var entry: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var earliest := c.card_dob + int(entry["min_age"]) * 365
		entries.append({"date": rng.randi_range(earliest, latest), "label": entry["label"], "condition": entry["condition"]})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["date"]) < int(b["date"]))
	return entries


func _has_pa_line(c: Claim) -> bool:
	for line in c.bill_lines:
		if line["pa"]:
			return true
	return false


func _refresh_prior_auth(c: Claim, rng: RandomNumberGenerator) -> void:
	if _has_pa_line(c) and c.prior_auth == "":
		c.prior_auth = "PA-%05d" % rng.randi_range(10000, 99999)


func _sort_history(c: Claim) -> void:
	c.history.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["date"]) < int(b["date"]))


## Claim numbers come from each patient's own draw, so two can collide. Later
## patients step to the next free number; the result depends only on the seed.
func _make_claim_numbers_unique(claims: Array[Claim]) -> void:
	var used := {}
	for c in claims:
		while used.has(c.claim_no):
			c.claim_no = _next_claim_no(c.claim_no)
		used[c.claim_no] = true


## "BM-0302-4417" -> "BM-0302-4418"; the four-digit serial wraps 9999 -> 1000.
static func _next_claim_no(claim_no: String) -> String:
	var serial := int(claim_no.right(4)) + 1
	if serial > 9999:
		serial = 1000
	return "%s%04d" % [claim_no.left(-4), serial]


# --- the week's order, names and lines --------------------------------------

## Days 2-6: the first patient shows the day's new rule broken, if anyone does.
## Only the order changes: the first later random patient who breaks it trades
## places with the first. The scripted case keeps its slot.
func _example_first(claims: Array[Claim], day: int) -> void:
	if day < 2 or day > 6 or claims.is_empty() or claims[0].scripted_id != "":
		return
	var rule: String = Rules.new_rule_on(day).get("id", "")
	if rule == "" or _breaks(claims[0], rule, day):
		return
	for i in range(1, claims.size()):
		var c := claims[i]
		if c.scripted_id == "" and not c.is_player and _breaks(c, rule, day):
			claims[i] = claims[0]
			claims[0] = c
			return


static func _breaks(c: Claim, rule_id: String, day: int) -> bool:
	for v in RuleChecker.violations(c, day):
		if v["rule"] == rule_id:
			return true
	return false


func _name_for(day: int, slot: int) -> String:
	return week_names()[week_index(day, slot)]


## Gives every random patient of `day` an arrival line and both reactions, dealt
## in week order from per-run shuffled decks, so no line comes round again until
## its deck has been dealt through. Earlier days only need to say what they drew
## (their profiles, generated once): a day dealt alone matches the same day in a
## full week.
func _deal_lines(day: int, claims: Array[Claim]) -> void:
	var today := _profile(day, claims)
	_profiles[day] = today
	var dealt := {}
	for d in range(1, day):
		for patient: Dictionary in _day_profile(d):
			_deal_patient(patient, dealt)
	for slot in claims.size():
		var lines := _deal_patient(today[slot], dealt)
		if lines.is_empty():
			continue
		claims[slot].arrival_line = lines[0]
		claims[slot].reaction_approved = lines[1]
		claims[slot].reaction_denied = lines[2]


## What dealing needs to know about each patient of a day, slot by slot: {} for
## the scripted case and the player, who bring their own lines.
func _profile(day: int, claims: Array[Claim]) -> Array[Dictionary]:
	var patients: Array[Dictionary] = []
	for slot in claims.size():
		var c := claims[slot]
		if c.scripted_id != "" or c.is_player:
			patients.append({})
		else:
			patients.append({"place": week_index(day, slot), "tier": clampi(c.priority, 0, 2), "parent": c.parent_speaks, "dx": c.diagnosis_id, "first": c.first_name()})
	return patients


func _day_profile(day: int) -> Array[Dictionary]:
	if not _profiles.has(day):
		_profiles[day] = _profile(day, _generate_raw(day))
	var cached: Array[Dictionary] = _profiles[day]
	return cached


## One patient's [arrival line, approved reaction, denied reaction], or nothing
## for a patient with lines of their own. The arrival line is one for their
## diagnosis DX_LINE_SHARE of the time, while that diagnosis's lines last, and
## otherwise the next card from the priority deck.
func _deal_patient(patient: Dictionary, dealt: Dictionary) -> PackedStringArray:
	if patient.is_empty():
		return PackedStringArray()
	var parent: bool = patient["parent"]
	var tier: int = patient["tier"]
	var voice := "parent" if parent else "adult"
	var arrival := ""
	var specific := Lines.dx_pool(patient["dx"], parent)
	var dx_key := "dx:%s:%s" % [patient["dx"], voice]
	if not specific.is_empty() and int(dealt.get(dx_key, 0)) < specific.size():
		var roll := RandomNumberGenerator.new()
		roll.seed = hash([run_seed, "dx_line", patient["place"]])
		if roll.randf() < DX_LINE_SHARE:
			arrival = _deal_line(dx_key, specific, dealt)
	if arrival == "":
		arrival = _deal_line("arrival:%s:%d" % [voice, tier], Lines.arrival_pool(tier, parent), dealt)
	if parent:
		arrival = Lines.fill_child(arrival, patient["first"])
	var lines := PackedStringArray([arrival])
	for approved: bool in [true, false]:
		var kind := "approved" if approved else "denied"
		var key := ("%s:parent" % kind) if parent else ("%s:adult:%d" % [kind, tier])
		lines.append(_deal_line(key, Lines.reaction_pool(tier, approved, parent), dealt))
	return lines


## The next card from deck `key` (shuffled once per run from `pool`). The deck
## starts over, in the same order, once every card has been dealt.
func _deal_line(key: String, pool: Array, dealt: Dictionary) -> String:
	if pool.is_empty():
		return ""
	if not _decks.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([run_seed, "deck", key])
		_decks[key] = _shuffled(pool, rng)
	var deck: Array = _decks[key]
	var n := int(dealt.get(key, 0))
	dealt[key] = n + 1
	return deck[n % deck.size()]


## A Fisher-Yates shuffle driven by `rng` (Array.shuffle uses the global one).
static func _shuffled(items: Array, rng: RandomNumberGenerator) -> Array:
	var out := items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = out[i]
		out[i] = out[j]
		out[j] = swap
	return out
