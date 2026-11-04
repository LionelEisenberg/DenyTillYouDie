extends RefCounted
## Drives the real screen flow through a whole campaign with the cite-or-approve
## strategy, the way a careful player would.

var t: TestContext
var gs: Node
var tree: SceneTree
var main: Control
## The stand-in Esc menu, when the Settings autoload isn't registered.
var _menu: CanvasLayer


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
	_close_esc_menu()
	main.queue_free()
	tree.paused = false
	await tree.process_frame
	gs.delete_save()
	gs.delete_retry()
	gs.clear_record()
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


## Opens the Esc menu: the Settings autoload's once it is registered, otherwise a
## stand-in that does what it does (pauses the game and takes keyboard focus on
## its own layer, outside Main). Returns the control holding focus.
func _open_esc_menu() -> Control:
	var settings := tree.root.get_node_or_null("Settings")
	if settings != null and settings.has_method("open_menu"):
		settings.call("open_menu")
		await tree.process_frame
		return tree.root.gui_get_focus_owner()
	_menu = CanvasLayer.new()
	_menu.layer = 100
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	var resume := Button.new()
	resume.text = "RESUME"
	_menu.add_child(resume)
	tree.root.add_child(_menu)
	tree.paused = true
	resume.grab_focus()
	await tree.process_frame
	return resume


func _close_esc_menu() -> void:
	var settings := tree.root.get_node_or_null("Settings")
	if settings != null and settings.has_method("close_menu"):
		settings.call("close_menu")
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null
	tree.paused = false


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
	# The title starts runs on randi(). Fix it: about one seed in 150 ends in a
	# night-6 scapegoating even played by the book.
	seed(4471)
	t.ok(_screen() is TitleScreen, "starts on the title")
	_screen().finish({"action": "new"})
	await tree.process_frame
	t.ok(_screen() is AgreementScreen, "agreement")
	_screen().finish({"name": "Pat Doe"})
	var guard := 0
	var days_seen: Array[int] = []
	var day_seven_payloads: Array = []
	var day_seven_desk: DeskScreen
	while not (_screen() is EndingScreen) and guard < 60:
		guard += 1
		await tree.process_frame
		var screen := _screen()
		if screen is NewspaperScreen or screen is MemoScreen or screen is DayCardScreen:
			screen.finish({})
		elif screen is DeskScreen:
			var desk := screen as DeskScreen
			days_seen.append(desk.day)
			if desk.day == 7:
				day_seven_desk = desk
				desk.done.connect(func(p: Dictionary) -> void: day_seven_payloads.append(p))
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
	t.eq(day_seven_payloads.size(), 1, "the day-7 desk finished once, on the player's claim")
	# The day-7 climax always ends on a hard cut after the player's own claim.
	t.ok(day_seven_desk != null and not day_seven_payloads.is_empty(), "the day-7 desk sent a payload")
	if not day_seven_payloads.is_empty():
		t.eq(day_seven_payloads[0].get("cut", false), true, "the day-7 desk sends cut")
	t.eq(gs.retry_day(), 7, "a day-7 ending can retry Sunday morning")


func test_a_slow_morning_opens_on_its_day_card() -> void:
	await _slow_main()
	await _until(_fade_done)
	gs.new_run("Pat Doe", 5)
	var seen: Array[String] = []
	main.call("_morning")
	var deadline := Time.get_ticks_msec() + 8000
	while not (_screen() is MemoScreen) and Time.get_ticks_msec() < deadline:
		var s := _screen()
		if s != null and (seen.is_empty() or seen[-1] != s.get_script().get_global_name()):
			seen.append(s.get_script().get_global_name())
		await tree.process_frame
	t.eq(seen, ["TitleScreen", "DayCardScreen"] as Array[String], "the title, then the day card")
	t.ok(_screen() is MemoScreen, "then the memo (day 1 has no paper)")


func test_a_key_skips_the_day_card_in_the_real_flow() -> void:
	await _slow_main()
	await _until(_fade_done)
	gs.new_run("Pat Doe", 5)
	main.call("_morning")
	await _until(func() -> bool: return _screen() is DayCardScreen and _fade_done())
	var card := _screen() as DayCardScreen
	t.eq(card.day, 1, "day 1's card")
	_push_enter()
	await _until(func() -> bool: return _screen() is MemoScreen, 2.0)
	t.ok(_screen() is MemoScreen, "Enter skipped straight on to the memo")


func test_the_esc_menu_keeps_its_focus_over_a_day_card() -> void:
	await _slow_main()
	await _until(_fade_done)
	gs.new_run("Pat Doe", 5)
	main.call("_morning")
	await _until(func() -> bool: return _screen() is DayCardScreen and _fade_done())
	var card := _screen() as DayCardScreen
	var payloads: Array = []
	card.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	var menu_focus := await _open_esc_menu()
	t.ok(tree.paused, "the menu pauses the game")
	t.ok(menu_focus != null and not main.is_ancestor_of(menu_focus), "and holds keyboard focus on its own layer")
	# Longer than the whole card takes, timed by a clock that runs while paused.
	await tree.create_timer(4.5, true).timeout
	t.ok(_screen() == card and payloads.is_empty(), "the card waits behind the menu")
	t.eq(tree.root.gui_get_focus_owner(), menu_focus, "and the menu keeps keyboard focus")
	# Anything moving the flow on while the menu is up leaves its focus alone.
	main.call("go", _screen_id("MEMO"))
	t.eq(tree.root.gui_get_focus_owner(), menu_focus, "a screen change doesn't take the menu's focus")
	_close_esc_menu()
	await _until(func() -> bool: return _screen() is MemoScreen and _fade_done(), 4.0)
	t.ok(_screen() is MemoScreen, "the flow carries on once the menu closes")


func test_a_card_finishing_on_its_way_out_cannot_redirect_the_flow() -> void:
	await _slow_main()
	await _until(_fade_done)
	gs.new_run("Pat Doe", 5)
	main.call("_morning")
	await _until(func() -> bool: return _screen() is DayCardScreen and _fade_done())
	var card := _screen() as DayCardScreen
	main.call("quit_to_title")
	# The card reaches its own end while the title fade is still under way.
	card.skip()
	await _until(func() -> bool: return _screen() is TitleScreen and _fade_done(), 3.0)
	t.ok(_screen() is TitleScreen, "QUIT TO TITLE lands on the title")
	await tree.create_timer(0.6).timeout
	t.ok(_screen() is TitleScreen, "and the card's finish didn't move the flow on to the memo")


func test_fast_mornings_skip_the_day_card() -> void:
	gs.new_run("Pat Doe", 5)
	main.call("_morning")
	await tree.process_frame
	t.ok(_screen() is MemoScreen, "fast mode goes straight to the memo")


func test_quit_to_title_from_a_desk_keeps_the_save() -> void:
	_screen().finish({"action": "new"})
	await tree.process_frame
	_screen().finish({"name": "Pat Doe"})
	await tree.process_frame
	_screen().finish({})
	await tree.process_frame
	t.ok(_screen() is DeskScreen, "at the desk")
	var desk := _screen() as DeskScreen
	desk.call_next_patient()
	await desk.stamp(true)
	var saved := FileAccess.get_file_as_string(TestContext.save_path())
	tree.paused = true
	main.call("quit_to_title")
	await tree.process_frame
	t.ok(not tree.paused, "unpaused")
	t.ok(_screen() is TitleScreen, "back on the title")
	t.eq(FileAccess.get_file_as_string(TestContext.save_path()), saved, "the save is untouched")
	t.ok(gs.has_save() and gs.saved_day() == 1, "Continue resumes day 1")
	t.ok((_screen() as TitleScreen).first_button.text.begins_with("CONTINUE"), "and the title offers it")


func test_quit_to_title_mid_fade_lands_cleanly() -> void:
	await _slow_main()
	await _until(_fade_done)
	gs.new_run("Pat Doe", 5)
	main.call("go", _screen_id("MEMO"))
	await tree.create_timer(0.1).timeout
	t.ok(not _fade_done(), "the memo is still fading in")
	main.call("quit_to_title")
	await _until(func() -> bool: return _screen() is TitleScreen and _fade_done())
	t.ok(_screen() is TitleScreen, "on the title")
	t.eq(_fade().color.a, 0.0, "fully faded in")
	await tree.create_timer(0.4).timeout
	t.ok(_screen() is TitleScreen, "and no stale fade takes it elsewhere")
	t.eq(tree.root.gui_get_focus_owner(), (_screen() as TitleScreen).first_button, "the title has focus")


func _end_on_day_seven() -> void:
	gs.new_run("Pat Doe", 9)
	gs.run.day = 7
	gs.begin_day()
	gs.decide(gs.claims_today[gs.claims_today.size() - 1], false, "R-05")


func test_the_cut_holds_black_then_shows_the_ending() -> void:
	await _slow_main()
	await _until(_fade_done)
	_end_on_day_seven()
	main.call("_on_done", {"cut": true}, _screen_id("DESK"))
	t.eq(_fade().color.a, 1.0, "black at once, no fade-out")
	t.eq(_fade().mouse_filter, Control.MOUSE_FILTER_STOP, "and it swallows clicks")
	await tree.create_timer(1.7).timeout
	t.ok(not (_screen() is EndingScreen), "still black after 1.7 s")
	t.eq(_fade().color.a, 1.0)
	await _until(func() -> bool: return _screen() is EndingScreen, 3.0)
	t.ok(_screen() is EndingScreen, "then the last front page")
	await _until(_fade_done)
	t.eq(_fade().color.a, 0.0, "faded in from the black")


func test_fast_cut_goes_straight_to_the_ending() -> void:
	_end_on_day_seven()
	main.call("_on_done", {"cut": true}, _screen_id("DESK"))
	await tree.process_frame
	t.ok(_screen() is EndingScreen, "no hold in fast mode")
	t.eq(_fade().color.a, 0.0)


## Plays today's claims citing every valid reason, then pays every bill.
func _play_day_by_the_book() -> String:
	gs.begin_day()
	for c: Claim in gs.claims_today:
		var violations := RuleChecker.violations(c, gs.run.day)
		gs.decide(c, violations.is_empty(), "" if violations.is_empty() else violations[0]["rule"])
	gs.close_shift()
	var medicine := {}
	for m: Dictionary in gs.run.family:
		medicine[m["id"]] = true
	return gs.apply_ledger({"food": true, "heat": true, "medicine": medicine})


func test_retry_replays_the_morning_that_was_lost() -> void:
	gs.new_run("Pat Doe", 42)
	for night in 2:
		t.eq(_play_day_by_the_book(), "", "night %d" % (night + 1))
	gs.begin_day()
	gs.run.savings = -500
	gs.close_shift()
	t.eq(gs.apply_ledger({"food": true, "heat": true, "medicine": {}}), Endings.EVICTED)
	main.call("go", _screen_id("ENDING"))
	await tree.process_frame
	var ending := _screen() as EndingScreen
	t.ok(ending != null, "the ending")
	ending._advance()
	ending._advance()
	t.ok(ending._retry.visible, "offers a retry")
	t.eq(ending._retry.text, "RETRY DAY 3 (WEDNESDAY MORNING)")
	ending._retry.pressed.emit()
	await tree.process_frame
	t.eq(gs.run.day, 3, "Wednesday morning again")
	t.eq(gs.run.ending, "", "the run goes on")
	t.ok(_screen() is NewspaperScreen, "starting with Wednesday's paper")
	t.ok(gs.has_save() and gs.saved_day() == 3, "and Continue resumes it")


func test_return_to_title_from_the_ending() -> void:
	_end_on_day_seven()
	main.call("go", _screen_id("ENDING"))
	await tree.process_frame
	_screen().finish({})
	await tree.process_frame
	t.ok(_screen() is TitleScreen, "RETURN TO TITLE")
	t.eq(gs.retry_day(), 7, "the retry file stays for another try")
