extends RefCounted
## Drives the real screen flow through a whole campaign with the cite-or-approve
## strategy, the way a careful player would.

var t: TestContext
var gs: Node
var tree: SceneTree
var main: Control


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	gs.save_path_override = TestContext.save_path()
	gs.delete_save()
	main = (load("res://screens/main.tscn") as PackedScene).instantiate()
	main.set("fast", true)
	tree.root.add_child(main)
	await tree.process_frame


func after_each() -> void:
	main.queue_free()
	await tree.process_frame
	gs.delete_save()
	gs.save_path_override = ""


func _screen() -> ScreenBase:
	return main.get("current")


## Waits (in real time) until `condition` holds or `seconds` pass.
func _until(condition: Callable, seconds: float = 4.0) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await tree.process_frame


## Swaps the fast Main for one that really fades.
func _slow_main() -> void:
	main.queue_free()
	await tree.process_frame
	main = (load("res://screens/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)


func _fade() -> ColorRect:
	return main.get("_fade")


func _fade_done() -> bool:
	return _fade().mouse_filter == Control.MOUSE_FILTER_IGNORE


func _screen_id(screen_name: String) -> int:
	return (main.get_script() as GDScript).get_script_constant_map()["Screen"][screen_name]


func _push_click(c: Control) -> void:
	var at := tree.root.get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		e.position = at
		e.global_position = at
		tree.root.push_input(e)


func _push_enter() -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ENTER
		e.physical_keycode = KEY_ENTER
		e.pressed = pressed
		tree.root.push_input(e)


func test_agreement_back_button_returns_to_the_title() -> void:
	_screen().finish({"action": "new"})
	await tree.process_frame
	var agreement := _screen() as AgreementScreen
	t.ok(agreement != null, "agreement")
	await tree.process_frame
	_push_click(agreement.back_button)
	await tree.process_frame
	t.ok(_screen() is TitleScreen, "clicking BACK returns to the title")


func test_keyboard_focus_waits_for_the_fade_in() -> void:
	await _slow_main()
	await _until(func() -> bool: return _screen() is TitleScreen)
	t.ok(not _fade_done(), "the title is still fading in")
	t.eq(_fade().mouse_filter, Control.MOUSE_FILTER_STOP, "the fade swallows clicks meanwhile")
	t.ok(tree.root.gui_get_focus_owner() == null, "and no button has focus yet")
	await _until(_fade_done)
	t.eq(_fade().color.a, 0.0, "fully faded in")
	t.eq(tree.root.gui_get_focus_owner(), (_screen() as TitleScreen).first_button, "then the first button takes focus")


func test_enter_during_the_ledger_fade_in_does_not_sleep() -> void:
	await _slow_main()
	await _until(_fade_done)
	gs.new_run("Pat Doe", 5)
	gs.begin_day()
	main.call("go", _screen_id("LEDGER"))
	await _until(func() -> bool: return _screen() is LedgerScreen)
	var ledger := _screen() as LedgerScreen
	t.ok(not _fade_done(), "the ledger is still fading in")
	_push_enter()
	await tree.process_frame
	t.eq(gs.run.day, 1, "Enter during the fade doesn't commit the night unseen")
	t.ok(not ledger._sleep.disabled, "SLEEP wasn't pressed")
	await _until(_fade_done)
	t.eq(tree.root.gui_get_focus_owner(), ledger._sleep, "SLEEP takes focus once the ledger is visible")


func test_agreement_back_returns_to_title_without_touching_the_save() -> void:
	gs.new_run("Saved Player", 9)
	_screen().finish({"action": "new"})
	await tree.process_frame
	t.ok(_screen() is AgreementScreen, "agreement")
	_screen().finish({"back": true})
	await tree.process_frame
	t.ok(_screen() is TitleScreen, "back on the title")
	t.ok(gs.has_save(), "save untouched")
	gs.load_game()
	t.eq(gs.run.player_name, "Saved Player")


func test_autopilot_reaches_an_ending() -> void:
	t.ok(_screen() is TitleScreen, "starts on the title")
	_screen().finish({"action": "new"})
	await tree.process_frame
	t.ok(_screen() is AgreementScreen, "agreement")
	_screen().finish({"name": "Pat Doe"})
	var guard := 0
	var days_seen: Array[int] = []
	while not (_screen() is EndingScreen) and guard < 60:
		guard += 1
		await tree.process_frame
		var screen := _screen()
		if screen is NewspaperScreen or screen is MemoScreen:
			screen.finish({})
		elif screen is DeskScreen:
			var desk := screen as DeskScreen
			days_seen.append(desk.day)
			for i in desk.claims.size():
				desk.call_next_patient()
				var c := desk.active_claim()
				var violations := RuleChecker.violations(c, desk.day)
				if c.is_player:
					await desk.stamp(false)
					break
				if violations.is_empty():
					await desk.stamp(true)
				else:
					var v: Dictionary = violations[0]
					t.ok(desk.try_cite(v["rule"], (v["evidence"] as PackedStringArray)[0]), "cites %s" % v["rule"])
					await desk.stamp(false)
			if not (_screen() is EndingScreen) and _screen() == desk:
				desk.call_next_patient()
		elif screen is LedgerScreen:
			(screen as LedgerScreen)._on_sleep()
	t.ok(_screen() is EndingScreen, "reached an ending after %d steps" % guard)
	t.eq(days_seen, [1, 2, 3, 4, 5, 6, 7] as Array[int], "played all seven days")
	t.ok(gs.run.ending in [Endings.PROMOTED, Endings.EMPLOYEE_OF_MONTH, Endings.SCAPEGOATED], "ending %s" % gs.run.ending)
	t.ok(not gs.has_save(), "save cleared after the ending")
