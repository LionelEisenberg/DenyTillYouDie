extends RefCounted

var t: TestContext


func _clean(day: int = 7) -> Claim:
	var c := Claim.new()
	c.day = day
	c.age = 64
	c.name = "Maria Okafor"
	c.card_name = "Maria Okafor"
	c.dob = DateUtil.from_ymd(1961, 7, 14)
	c.card_dob = c.dob
	c.member_id = "BMH-483-2291"
	c.card_member_id = c.member_id
	c.provider = "Riverside General Hospital"
	c.date_of_service = DateUtil.game_date(day) - 10
	c.member_since = DateUtil.from_ymd(2021, 1, 1)
	c.coverage_through = DateUtil.from_ymd(2026, 12, 31)
	c.diagnosis = "Fracture, left wrist"
	c.condition = "wrist_fracture"
	c.bill_lines = [Claim.make_line("er_visit"), Claim.make_line("xray_wrist"), Claim.make_line("cast")]
	c.amount = c.bill_total()
	c.history = [{"date": DateUtil.from_ymd(2015, 5, 1), "label": "Tonsillectomy", "condition": "hx_tonsils"}]
	return c


func _rules_of(c: Claim, day: int) -> Array[String]:
	var ids: Array[String] = []
	for v in RuleChecker.violations(c, day):
		ids.append(v["rule"])
	return ids


func test_clean_claim_has_no_violations() -> void:
	t.eq(RuleChecker.violations(_clean(), 7).size(), 0)
	t.ok(not RuleChecker.has_valid_reason(_clean(), 7))


func test_r01_lapsed_detected() -> void:
	var c := _clean()
	c.coverage_through = c.date_of_service - 1
	t.eq(_rules_of(c, 1), ["R-01"] as Array[String])
	t.ok(RuleChecker.check_citation(c, "R-01", "card.coverage_through", 1))
	t.ok(RuleChecker.check_citation(c, "R-01", "claim.date_of_service", 1))
	t.ok(not RuleChecker.check_citation(c, "R-01", "claim.name", 1))


func test_r01_coverage_ending_on_service_day_is_clean() -> void:
	var c := _clean()
	c.coverage_through = c.date_of_service
	t.eq(_rules_of(c, 7).size(), 0)


func test_r02_out_of_network() -> void:
	var c := _clean()
	c.provider = "Riverside Medical Center"
	t.eq(_rules_of(c, 2), ["R-02"] as Array[String])
	t.ok(RuleChecker.check_citation(c, "R-02", "claim.provider", 2))
	t.ok(RuleChecker.check_citation(c, "R-02", "bill.provider", 4))


func test_r03_name_typo() -> void:
	var c := _clean()
	c.name = "Maria Okafur"
	t.eq(_rules_of(c, 3), ["R-03"] as Array[String])
	t.ok(RuleChecker.check_citation(c, "R-03", "claim.name", 3))
	t.ok(RuleChecker.check_citation(c, "R-03", "card.name", 3))
	t.ok(not RuleChecker.check_citation(c, "R-03", "claim.member_id", 3))


func test_r03_member_id() -> void:
	var c := _clean()
	c.member_id = "BMH-483-2297"
	t.ok(RuleChecker.check_citation(c, "R-03", "card.member_id", 3))


func test_r03_dob() -> void:
	var c := _clean()
	c.dob += 2
	t.ok(RuleChecker.check_citation(c, "R-03", "claim.dob", 3))


func test_r04_missing_prior_auth() -> void:
	var c := _clean()
	c.bill_lines.append(Claim.make_line("mri_brain"))
	c.amount = c.bill_total()
	t.eq(_rules_of(c, 4), ["R-04"] as Array[String])
	t.ok(RuleChecker.check_citation(c, "R-04", "claim.prior_auth", 4))
	t.ok(RuleChecker.check_citation(c, "R-04", "bill.line.3", 4))
	t.ok(not RuleChecker.check_citation(c, "R-04", "bill.line.0", 4))
	c.prior_auth = "PA-55120"
	t.eq(_rules_of(c, 4).size(), 0, "prior auth on file")


func test_r04_needs_a_listed_procedure() -> void:
	var c := _clean()
	c.prior_auth = ""
	t.eq(_rules_of(c, 4).size(), 0, "blank prior auth without a listed procedure is fine")


func test_r05_pre_existing_before_member_since() -> void:
	var c := _clean()
	c.condition = "asthma"
	c.history.append({"date": c.member_since - 90, "label": "Asthma", "condition": "asthma"})
	t.eq(_rules_of(c, 5), ["R-05"] as Array[String])
	t.ok(RuleChecker.check_citation(c, "R-05", "history.entry.1", 5))
	t.ok(not RuleChecker.check_citation(c, "R-05", "history.entry.0", 5))


func test_r05_diagnosed_after_enrollment_is_clean() -> void:
	var c := _clean()
	c.condition = "asthma"
	c.history.append({"date": c.member_since + 90, "label": "Asthma", "condition": "asthma"})
	t.eq(_rules_of(c, 5).size(), 0)


func test_r06_excluded_line() -> void:
	var c := _clean()
	c.bill_lines.append(Claim.make_line("massage"))
	c.amount = c.bill_total()
	t.eq(_rules_of(c, 6), ["R-06"] as Array[String])
	t.ok(RuleChecker.check_citation(c, "R-06", "bill.line.3", 6))


func test_rules_locked_before_their_day() -> void:
	var c := _clean()
	c.provider = "Riverside Medical Center"
	t.eq(_rules_of(c, 1).size(), 0, "R-02 locked on day 1")
	t.ok(not RuleChecker.check_citation(c, "R-02", "claim.provider", 1))


func test_denybot_only_day_seven() -> void:
	var c := _clean()
	t.ok(RuleChecker.check_citation(c, "R-07", "denybot", 7))
	t.ok(not RuleChecker.check_citation(c, "R-07", "denybot", 6))
	t.ok(not RuleChecker.check_citation(c, "R-07", "claim.name", 7))
	t.ok(not RuleChecker.has_valid_reason(c, 7), "DenyBot is never a valid reason on its own")
