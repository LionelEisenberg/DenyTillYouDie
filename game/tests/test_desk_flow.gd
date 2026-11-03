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


func test_next_patient_requires_a_stamp() -> void:
	desk.call_next_patient()
	var first := desk.active_claim()
	desk.call_next_patient()
	t.ok(desk.active_claim() == first, "can't skip an unstamped patient")
