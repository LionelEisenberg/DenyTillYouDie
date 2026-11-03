extends RefCounted

var t: TestContext
var gs: Node
var desk: DeskScreen
var tree: SceneTree


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	gs.save_path_override = "user://test_save.json"
	gs.new_run("Pat Doe", 77)
	desk = DeskScreen.new()
	desk.fast = true
	tree.root.add_child(desk)
	await tree.process_frame


func after_each() -> void:
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
