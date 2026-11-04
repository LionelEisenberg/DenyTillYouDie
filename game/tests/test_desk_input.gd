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


func _move(from: Vector2, to: Vector2, mask: int = MOUSE_BUTTON_MASK_LEFT) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	e.global_position = to
	e.relative = to - from
	e.button_mask = mask
	tree.root.push_input(e)


## A real key press and release, as the keyboard sends it.
func _key(keycode: Key, unicode: int = 0) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.unicode = unicode
		e.pressed = pressed
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


func test_a_motion_without_the_button_ends_a_drag() -> void:
	desk.call_next_patient()
	await tree.process_frame
	var doc := desk._claim_doc
	doc.move_to_front()
	await tree.process_frame
	var grab := _screen_pos(doc, Vector2(doc.size.x / 2.0, 12))
	var scale := (tree.root.get_final_transform() * doc.get_global_transform_with_canvas()).get_scale().x
	_move(grab, grab)
	_press(grab, true)
	await tree.process_frame
	t.ok(doc._dragging, "pressing on the paper starts a drag")
	# The mouse-up happened outside the window, so it never arrived: the next
	# motion comes in with no button held.
	var lost := grab + Vector2(40, 20) * scale
	_move(grab, lost, 0)
	await tree.process_frame
	t.ok(not doc._dragging, "a motion with no button held ends the drag")
	var before := doc.position
	_move(lost, lost + Vector2(100, 50) * scale)
	await tree.process_frame
	t.eq(doc.position, before, "and the paper no longer follows the mouse")
	_press(lost + Vector2(100, 50) * scale, false)
	await tree.process_frame


func test_space_after_clicking_approve_inspects_and_stamps_nothing() -> void:
	desk.call_next_patient()
	await tree.process_frame
	_click(desk._approve_button)
	await tree.process_frame
	t.eq(gs.run.stats["processed"], 1, "the click on APPROVE stamped the claim")
	_click(desk._next_button)
	await tree.process_frame
	var claim := desk.active_claim()
	t.ok(claim != null, "the click on NEXT! called the next patient")
	var focus := tree.root.gui_get_focus_owner()
	t.ok(focus not in [desk._approve_button, desk._deny_button, desk._next_button, desk._inspect_button], "no desk button kept keyboard focus")
	_key(KEY_SPACE, 32)
	await tree.process_frame
	t.ok(desk.inspect, "Space toggles inspect")
	t.ok(desk.active_claim() == claim, "the new claim is still open")
	t.eq(gs.run.stats["processed"], 1, "and Space stamped nothing")


## Picked up, the paper itself lifts (bigger, a longer shadow, a closed hand)
## while the DocumentView the drag moves never scales; let go, it settles back
## to exactly its own size.
func test_a_held_paper_lifts_and_settles_back() -> void:
	desk.call_next_patient()
	await tree.process_frame
	var doc := desk._claim_doc
	doc.move_to_front()
	await tree.process_frame
	var box := doc.paper.get_theme_stylebox("panel") as StyleBoxFlat
	t.eq(box.shadow_offset, Vector2(6, 6), "a paper at rest")
	var grab := _screen_pos(doc, Vector2(doc.size.x / 2.0, 12))
	_move(grab, grab)
	_press(grab, true)
	await tree.process_frame
	t.ok(doc.is_dragging(), "grabbed")
	t.near(doc.paper.scale.x, DocumentView.LIFT_SCALE, 0.0001, "the held paper is lifted")
	t.eq(doc.scale, Vector2.ONE, "the DocumentView itself never scales")
	t.eq(box.shadow_offset, Vector2(12, 12), "its shadow reaches further")
	t.eq(doc.mouse_default_cursor_shape, Control.CURSOR_DRAG, "a closed hand while dragging")
	t.eq(doc.find_row("claim.name").mouse_default_cursor_shape, Control.CURSOR_DRAG, "over its rows too")
	_press(grab, false)
	await tree.process_frame
	t.ok(not doc.is_dragging(), "let go")
	await tree.create_timer(0.3).timeout
	t.eq(doc.paper.scale, Vector2.ONE, "settled back to its own size within 0.3 s")
	t.eq(doc.overlay.scale, Vector2.ONE, "the stamp layer with it")
	t.eq(box.shadow_offset, Vector2(6, 6), "shadow back")
	t.eq(doc.mouse_default_cursor_shape, Control.CURSOR_MOVE, "an open hand again")
	t.eq(doc.find_row("claim.name").mouse_default_cursor_shape, Control.CURSOR_MOVE)
