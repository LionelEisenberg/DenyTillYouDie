extends RefCounted

var t: TestContext


func test_every_diagnosis_procedure_exists() -> void:
	for dx: Dictionary in Medical.DIAGNOSES:
		for key in ["procs", "pa_addons", "excluded_addons"]:
			for proc_id: String in dx[key]:
				t.ok(Medical.PROCEDURES.has(proc_id), "%s references missing %s" % [dx["id"], proc_id])


func test_addon_flags_match_their_lists() -> void:
	for dx: Dictionary in Medical.DIAGNOSES:
		for proc_id: String in dx["pa_addons"]:
			t.ok(Medical.PROCEDURES[proc_id]["pa"], "%s pa addon %s lacks pa flag" % [dx["id"], proc_id])
		for proc_id: String in dx["excluded_addons"]:
			t.ok(Medical.PROCEDURES[proc_id]["excluded"], "%s excluded addon %s lacks excluded flag" % [dx["id"], proc_id])
		for proc_id: String in dx["procs"]:
			t.ok(not Medical.PROCEDURES[proc_id]["excluded"], "%s base proc %s is excluded" % [dx["id"], proc_id])


func test_each_priority_has_diagnoses_for_adults_and_children() -> void:
	for priority in 3:
		var adult := 0
		var child := 0
		for dx: Dictionary in Medical.DIAGNOSES:
			if dx["priority"] == priority:
				if dx["adult_ok"]:
					adult += 1
				if dx["child_ok"]:
					child += 1
		t.ok(adult >= 3, "priority %d adult diagnoses: %d" % [priority, adult])
		t.ok(child >= 1, "priority %d child diagnoses: %d" % [priority, child])


func test_chronic_diagnoses_exist_for_pre_existing() -> void:
	var chronic := 0
	for dx: Dictionary in Medical.DIAGNOSES:
		if dx["chronic"]:
			chronic += 1
	t.ok(chronic >= 6, "chronic diagnoses: %d" % chronic)


func test_pa_and_excluded_procedures_exist() -> void:
	t.ok(Medical.pa_labels().size() >= 5, "pa procedures")
	t.ok(Medical.excluded_labels().size() >= 5, "excluded procedures")


func test_enough_diagnoses_can_take_pa_and_exclusion_addons() -> void:
	var with_pa := 0
	var with_excluded := 0
	for dx: Dictionary in Medical.DIAGNOSES:
		var has_pa_base := false
		for proc_id: String in dx["procs"]:
			if Medical.PROCEDURES[proc_id]["pa"]:
				has_pa_base = true
		if has_pa_base or not (dx["pa_addons"] as Array).is_empty():
			with_pa += 1
		if not (dx["excluded_addons"] as Array).is_empty():
			with_excluded += 1
	t.ok(with_pa >= 8, "diagnoses that can carry a prior-auth procedure: %d" % with_pa)
	t.ok(with_excluded >= 8, "diagnoses that can carry an excluded procedure: %d" % with_excluded)


func test_filler_history_never_matches_a_diagnosis() -> void:
	var conditions: Array[String] = []
	for dx: Dictionary in Medical.DIAGNOSES:
		conditions.append(dx["condition"])
	for entry: Dictionary in Medical.FILLER_HISTORY:
		t.ok(not conditions.has(entry["condition"]), "filler %s collides" % entry["label"])


## Filler must be unrelated to every diagnosis, not just a different key, or "the
## claimed condition under another name" stops being decidable.
func test_filler_history_is_the_neutral_list() -> void:
	var expected: Array[String] = [
		"Chickenpox", "Wisdom teeth removed", "Food poisoning", "Vision correction",
		"Shingles", "Tooth extraction", "Ingrown toenail", "Bunion",
		"Tetanus booster", "Dental crown", "Plantar wart", "Ganglion cyst",
	]
	var labels: Array[String] = []
	var keys := {}
	for entry: Dictionary in Medical.FILLER_HISTORY:
		labels.append(entry["label"])
		var key: String = entry["condition"]
		t.ok(key.begins_with("hx_"), "%s has key %s" % [entry["label"], key])
		t.ok(not keys.has(key), "%s reuses key %s" % [entry["label"], key])
		keys[key] = true
		t.ok(int(entry.get("min_age", 0)) >= 1, "%s needs a min_age of at least 1" % entry["label"])
	t.eq(labels, expected)


func test_every_diagnosis_says_whether_it_can_kill() -> void:
	var non_fatal: Array[String] = []
	for dx: Dictionary in Medical.DIAGNOSES:
		t.ok(dx.has("fatal") and typeof(dx["fatal"]) == TYPE_BOOL, "%s needs a bool fatal flag" % dx["id"])
		if not dx.get("fatal", true):
			non_fatal.append(dx["id"])
	non_fatal.sort()
	t.eq(non_fatal, ["acl_tear", "depression", "kidney_stone"] as Array[String])


func test_r05_text_says_other_names_not_related_conditions() -> void:
	var text: String = Rules.get_rule("R-05")["text"]
	t.eq(text, "Deny if the medical history lists the claimed condition (sometimes under another name) dated before the card's MEMBER SINCE date.")
	t.ok(not text.to_lower().contains("related"), "no related conditions")


## Every line a patient can say: generic pools and the scripted cases.
func _patient_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for pools: Array in [Lines.ARRIVAL, Lines.ARRIVAL_PARENT, Lines.APPROVED, Lines.DENIED]:
		for pool: Array in pools:
			for line: String in pool:
				lines.append(line)
	for pool: Array in [Lines.APPROVED_PARENT, Lines.DENIED_PARENT, Lines.CODE_REACTIONS]:
		for line: String in pool:
			lines.append(line)
	for code: String in Lines.CODE_SPECIFIC:
		for line: String in Lines.CODE_SPECIFIC[code]:
			lines.append(line)
	for case_data: Dictionary in Scripted.CASES:
		lines.append(case_data["line"])
	for id: String in Scripted.REACTIONS:
		lines.append(Scripted.REACTIONS[id]["approved"])
		lines.append(Scripted.REACTIONS[id]["denied"])
	return lines


## Generic lines sit next to any card, so they can't say how long someone has
## been a member, when they joined, or how long a condition has been around.
func test_patient_lines_make_no_time_claims_a_card_could_contradict() -> void:
	var months := "january|february|march|april|june|july|august|september|october|november|december"
	var pattern := RegEx.create_from_string("(?i)\\b(%s|years?|born|last week|last month)\\b" % months)
	var lines := _patient_lines()
	t.ok(lines.size() > 150, "collected %d lines" % lines.size())
	for line in lines:
		var hit := pattern.search(line)
		t.ok(hit == null, "\"%s\" says \"%s\"" % [line, hit.get_string() if hit else ""])


func test_chronic_diagnoses_have_history_labels() -> void:
	for dx: Dictionary in Medical.DIAGNOSES:
		if dx["chronic"]:
			t.ok(dx["history_label"] != "", "%s needs a history label" % dx["id"])


func test_providers_disjoint() -> void:
	t.eq(Medical.PROVIDERS_IN.size(), 8)
	t.eq(Medical.PROVIDERS_OUT.size(), 6)
	for p in Medical.PROVIDERS_OUT:
		t.ok(not Medical.PROVIDERS_IN.has(p), p)


func test_rules_one_per_day() -> void:
	t.eq(Rules.ALL.size(), 7)
	for i in Rules.ALL.size():
		t.eq(Rules.ALL[i]["day"], i + 1)
		t.eq(Rules.ALL[i]["id"], "R-0%d" % (i + 1))
	t.eq(Rules.unlocked(1), PackedStringArray(["R-01"]))
	t.eq(Rules.unlocked(3).size(), 3)
	t.eq(Rules.get_rule("R-04")["title"], "No prior authorization")


func test_font_covers_all_game_text() -> void:
	var font: FontFile = load("res://assets/fonts/MatchupPro.ttf")
	var dirs := ["res://content/", "res://core/", "res://screens/", "res://ui/", "res://autoload/"]
	for dir in dirs:
		for file_name in DirAccess.get_files_at(dir):
			if not file_name.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir + file_name)
			for i in text.length():
				var code := text.unicode_at(i)
				if code > 126 and not font.has_char(code):
					t.ok(false, "%s has %s (U+%04X), missing from MatchupPro" % [file_name, String.chr(code), code])


func test_name_pools_are_big_enough() -> void:
	t.ok(Names.FIRST.size() >= 60, "first names")
	t.ok(Names.LAST.size() >= 60, "last names")
