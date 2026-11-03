class_name ClaimGenerator
extends RefCounted
## Builds each day's patients from a seed, so reloading a morning replays the same day.
##
## Random claims break at most one rule, chosen from the rules unlocked that day;
## clean claims carry decoys (cards that expire soon, prior-auth procedures with an
## auth number, conditions diagnosed after enrollment) so the player has to read.

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
const VOWELS := "aeiou"

var run_seed: int
var player_name: String


func _init(seed_value: int, player: String) -> void:
	run_seed = seed_value
	player_name = player


## Every patient for `day`, in arrival order. Day 7 ends with the player's own claim.
func generate_day(day: int) -> Array[Claim]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, day])
	var scripted := Scripted.for_day(day)
	var claims: Array[Claim] = []
	for i in PATIENTS_PER_DAY[day - 1]:
		if not scripted.is_empty() and i == int(scripted["slot"]):
			claims.append(make_scripted(scripted, day, rng))
		else:
			claims.append(random_claim(day, rng))
	if day == 7:
		claims.append(make_player_claim(day))
	return claims


func random_claim(day: int, rng: RandomNumberGenerator) -> Claim:
	var rule := ""
	if rng.randf() < VIOLATION_TARGET[day - 1]:
		rule = _pick_rule(day, rng)
	var want_child := rng.randf() < CHILD_SHARE
	var dx := _pick_diagnosis(_pick_priority(rng), want_child, rule, rng)
	var child := want_child and bool(dx["child_ok"])
	if not child and not dx["adult_ok"]:
		child = true
	var full_name := "%s %s" % [Names.FIRST[rng.randi_range(0, Names.FIRST.size() - 1)], Names.LAST[rng.randi_range(0, Names.LAST.size() - 1)]]
	var c := _build(day, dx, _pick_age(dx, child, rng), full_name, rng)
	if rule == "":
		_add_decoys(c, dx, rng)
	else:
		_plant(c, rule, dx, rng)
	c.amount = c.bill_total()
	return c


func make_scripted(case_data: Dictionary, day: int, rng: RandomNumberGenerator) -> Claim:
	var dx := Medical.diagnosis(case_data["dx"])
	var c := _build(day, dx, case_data["age"], case_data["name"], rng)
	c.scripted_id = case_data["id"]
	c.provider = case_data.get("provider", c.provider)
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
	c.amount = c.bill_total()
	return c


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
	c.member_since = mini(c.member_since, c.date_of_service - 20)
	c.coverage_through = DateUtil.from_ymd(PLAN_YEAR_END.x, PLAN_YEAR_END.y, PLAN_YEAR_END.z)
	c.diagnosis = dx["label"]
	c.condition = dx["condition"]
	c.priority = dx["priority"]
	c.provider = _pick_provider(dx, c.is_child(), rng)
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
			var earliest := c.card_dob + 365
			var when := maxi(earliest, c.member_since - rng.randi_range(45, 1400))
			if when >= c.member_since:
				when = c.member_since - 1
			c.history.append({"date": when, "label": dx["history_label"], "condition": dx["condition"]})
			_sort_history(c)
		Rules.R06:
			var excluded: Array = dx["excluded_addons"]
			c.bill_lines.append(Claim.make_line(excluded[rng.randi_range(0, excluded.size() - 1)]))


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
		var span := c.date_of_service - c.member_since
		if span > 2:
			var when := c.member_since + rng.randi_range(1, span - 1)
			c.history.append({"date": when, "label": dx["history_label"], "condition": dx["condition"]})
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


func _pick_provider(dx: Dictionary, child: bool, rng: RandomNumberGenerator) -> String:
	var procs: Array = dx["procs"]
	if child and rng.randf() < 0.6:
		return "Elm Street Pediatrics"
	if procs.has("oncology_consult"):
		return "Westbrook Cancer Institute"
	if procs.has("urgent_care"):
		return "Harborview Urgent Care"
	if procs.has("office_visit") or procs.has("psych_eval"):
		return "Northgate Family Clinic"
	if ORTHO_DIAGNOSES.has(dx["id"]) and rng.randf() < 0.5:
		return "Lakeside Orthopedics"
	return HOSPITALS[rng.randi_range(0, HOSPITALS.size() - 1)]


func _dob_for_age(age: int, today: int, rng: RandomNumberGenerator) -> int:
	var now := DateUtil.to_ymd(today)
	var month := rng.randi_range(1, 12)
	var day_of_month := rng.randi_range(1, 28)
	var dob := DateUtil.from_ymd(now.x - age, month, day_of_month)
	if DateUtil.age_on(dob, today) != age:
		dob = DateUtil.from_ymd(now.x - age - 1, month, day_of_month)
	return dob


func _filler_history(c: Claim, today: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var count := rng.randi_range(1, 3) if c.age >= 4 else 1
	var used: Array[int] = []
	var earliest := c.card_dob + 180
	for i in count:
		var pick := rng.randi_range(0, Medical.FILLER_HISTORY.size() - 1)
		if used.has(pick):
			continue
		used.append(pick)
		var entry: Dictionary = Medical.FILLER_HISTORY[pick]
		entries.append({"date": rng.randi_range(earliest, today - 30), "label": entry["label"], "condition": entry["condition"]})
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
