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
	gs.save_path_override = "user://test_save.json"
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
