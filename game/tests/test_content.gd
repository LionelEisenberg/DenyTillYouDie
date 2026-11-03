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


func test_name_pools_are_big_enough() -> void:
	t.ok(Names.FIRST.size() >= 60, "first names")
	t.ok(Names.LAST.size() >= 60, "last names")
