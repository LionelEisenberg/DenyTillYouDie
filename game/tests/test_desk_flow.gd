extends RefCounted

var t: TestContext
var gs: Node
var desk: DeskScreen
var tree: SceneTree


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	gs.save_path_override = TestContext.save_path()
	gs.new_run("Pat Doe", 77)
	desk = DeskScreen.new()
	desk.fast = true
	tree.root.add_child(desk)
	await tree.process_frame


func after_each() -> void:
	Engine.set_meta("reduce_motion", false)
	desk.queue_free()
	await tree.process_frame
	gs.delete_save()
	gs.save_path_override = ""


## Calls patients (approving the ones skipped) until one has a citable violation.
func _next_violating() -> Claim:
	while true:
		desk.call_next_patient()
		var c := desk.active_claim()
		if c == null:
			return null
		if RuleChecker.has_valid_reason(c, desk.day):
			return c
		await desk.stamp(true)
	return null


func test_stamp_ignored_without_active_claim() -> void:
	await desk.stamp(false)
	t.eq(gs.run.stats["processed"], 0)
	t.ok(desk.active_claim() == null)


func test_double_stamp_is_ignored() -> void:
	desk.call_next_patient()
	await desk.stamp(true)
	await desk.stamp(false)
	t.eq(gs.run.stats["processed"], 1)
	t.eq(gs.run.stats["approved"], 1)


func test_valid_citation_then_deny_records_cited() -> void:
	var c: Claim = await _next_violating()
	t.ok(c != null, "found a violating claim")
	var v: Dictionary = RuleChecker.violations(c, desk.day)[0]
	t.ok(desk.try_cite(v["rule"], (v["evidence"] as PackedStringArray)[0]), "valid citation")
	t.eq(desk.cited_rule, v["rule"])
	await desk.stamp(false)
	t.eq(gs.run.stats["cited"], 1)
	t.eq(gs.run.stats["blind"], 0)


func test_invalid_citation_charges_fee() -> void:
	desk.training_enabled = false
	desk.call_next_patient()
	var before: int = gs.pay_so_far()
	t.ok(not desk.try_cite("R-01", "claim.claim_no"))
	t.eq(gs.pay_so_far(), before - Economy.COMPLIANCE_FEE)
	t.eq(desk.cited_rule, "")


func test_citation_persists_until_stamp() -> void:
	var c: Claim = await _next_violating()
	var v: Dictionary = RuleChecker.violations(c, desk.day)[0]
	desk.try_cite(v["rule"], (v["evidence"] as PackedStringArray)[0])
	desk.try_cite("R-01", "claim.claim_no")
	t.eq(desk.cited_rule, v["rule"], "a later miss doesn't erase the citation")
	await desk.stamp(false)
	t.eq(gs.run.stats["cited"], 1)


func test_day_ends_after_last_patient() -> void:
	var finished := [false]
	desk.done.connect(func(_p: Dictionary) -> void: finished[0] = true)
	for i in desk.claims.size():
		desk.call_next_patient()
		await desk.stamp(true)
	t.ok(desk.end_shift_ready())
	t.ok(not finished[0], "waits for END SHIFT")
	desk.call_next_patient()
	t.ok(finished[0], "END SHIFT finishes the screen")
	t.eq(gs.run.stats["processed"], desk.claims.size())


func test_space_cannot_press_a_stamp() -> void:
	desk.call_next_patient()
	for b: Button in [desk._approve_button, desk._deny_button, desk._next_button, desk._inspect_button]:
		t.eq(b.focus_mode, Control.FOCUS_NONE, "%s takes no keyboard focus" % b.text)
	var space := InputEventAction.new()
	space.action = "inspect_toggle"
	space.pressed = true
	tree.root.push_input(space)
	await tree.process_frame
	t.ok(desk.inspect, "Space toggles inspect")
	t.ok(desk.active_claim() != null, "and stamps nothing")


func _desk_on_day(day: int) -> void:
	gs.run.day = day
	desk.queue_free()
	desk = DeskScreen.new()
	desk.fast = true
	tree.root.add_child(desk)
	await tree.process_frame


func test_clicking_r07_runs_denybot() -> void:
	await _desk_on_day(7)
	desk.call_next_patient()
	desk._set_inspect(true)
	var row := desk._rulebook.find_rule_row("R-07")
	desk._on_rule_clicked("R-07", row)
	t.eq(desk.cited_rule, "R-07", "R-07 click cites DenyBot")
	t.eq(gs.run.today["fees"], 0, "and charges no compliance fee")


func test_a_miss_after_a_citation_keeps_the_red_marks() -> void:
	var c: Claim = await _next_violating()
	var v: Dictionary = RuleChecker.violations(c, desk.day)[0]
	var key: String = (v["evidence"] as PackedStringArray)[0]
	desk.try_cite(v["rule"], key)
	var key_row := desk._find_evidence_row(key)
	desk.try_cite("R-01" if v["rule"] != "R-01" else "R-02", key)
	await tree.process_frame
	t.eq(key_row.get_mark(), FieldRow.Mark.VALID, "cited evidence stays marked after the miss")
	t.eq(desk.cited_rule, v["rule"])


func test_inspect_opens_the_rules_page() -> void:
	gs.run.day = 2
	desk.queue_free()
	desk = DeskScreen.new()
	desk.fast = true
	tree.root.add_child(desk)
	await tree.process_frame
	desk.call_next_patient()
	desk._rulebook.show_page("NETWORK")
	desk._set_inspect(true)
	t.ok(desk._rulebook.find_rule_row("R-01").is_visible_in_tree(), "rule rows visible while inspecting")


func test_next_patient_requires_a_stamp() -> void:
	desk.call_next_patient()
	var first := desk.active_claim()
	desk.call_next_patient()
	t.ok(desk.active_claim() == first, "can't skip an unstamped patient")


## Waits (in real time) until `condition` holds or `seconds` pass.
func _until(condition: Callable, seconds: float = 4.0) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await tree.process_frame


func test_denybot_drops_a_half_made_selection() -> void:
	await _desk_on_day(7)
	desk.call_next_patient()
	desk._set_inspect(true)
	desk._on_rule_clicked("R-01", desk._rulebook.find_rule_row("R-01"))
	t.eq(desk._sel_rule, "R-01", "a rule is picked")
	desk._rulebook.show_page("DENYBOT")
	desk._rulebook.denybot_button.pressed.emit()
	await tree.process_frame
	t.eq(desk.cited_rule, "R-07", "DenyBot cites")
	t.ok(not desk.inspect, "inspect mode ends")
	t.eq(desk._sel_rule, "", "the picked rule is dropped")
	t.ok(desk._sel_rule_row == null, "no selected row left behind")
	# A later click on a paper can't pair with the forgotten rule.
	desk._on_evidence_clicked("claim.claim_no", desk._find_evidence_row("claim.claim_no"))
	t.eq(desk.cited_rule, "R-07", "citation unchanged")
	t.eq(gs.run.today["fees"], 0, "no compliance fee")


func test_manual_citation_during_denybot_analysis_stands() -> void:
	await _desk_on_day(7)
	var c: Claim = await _next_violating()
	t.ok(c != null, "found a violating claim")
	var v: Dictionary = RuleChecker.violations(c, desk.day)[0]
	desk.fast = false
	desk._on_denybot_pressed()
	desk.fast = true
	t.eq(desk._rulebook.denybot_text(), DeskScreen.DENYBOT_ANALYZING, "DenyBot is thinking")
	t.ok(desk.try_cite(v["rule"], (v["evidence"] as PackedStringArray)[0]), "the player cites by hand meanwhile")
	await tree.create_timer(1.0).timeout
	t.eq(desk.cited_rule, v["rule"], "DenyBot's late verdict doesn't overwrite the citation")
	t.eq(desk._rulebook.denybot_text(), "", "and ANALYZING... is cleared")
	t.eq(desk._deny_button.text, "DENY (%s)" % v["rule"])


func test_stamping_during_denybot_analysis_clears_it() -> void:
	await _desk_on_day(7)
	desk.call_next_patient()
	desk.fast = false
	desk._on_denybot_pressed()
	desk.fast = true
	await desk.stamp(false)
	await tree.create_timer(1.0).timeout
	t.eq(desk._rulebook.denybot_text(), "", "no ANALYZING... left on a stamped claim")
	t.eq(desk.cited_rule, "", "and no citation after the fact")


func test_pressing_denybot_twice_keeps_the_verdict() -> void:
	await _desk_on_day(7)
	desk.call_next_patient()
	desk.fast = false
	desk._on_denybot_pressed()
	desk._on_denybot_pressed()
	desk.fast = true
	await tree.create_timer(1.0).timeout
	t.eq(desk.cited_rule, "R-07")
	t.eq(desk._rulebook.denybot_text(), DeskScreen.DENYBOT_VERDICT, "the second run doesn't blank the first one's verdict")


func test_picking_away_from_a_cited_row_keeps_it_red() -> void:
	var c: Claim = await _next_violating()
	var v: Dictionary = RuleChecker.violations(c, desk.day)[0]
	var key: String = (v["evidence"] as PackedStringArray)[0]
	t.ok(desk.try_cite(v["rule"], key))
	var key_row := desk._find_evidence_row(key)
	var other := desk._find_evidence_row("claim.claim_no")
	desk._set_inspect(true)
	desk._on_evidence_clicked(key, key_row)
	t.eq(key_row.get_mark(), FieldRow.Mark.SELECTED, "the cited row is picked again")
	desk._on_evidence_clicked("claim.claim_no", other)
	t.eq(key_row.get_mark(), FieldRow.Mark.VALID, "picking another row puts it back to red, not blank")
	desk._set_inspect(false)
	t.eq(other.get_mark(), FieldRow.Mark.NONE, "an uncited row goes blank")
	t.eq(key_row.get_mark(), FieldRow.Mark.VALID)


func test_cancelling_inspect_keeps_the_citation_red() -> void:
	var c: Claim = await _next_violating()
	var v: Dictionary = RuleChecker.violations(c, desk.day)[0]
	t.ok(desk.try_cite(v["rule"], (v["evidence"] as PackedStringArray)[0]))
	var rule_row := desk._rulebook.find_rule_row(v["rule"])
	desk._set_inspect(true)
	desk._on_rule_clicked(v["rule"], rule_row)
	t.eq(rule_row.get_mark(), FieldRow.Mark.SELECTED, "the cited rule is picked again")
	desk._set_inspect(false)
	t.eq(rule_row.get_mark(), FieldRow.Mark.VALID, "Esc leaves it red")
	t.eq(desk.cited_rule, v["rule"])


func test_a_fading_miss_leaves_a_fresh_pick_alone() -> void:
	desk.call_next_patient()
	desk._set_inspect(true)
	var rule_row := desk._rulebook.find_rule_row("R-01")
	var wrong := desk._find_evidence_row("claim.claim_no")
	desk.fast = false
	desk._on_rule_clicked("R-01", rule_row)
	desk._on_evidence_clicked("claim.claim_no", wrong)
	desk.fast = true
	t.eq(rule_row.get_mark(), FieldRow.Mark.INVALID, "a miss greys both rows")
	desk._on_rule_clicked("R-01", rule_row)
	await tree.create_timer(0.9).timeout
	t.eq(rule_row.get_mark(), FieldRow.Mark.SELECTED, "the rule picked again stays highlighted")
	t.eq(desk._sel_rule, "R-01", "and selected")
	t.eq(wrong.get_mark(), FieldRow.Mark.NONE, "the missed evidence clears")


func test_no_next_hint_while_next_is_disabled() -> void:
	# The generic NEXT! hint; the day-1 coach has its own say after a stamp.
	desk.training_enabled = false
	desk.call_next_patient()
	desk.fast = false
	desk.stamp(true)
	t.ok(desk._next_button.disabled, "NEXT! waits while the papers clear")
	t.eq(desk._hint_label.text, "", "so the hint doesn't point at it")
	await _until(func() -> bool: return not desk._next_button.disabled)
	t.ok(not desk._next_button.disabled, "NEXT! comes back")
	t.eq(desk._hint_label.text, "Press NEXT! for the next patient.", "and the hint with it")


func test_citation_link_is_clipped_to_the_desk() -> void:
	t.eq(desk._overlay.get_global_rect(), desk._desk.get_global_rect(), "the link layer covers exactly the desk")
	t.ok(desk._overlay.clip_contents, "and clips what it draws to it")


# --- day-1 training ------------------------------------------------------------

## A run seed whose first day-1 patient does (or doesn't) have a lapsed card.
## ClaimGenerator now opens every day 1 with the lapsed training claim, so only
## `true` finds one; _clean_first_desk() builds the other case.
func _seed_where(first_lapses: bool) -> int:
	for s in range(1, 500):
		var first: Claim = ClaimGenerator.new(s, "Pat Doe").generate_day(1)[0]
		var lapses := false
		for v in RuleChecker.violations(first, 1):
			lapses = lapses or v["rule"] == "R-01"
		if lapses == first_lapses and first.scripted_id == "":
			return s
	return -1


## A fresh day-1 desk whose first patient is clean. Day 1 always opens with the
## lapsed training claim and follows it with a clean one; they trade places.
func _clean_first_desk() -> void:
	await _training_desk(_seed_where(true))
	var lapsed := desk.claims[0]
	desk.claims[0] = desk.claims[1]
	desk.claims[1] = lapsed
	t.ok(RuleChecker.violations(desk.claims[0], 1).is_empty(), "the first patient is clean")


## A fresh day-1 desk for a run started with `seed_value`.
func _training_desk(seed_value: int) -> void:
	desk.queue_free()
	await tree.process_frame
	gs.new_run("Pat Doe", seed_value)
	desk = DeskScreen.new()
	desk.fast = true
	tree.root.add_child(desk)
	await tree.process_frame


func _coaching() -> bool:
	return desk._hint_label.text.begins_with("TRAINING") or not desk._coach.targets.is_empty()


func test_training_walks_a_lapsed_first_claim_through_a_citation() -> void:
	var s := _seed_where(true)
	t.ok(s > 0, "found a seed whose first patient's coverage lapsed")
	await _training_desk(s)
	desk.call_next_patient()
	var c := desk.active_claim()
	var through := DateUtil.fmt(c.coverage_through)
	var service := DateUtil.fmt(c.date_of_service)
	var dates: Array[Control] = [desk._find_evidence_row("card.coverage_through"), desk._find_evidence_row("claim.date_of_service")]
	t.eq(desk._hint_label.text, DeskScreen.COACH_CITE[0] % [through, service], "step 1: the dates, then INSPECT")
	t.eq(desk._coach.targets, dates + ([desk._inspect_button] as Array[Control]), "pulsing both dates and INSPECT")
	desk._set_inspect(true)
	t.eq(desk._hint_label.text, DeskScreen.COACH_CITE[1], "step 2: click R-01")
	t.eq(desk._coach.targets, [desk._rulebook.find_rule_row("R-01")] as Array[Control], "pulsing the R-01 row")
	desk._on_rule_clicked("R-01", desk._rulebook.find_rule_row("R-01"))
	t.eq(desk._hint_label.text, DeskScreen.COACH_CITE[2], "step 3: click the date")
	t.eq(desk._coach.targets, dates, "pulsing the dates")
	t.ok(desk.try_cite("R-01", "card.coverage_through"), "the citation holds")
	t.eq(desk._hint_label.text, DeskScreen.COACH_CITE[3], "step 4: stamp DENY")
	t.eq(desk._coach.targets, [desk._deny_button] as Array[Control], "pulsing DENY")
	await desk.stamp(false)
	t.eq(gs.run.stats["cited"], 1, "a cited denial")
	t.eq(desk._hint_label.text, "Press NEXT! for the next patient.", "a right call needs no comment")


## Patient 1 is the lapsed training claim; patient 2 is always clean.
func test_training_approve_path_and_completion() -> void:
	await _training_desk(_seed_where(true))
	desk.call_next_patient()
	t.ok(desk.try_cite("R-01", "card.coverage_through"), "patient 1's lapse, cited")
	await desk.stamp(false)
	desk.call_next_patient()
	var c := desk.active_claim()
	t.ok(RuleChecker.violations(c, 1).is_empty(), "patient 2 is clean")
	t.ok(_coaching(), "the second patient is coached too")
	t.eq(desk._hint_label.text, DeskScreen.COACH_APPROVE % [DateUtil.fmt(c.coverage_through), DateUtil.fmt(c.date_of_service)], "nothing to cite")
	t.ok(desk._coach.targets.has(desk._approve_button), "APPROVE pulses")
	await desk.stamp(true)
	t.eq(desk._hint_label.text, DeskScreen.COACH_DONE, "training complete after patient 2")
	t.ok(not desk._skip_training.visible, "SKIP TRAINING is gone")
	desk.call_next_patient()
	t.ok(not _coaching(), "and the coach is off for patient 3")


func test_training_says_what_a_wrong_stamp_did() -> void:
	var s := _seed_where(true)
	await _training_desk(s)
	desk.call_next_patient()
	await desk.stamp(false)
	t.eq(desk._hint_label.text, DeskScreen.COACH_UNCITED, "an uncited denial of the lapsed claim")
	await _training_desk(s)
	desk.call_next_patient()
	await desk.stamp(true)
	t.eq(desk._hint_label.text, DeskScreen.COACH_MISSED, "approving the lapsed claim")
	t.eq(gs.run.today["warnings"], 1, "which earned a citation")
	await _clean_first_desk()
	desk.call_next_patient()
	await desk.stamp(false)
	t.eq(desk._hint_label.text, DeskScreen.COACH_UNCITED_CLEAN, "an uncited denial of a clean claim")


func test_a_training_miss_points_the_coach_back_at_the_rule() -> void:
	await _training_desk(_seed_where(true))
	desk.call_next_patient()
	desk._set_inspect(true)
	var r01 := desk._rulebook.find_rule_row("R-01")
	desk._on_rule_clicked("R-01", r01)
	t.eq(desk._hint_label.text, DeskScreen.COACH_CITE[2], "R-01 picked: now the date")
	desk.fast = false
	desk._on_evidence_clicked("claim.claim_no", desk._find_evidence_row("claim.claim_no"))
	t.eq(desk._hint_label.text, DeskScreen.COACH_MISS, "the miss is named")
	t.eq(desk._sel_rule, "", "and it dropped the rule picked")
	t.eq(desk._coach.targets, [r01] as Array[Control], "so the pulse goes back to R-01 at once")
	await _until(func() -> bool: return desk._hint_label.text != DeskScreen.COACH_MISS, 2.0)
	t.eq(desk._hint_label.text, DeskScreen.COACH_CITE[1], "then the coach asks for R-01 again")
	desk.fast = true
	desk._on_rule_clicked("R-01", r01)
	t.ok(desk.try_cite("R-01", "card.coverage_through"), "and the citation goes through")
	t.eq(desk._hint_label.text, DeskScreen.COACH_CITE[3])


func test_a_training_miss_is_free_but_a_later_one_costs() -> void:
	await _training_desk(_seed_where(true))
	desk.call_next_patient()
	var before: int = gs.pay_so_far()
	t.ok(not desk.try_cite("R-01", "claim.claim_no"), "a miss")
	t.eq(gs.pay_so_far(), before, "costs nothing on patient 1")
	t.eq(gs.run.today["fees"], 0)
	t.eq(desk._hint_label.text, DeskScreen.COACH_MISS)
	await desk.stamp(true)
	desk.call_next_patient()
	await desk.stamp(true)
	desk.call_next_patient()
	t.eq(desk.index, 2, "patient 3")
	before = gs.pay_so_far()
	t.ok(not desk.try_cite("R-01", "claim.claim_no"), "another miss")
	t.eq(gs.pay_so_far(), before - Economy.COMPLIANCE_FEE, "costs the fee on patient 3")


func test_skip_training_ends_it_at_once() -> void:
	await _training_desk(_seed_where(true))
	t.ok(desk._skip_training.visible, "offered before the first patient")
	desk.call_next_patient()
	t.ok(_coaching(), "coaching")
	t.eq(desk._skip_training.focus_mode, Control.FOCUS_NONE, "takes no focus")
	t.ok(desk._skip_training.get_meta("silent", false), "and makes no clack")
	t.eq(desk._skip_training.get_theme_font_size("font_size"), UiTheme.SIZE_SMALL)
	desk._skip_training.pressed.emit()
	t.ok(not _coaching(), "the coach goes quiet: %s" % desk._hint_label.text)
	t.ok(not desk._skip_training.visible, "the button goes")
	var before: int = gs.pay_so_far()
	desk.try_cite("R-01", "claim.claim_no")
	t.eq(gs.pay_so_far(), before - Economy.COMPLIANCE_FEE, "misses cost again")


func test_no_coach_for_walt_on_day_2_or_when_disabled() -> void:
	await _training_desk(_seed_where(true))
	var walt_at := -1
	for i in desk.claims.size():
		if desk.claims[i].scripted_id == "walt":
			walt_at = i
	t.ok(walt_at > 1, "Walt comes after the training patients")
	var walt := desk.claims[walt_at]
	desk.claims[walt_at] = desk.claims[0]
	desk.claims[0] = walt
	desk.call_next_patient()
	t.eq(desk.active_claim().scripted_id, "walt", "Walt first, to be sure")
	t.ok(not _coaching(), "no coach on a scripted case")
	await _desk_on_day(2)
	desk.call_next_patient()
	t.ok(not _coaching(), "none on day 2")
	t.ok(not desk._skip_training.visible)
	await _training_desk(_seed_where(true))
	desk.training_enabled = false
	desk.call_next_patient()
	t.ok(not _coaching(), "none when training is off")
	t.eq(desk._hint_label.text, DeskScreen.DAY_HINTS[1], "the plain day-1 hint instead")
	await desk.stamp(true)
	desk.call_next_patient()
	t.eq(desk._hint_label.text, DeskScreen.WARNINGS_HINT, "and the warnings hint after the first stamp")


func test_hints_are_body_size_and_fit_the_strip() -> void:
	t.eq(desk._hint_label.get_theme_font_size("font_size"), UiTheme.SIZE_BODY, "24 px hints")
	var date := "12/31/2026"
	var lines: PackedStringArray = DeskScreen.DAY_HINTS.duplicate()
	lines.append_array([DeskScreen.COACH_CITE[0] % [date, date], DeskScreen.COACH_CITE[1], DeskScreen.COACH_CITE[2], DeskScreen.COACH_CITE[3]])
	lines.append_array([DeskScreen.COACH_APPROVE % [date, date], DeskScreen.COACH_MISS, DeskScreen.COACH_UNCITED, DeskScreen.COACH_UNCITED_CLEAN])
	lines.append_array([DeskScreen.COACH_MISSED, DeskScreen.COACH_DONE, DeskScreen.WARNINGS_HINT])
	for line in lines:
		t.ok(line.length() <= 100, "%d characters: %s" % [line.length(), line])


# --- the stamp -----------------------------------------------------------------

## Waits (in real time, which a hitstop can't freeze) until `condition` holds.
func _until_real(condition: Callable, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await tree.process_frame


func test_time_runs_again_after_a_real_stamp() -> void:
	desk.training_enabled = false
	desk.call_next_patient()
	desk.fast = false
	desk.stamp(true)
	var froze := [false]
	await _until_real(func() -> bool:
		froze[0] = froze[0] or Engine.time_scale == 0.0
		return not desk._next_button.disabled, 6.0)
	t.ok(froze[0], "the impact froze time for a beat")
	t.eq(Engine.time_scale, 1.0, "and time runs again")
	t.ok(not desk._next_button.disabled, "the stamp finished")
	desk.fast = true


func test_time_runs_again_when_the_desk_goes_mid_stamp() -> void:
	desk.call_next_patient()
	desk.fast = false
	desk.stamp(true)
	await _until_real(func() -> bool: return false, 0.02)
	desk.queue_free()
	await tree.process_frame
	await _until_real(func() -> bool: return false, 0.15)
	t.eq(Engine.time_scale, 1.0, "freed 20 ms into the stamp")
	# Now catch the freeze itself and free the desk inside it.
	desk = DeskScreen.new()
	desk.fast = true
	tree.root.add_child(desk)
	await tree.process_frame
	desk.call_next_patient()
	desk.fast = false
	desk.stamp(true)
	await _until_real(func() -> bool: return Engine.time_scale == 0.0, 3.0)
	t.eq(Engine.time_scale, 0.0, "caught mid-hitstop")
	desk.queue_free()
	await tree.process_frame
	await _until_real(func() -> bool: return Engine.time_scale == 1.0, 0.5)
	t.eq(Engine.time_scale, 1.0, "time comes back with the desk gone")
	desk = DeskScreen.new()
	desk.fast = true
	tree.root.add_child(desk)
	await tree.process_frame


func test_moving_on_mid_flight_drops_the_impression() -> void:
	desk.training_enabled = false
	desk.call_next_patient()
	desk.fast = false
	desk.stamp(true)
	desk.fast = true
	desk.call_next_patient()
	var second := desk.active_claim()
	t.ok(second != null and desk.index == 1, "the next patient, called while the stamp flew")
	await _until_real(func() -> bool: return false, 0.6)
	t.ok(desk.active_claim() == second, "is still waiting")
	t.ok(desk._last_mark == null, "with no stray impression on their papers")
	t.ok(desk._approve_tool.visible, "the stamp is back in the tray")
	t.eq(gs.run.stats["processed"], 1, "the first decision stands")
	t.eq(Engine.time_scale, 1.0)


func test_the_stamp_round_trip_stays_under_half_a_second() -> void:
	var trip := DeskScreen.STAMP_FLY + DeskScreen.STAMP_HOVER + DeskScreen.STAMP_DROP + DeskScreen.HITSTOP + DeskScreen.STAMP_RETURN
	t.ok(trip < 0.5, "fly, hover, drop, hit and return: %.2f s" % trip)


## A stamp impression that notes what it letters instead of drawing it.
class RecordingMark extends StampMark:
	var lettered: Array[Dictionary] = []

	func _letter(text: String, at: Vector2, font_size: int, color: Color) -> void:
		lettered.append({"text": text, "at": at, "size": font_size, "alpha": color.a})


func test_the_reason_code_prints_once_and_whole() -> void:
	var mark := RecordingMark.new()
	mark.word = "DENIED"
	mark.code = DeskScreen.UNCITED_CODE
	mark.size = Vector2(300, 112)
	tree.root.add_child(mark)
	await tree.process_frame
	await tree.process_frame
	var codes := mark.lettered.filter(func(l: Dictionary) -> bool: return l["text"] == mark.code)
	var words := mark.lettered.filter(func(l: Dictionary) -> bool: return l["text"] == mark.word)
	t.eq(words.size(), 2, "the word gets its faint double strike")
	t.eq(codes.size(), 1, "the small code is printed once, by the main strike alone")
	if codes.size() == 1:
		t.near(codes[0]["alpha"], 0.85, 0.001, "at full ink")
		var font := UiTheme.font()
		var at: Vector2 = codes[0]["at"]
		var ascent := font.get_ascent(UiTheme.SIZE_SMALL)
		var box := Rect2(at.x, at.y - ascent, font.get_string_size(mark.code, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x, ascent + font.get_descent(UiTheme.SIZE_SMALL))
		t.ok(mark.code_band().encloses(box), "no dry specks inside the code: %s holds %s" % [mark.code_band(), box])
	var band: Vector4 = (mark.material as ShaderMaterial).get_shader_parameter("keep_band")
	t.eq(Rect2(band.x, band.y, band.z, band.w), mark.code_band(), "the ink shader spares that band")
	mark.free()
	t.ok(StampMark.SPECK_CELL <= 2.0, "specks a couple of pixels wide")
	t.ok(StampMark.SPECK_RATE + StampMark.DRY_RATE <= 0.1, "and rare enough not to cut a 48 px letter in two")
	var approval := StampMark.create(true, "")
	t.eq(approval.code_band(), Rect2(), "an approval has no code to spare")
	approval.free()


func test_an_uncited_denial_says_so_on_the_stamp() -> void:
	desk.training_enabled = false
	desk.call_next_patient()
	await desk.stamp(false)
	t.ok(desk._last_mark != null, "an impression on the claim form")
	t.eq(desk._last_mark.code, "REASON: NOT STATED")
	t.eq(desk._last_mark.word, "DENIED")
	t.near(desk._last_mark.scale.x, 1.0, 0.001, "at full size, no scale-in")
	t.near(desk._last_mark.modulate.a, 1.0, 0.001, "and full ink")


func test_stamps_are_tools_inside_real_buttons() -> void:
	for b: Button in [desk._approve_button, desk._deny_button]:
		var tool := b.get_child(0) as StampTool
		t.ok(tool != null, "%s holds a StampTool" % b.text)
		t.eq(tool.mouse_filter, Control.MOUSE_FILTER_IGNORE, "which lets clicks through")
		t.ok(b.get_meta("silent", false), "the button makes no clack of its own")
		t.eq(b.size, DeskScreen.STAMP_SIZE)
	var c: Claim = await _next_violating()
	var v: Dictionary = RuleChecker.violations(c, desk.day)[0]
	t.eq(desk._deny_tool.tag, "", "no tag before a citation")
	desk.try_cite(v["rule"], (v["evidence"] as PackedStringArray)[0])
	t.eq(desk._deny_tool.tag, v["rule"], "the cited rule hangs on DENIED")


# --- prices, HUD and keys --------------------------------------------------------

## A day-1 claim reshaped for one cell of the stamp price table.
func _priced_claim(priority: int, child: bool, lapsed: bool) -> Claim:
	var c: Claim = ClaimGenerator.new(5, "Pat Doe").generate_day(1)[0]
	c.priority = priority
	c.age = 8 if child else 40
	c.parent_speaks = child
	c.coverage_through = c.date_of_service + (-5 if lapsed else 100)
	return c


func test_stamp_preview_matches_shift_logic() -> void:
	var cells := 0
	for priority in 3:
		for child: bool in [false, true]:
			for protest: bool in [false, true]:
				for compassion: bool in [false, true]:
					for citation: String in ["", "R-01", "R-07"]:
						for approve: bool in [true, false]:
							var c := _priced_claim(priority, child, citation == "R-01")
							var effects := {"protest": protest, "audit": false, "compassion": compassion}
							var cited := "" if approve else citation
							var run := RunState.create("Pat Doe", 1)
							run.day = 7
							run.effects = effects.duplicate()
							var expected := ShiftLogic.apply_decision(run, c, approve, cited)
							var got := DeskScreen.stamp_preview(c, approve, cited, effects, 7)
							var cell := "p%d child=%s protest=%s compassion=%s cited=%s approve=%s" % [priority, child, protest, compassion, cited, approve]
							t.eq(got["pay"], expected["pay"], "pay, " + cell)
							t.near(got["discontent"], expected["discontent"], 0.0001, "discontent, " + cell)
							cells += 1
	t.eq(cells, 144, "every combination")


func test_price_lines_follow_the_citation() -> void:
	t.eq(desk._approve_price.text, "", "no prices before the first patient")
	var c: Claim = await _next_violating()
	var effects: Dictionary = gs.run.effects
	var approve := DeskScreen.stamp_preview(c, true, "", effects, desk.day)
	t.eq(desk._approve_price.text, "PAY %s   DISCONTENT -%s%%" % [Fmt.signed_money(approve["pay"]), desk._fmt_points(-approve["discontent"])])
	var uncited := desk._deny_price.text
	t.ok(uncited.contains(" UNCITED"), "an uncited denial says so: %s" % uncited)
	var v: Dictionary = RuleChecker.violations(c, desk.day)[0]
	desk.try_cite(v["rule"], (v["evidence"] as PackedStringArray)[0])
	var deny := DeskScreen.stamp_preview(c, false, v["rule"], effects, desk.day)
	t.ok(desk._deny_price.text != uncited, "the price changes with the citation")
	t.eq(desk._deny_price.text, "PAY %s   DISCONTENT +%s%%" % [Fmt.signed_money(deny["pay"]), desk._fmt_points(deny["discontent"])])
	t.eq(desk._deny_price.get_theme_font_size("font_size"), UiTheme.SIZE_SMALL, "16 px")


func test_compassion_day_prices_and_tags() -> void:
	gs.run.effects["compassion"] = true
	await _desk_on_day(3)
	desk.call_next_patient()
	t.ok(desk._approve_price.text.begins_with("PAY $0   "), "approvals are free: %s" % desk._approve_price.text)
	t.eq(desk._approve_tool.tag, "FREE", "a FREE tag hangs on APPROVED")
	t.eq(desk._warnings_label.text, "NO CITATIONS TODAY")


## A real key press and release.
func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		tree.root.push_input(e)


func test_enter_and_n_press_next_only_when_it_is_live() -> void:
	desk.training_enabled = false
	t.eq(desk._next_button.text, "NEXT! (ENTER)")
	_key(KEY_ENTER)
	_key(KEY_N)
	await tree.process_frame
	t.ok(desk.active_claim() == null and desk.index == -1, "nothing while Main is still fading the desk in")
	desk.on_shown()
	_key(KEY_ENTER)
	await tree.process_frame
	var first := desk.active_claim()
	t.ok(first != null, "Enter calls the first patient")
	_key(KEY_ENTER)
	_key(KEY_KP_ENTER)
	_key(KEY_N)
	await tree.process_frame
	t.ok(desk.active_claim() == first, "and does nothing while the claim is open")
	await desk.stamp(true)
	_key(KEY_KP_ENTER)
	await tree.process_frame
	var second := desk.active_claim()
	t.ok(second != null and second != first, "keypad Enter calls the next one after the stamp")
	await desk.stamp(true)
	_key(KEY_N)
	await tree.process_frame
	t.ok(desk.active_claim() != null and desk.active_claim() != second, "so does N")


func test_warnings_line_counts_down() -> void:
	desk.training_enabled = false
	t.eq(desk._warnings_label.text, "WARNINGS LEFT TODAY: 2", "after no citations")
	t.eq(desk._warnings_label.get_theme_font_size("font_size"), UiTheme.SIZE_SMALL)
	await _next_violating()
	await desk.stamp(true)
	t.eq(gs.run.today["warnings"], 1, "one citation")
	t.eq(desk._warnings_label.text, "WARNINGS LEFT TODAY: 1", "after one citation")
	for warnings in [2, 3]:
		gs.run.today["warnings"] = warnings
		desk._update_hud(false)
		t.eq(desk._warnings_label.text, "NEXT CITATION: -$5", "after %d citations" % warnings)


func test_target_line_only_with_a_target() -> void:
	desk.training_enabled = false
	desk.call_next_patient()
	await desk.stamp(false)
	t.ok(not desk._target_label.visible, "no target_pct, no target line")
	gs.run.today["target_pct"] = 60
	desk.call_next_patient()
	await desk.stamp(false)
	t.ok(desk._target_label.visible, "a target shows")
	t.eq(desk._target_label.text, "TARGET 60%: 2 OF 2 DENIED")
	t.eq(desk._target_label.get_theme_color("font_color"), Palette.AMBER, "in amber once met")
	desk.call_next_patient()
	await desk.stamp(true)
	desk.call_next_patient()
	await desk.stamp(true)
	t.eq(desk._target_label.text, "TARGET 60%: 2 OF 4 DENIED", "counting processed claims only")
	t.eq(desk._target_label.get_theme_color("font_color"), Palette.TEXT_DIM, "dim while short of it")


func test_saved_counter_sums_the_denied_amounts() -> void:
	desk.training_enabled = false
	t.eq(desk._saved_label.text, "$0")
	var expected := 0
	for i in desk.claims.size():
		desk.call_next_patient()
		var deny := i % 2 == 0
		if deny:
			expected += desk.active_claim().amount
		await desk.stamp(not deny)
	t.ok(expected > 0, "something was denied")
	t.eq(desk.saved_today, expected, "the sum of denied amounts")
	t.eq(desk._saved_label.text, Fmt.money(expected))


func test_effects_line_explains_itself() -> void:
	gs.run.effects["protest"] = true
	await _desk_on_day(3)
	t.ok(desk._effects_label.text.contains("PROTEST OUTSIDE"))
	t.ok(desk._effects_label.tooltip_text.contains("PROTEST OUTSIDE:"), "the tooltip names the effect")
	t.ok(desk._effects_label.mouse_filter != Control.MOUSE_FILTER_IGNORE, "and can be hovered")
	t.ok(not desk._effects_label.text.contains("BOARD REVIEW"), "no board review at low discontent")
	gs.run.discontent = 91.0
	desk._update_hud(true)
	t.ok(desk._effects_label.text.ends_with("BOARD REVIEW AT 100%"), "board review at 90%%: %s" % desk._effects_label.text)


func test_the_effects_line_never_reaches_the_discontent_caption() -> void:
	await _desk_on_day(5)
	var caption: Label
	for child in desk.get_children():
		if child is Label and (child as Label).text == "DISCONTENT":
			caption = child
	t.ok(caption != null, "the DISCONTENT caption")
	for mask in 16:
		gs.run.effects = {"protest": mask & 1 != 0, "audit": mask & 2 != 0, "compassion": mask & 4 != 0}
		gs.run.discontent = 95.0 if mask & 8 != 0 else 20.0
		desk._update_hud(true)
		var label := desk._effects_label
		var size := label.get_theme_font_size("font_size")
		var width := UiTheme.font().get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		t.ok(width <= DeskScreen.EFFECTS_WIDTH and label.position.x + width < caption.position.x, "fits (%s at %d px, %d px wide)" % [label.text, size, width])
		t.ok(size == UiTheme.SIZE_BODY or size == UiTheme.SIZE_SMALL)
	t.eq(desk._effects_label.text, "PROTEST  AUDIT  COMPASSION  REVIEW AT 100%", "everything at once: short names")
	t.eq(desk._effects_label.get_theme_font_size("font_size"), UiTheme.SIZE_BODY, "in body type, since they fit")
	for full: String in ["PROTEST OUTSIDE:", "AUDIT IN PROGRESS:", "COMPASSION DAY:", "BOARD REVIEW AT 100%:"]:
		t.ok(desk._effects_label.tooltip_text.contains(full), "the tooltip keeps %s" % full)
	gs.run.effects = {"protest": true, "audit": false, "compassion": false}
	gs.run.discontent = 20.0
	desk._update_hud(true)
	t.eq(desk._effects_label.text, "PROTEST OUTSIDE", "one event keeps its full name")
	t.eq(desk._effects_label.get_theme_font_size("font_size"), UiTheme.SIZE_BODY, "in body type")


func test_the_citation_printer_sounds_in_every_mode() -> void:
	# Needs an Sfx that reports what it plays (the sound workstream's has a
	# `played` signal); without one, only the slip is checked.
	var sfx := tree.root.get_node("Sfx")
	var heard: Array[String] = []
	var listen := func(sound_name: String) -> void: heard.append(sound_name)
	var reports := sfx.has_signal("played")
	if reports:
		sfx.connect("played", listen)
	for reduce: bool in [false, true]:
		Engine.set_meta("reduce_motion", reduce)
		await _desk_on_day(2)
		desk.training_enabled = false
		var c: Claim = await _next_violating()
		t.ok(c != null, "a claim with grounds")
		desk.fast = not reduce
		heard.clear()
		desk.stamp(true)
		t.ok(desk._docs.size() > 0 and desk._docs[desk._docs.size() - 1].rotation_degrees == -3.0, "the slip prints (reduce motion: %s)" % reduce)
		if reports:
			t.ok(heard.has("printer"), "with the printer's chatter (reduce motion: %s): %s" % [reduce, heard])
		desk.fast = true
		await _until(func() -> bool: return not desk._next_button.disabled, 4.0)
	if reports:
		sfx.disconnect("played", listen)


func test_inspect_dims_the_booth() -> void:
	desk.call_next_patient()
	t.eq(desk._booth_shade.color.a, 0.0)
	desk._set_inspect(true)
	t.near(desk._booth_shade.color.a, 0.25, 0.001, "a quarter darker while inspecting")
	desk._set_inspect(false)
	t.eq(desk._booth_shade.color.a, 0.0)


func test_wired_hooks() -> void:
	t.eq(Rect2(desk._badge_slot.position, desk._badge_slot.size), Rect2(16, 976, 280, 96), "the badge slot")
	t.ok(desk._badge_slot.get_child(0) is IdBadge, "the slot holds the staff badge")
	t.eq(desk._desk.get_child(0), desk._desk_underlay, "the underlay is the desk's first child")
	t.eq(desk._desk_underlay.size, DeskScreen.DESK_SIZE)
	t.eq(desk._desk_underlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	t.ok(desk._desk_underlay.get_child(0) is DeskProps, "the props lie under every paper")
	desk.call_next_patient()
	var c := desk.active_claim()
	t.eq(desk._extra_documents(c).size(), 0, "a random patient brings no exhibit")
	t.ok(c.reaction_approved != "" and c.reaction_denied != "", "a random patient comes with reactions")
	t.eq(desk._reaction_line(true, false), c.reaction_approved, "says its own approval line")
	t.eq(desk._reaction_line(false, false), c.reaction_denied, "says its own denial line")
	var with_exhibit: Claim = null
	for claim in desk.claims:
		if not claim.exhibit.is_empty():
			with_exhibit = claim
			break
	t.ok(with_exhibit != null and with_exhibit.scripted_id != "", "a scripted case brings an exhibit on day 1")
	if with_exhibit:
		var docs := desk._extra_documents(with_exhibit)
		t.eq(docs.size(), 1, "and the desk lays it out")
		for doc in docs:
			doc.free()


# --- citation slips ---------------------------------------------------------------

func _texts(node: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	if node is Label:
		texts.append((node as Label).text)
	for child in node.get_children():
		texts.append_array(_texts(child))
	return texts


func test_a_missed_rule_is_explained_and_stays_until_next() -> void:
	desk.training_enabled = false
	var c: Claim = await _next_violating()
	var v: Dictionary = RuleChecker.violations(c, desk.day)[0]
	var key: String = (v["evidence"] as PackedStringArray)[0]
	await desk.stamp(true)
	t.ok(gs.run.today["warnings"] == 1, "the approval earned a citation")
	t.ok(not desk._docs.is_empty(), "the papers stay")
	t.ok(Rect2(Vector2.ZERO, DeskScreen.DESK_SIZE).has_point(desk._claim_doc.position), "on the desk")
	var slip: DocumentView = desk._docs[desk._docs.size() - 1]
	var says := " ".join(_texts(slip))
	t.ok(says.contains(v["rule"]), "the slip names %s: %s" % [v["rule"], says])
	t.ok(says.contains(CitationText.explain(c, v)), "with the facts")
	t.eq(desk._rulebook.find_rule_row(v["rule"]).get_mark(), FieldRow.Mark.VALID, "the missed rule is marked")
	t.eq(desk._find_evidence_row(key).get_mark(), FieldRow.Mark.VALID, "and its evidence")
	t.ok(desk._overlay._a != null and desk._overlay._b != null, "linked in red")
	var old := desk._docs.duplicate()
	desk.call_next_patient()
	for doc in old:
		t.ok(not desk._docs.has(doc), "NEXT! clears %s" % doc)
	await tree.process_frame
	for doc in old:
		t.ok(not is_instance_valid(doc), "and frees it")
	t.ok(desk._overlay._a == null, "the link goes with them")
