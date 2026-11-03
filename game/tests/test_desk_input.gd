extends RefCounted
## Real mouse events through the viewport: clicking evidence in inspect mode and
## dragging paper. Catches mouse_filter mistakes that the hook-based tests skip.

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
	desk.theme = UiTheme.build()
	tree.root.add_child(desk)
	await tree.process_frame


func after_each() -> void:
	desk.queue_free()
	await tree.process_frame
	gs.delete_save()
	gs.save_path_override = ""


func _screen_pos(c: Control, local: Vector2) -> Vector2:
	# Pushed events are in window coordinates; the 1920x1080 canvas is stretched
	# into the window by the root's final transform (64x64 when headless).
	return tree.root.get_final_transform() * (c.get_global_transform_with_canvas() * local)


func _press(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.position = at
	e.global_position = at
	tree.root.push_input(e)


func _move(from: Vector2, to: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	e.global_position = to
	e.relative = to - from
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	tree.root.push_input(e)


func _click(c: Control) -> void:
	var at := _screen_pos(c, c.size / 2.0)
	_move(at, at)
	_press(at, true)
	_press(at, false)


func test_clicking_rule_and_evidence_cites() -> void:
	while true:
		desk.call_next_patient()
		await tree.process_frame
		if RuleChecker.has_valid_reason(desk.active_claim(), desk.day):
			break
		await desk.stamp(true)
	var v: Dictionary = RuleChecker.violations(desk.active_claim(), desk.day)[0]
	var key: String = (v["evidence"] as PackedStringArray)[0]
	desk._set_inspect(true)
	await tree.process_frame
	var rule_row := desk._rulebook.find_rule_row(v["rule"])
	var evidence_row := desk._find_evidence_row(key)
	t.ok(rule_row != null and evidence_row != null, "rows exist")
	# The evidence may sit under another paper; bring its document to the top first.
	for doc in desk._docs:
		if doc.find_row(key) == evidence_row:
			doc.move_to_front()
	desk._rulebook.move_to_front()
	await tree.process_frame
	_click(rule_row)
	await tree.process_frame
	t.eq(desk._sel_rule, v["rule"], "rule selected by click")
	for doc in desk._docs:
		if doc.find_row(key) == evidence_row:
			doc.move_to_front()
	await tree.process_frame
	_click(evidence_row)
	await tree.process_frame
	t.eq(desk.cited_rule, v["rule"], "clicking both cites the rule")


func test_dragging_moves_a_document() -> void:
	desk.call_next_patient()
	await tree.process_frame
	var doc := desk._claim_doc
	doc.move_to_front()
	await tree.process_frame
	var before := doc.position
	var grab := _screen_pos(doc, Vector2(doc.size.x / 2.0, 12))
	var scale := (tree.root.get_final_transform() * doc.get_global_transform_with_canvas()).get_scale().x
	_move(grab, grab)
	_press(grab, true)
	var to := grab + Vector2(120, 60) * scale
	_move(grab, to)
	_press(to, false)
	await tree.process_frame
	t.near(doc.position.x - before.x, 120.0, 2.0, "moved right")
	t.near(doc.position.y - before.y, 60.0, 2.0, "moved down")


func test_clicks_outside_inspect_mode_do_not_select() -> void:
	desk.call_next_patient()
	await tree.process_frame
	var row := desk._claim_doc.find_row("claim.name")
	desk._claim_doc.move_to_front()
	await tree.process_frame
	_click(row)
	await tree.process_frame
	t.eq(desk._sel_key, "", "no selection without inspect mode")
