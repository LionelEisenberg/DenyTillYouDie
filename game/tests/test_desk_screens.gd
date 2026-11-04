extends RefCounted
## The screens around the desk: when they take keyboard focus, how the night's
## ledger reads, and the date on the final front page.

var t: TestContext
var gs: Node
var tree: SceneTree
var screen: ScreenBase


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	gs.save_path_override = TestContext.save_path()
	gs.new_run("Pat Doe", 3)


func after_each() -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = null
	await tree.process_frame
	gs.delete_save()
	gs.save_path_override = ""


func _open(s: ScreenBase) -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
		await tree.process_frame
	screen = s
	screen.fast = true
	screen.theme = UiTheme.build()
	tree.root.add_child(screen)
	await tree.process_frame
	await tree.process_frame


func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	if node is Label:
		found.append(node as Label)
	for child in node.get_children():
		found.append_array(_labels(child))
	return found


func _has_text(node: Node, text: String) -> bool:
	for l in _labels(node):
		if l.text == text:
			return true
	return false


func _focus() -> Control:
	return tree.root.gui_get_focus_owner()


## Each screen built the way Main builds it, and the control on_shown() focuses.
func _check_focus_waits(s: ScreenBase, expected: Callable, what: String) -> void:
	await _open(s)
	t.ok(_focus() == null, "%s: nothing focused before on_shown()" % what)
	s.on_shown()
	t.ok(_focus() != null and _focus() == expected.call(), "%s: on_shown() focuses its default control" % what)


func test_screens_take_focus_only_when_shown() -> void:
	await _check_focus_waits(TitleScreen.new(), func() -> Control: return (screen as TitleScreen).first_button, "title")
	await _check_focus_waits(AgreementScreen.new(), func() -> Control: return (screen as AgreementScreen).name_edit, "agreement")
	await _check_focus_waits(MemoScreen.new(), func() -> Control: return (screen as MemoScreen)._button, "memo")
	await _check_focus_waits(NewspaperScreen.new(), func() -> Control: return (screen as NewspaperScreen)._go, "paper")
	gs.begin_day()
	await _check_focus_waits(LedgerScreen.new(), func() -> Control: return (screen as LedgerScreen)._sleep, "ledger")
	gs.run.ending = Endings.FIRED
	await _check_focus_waits(EndingScreen.new(), func() -> Control: return (screen as EndingScreen)._back, "ending")


func test_ledger_prints_the_locked_rent_row_faded() -> void:
	gs.begin_day()
	await _open(LedgerScreen.new())
	var ledger := screen as LedgerScreen
	t.ok(not ledger.ledger["evicted"], "an ordinary night")
	var rent: Button = ledger._toggles["rent"]
	t.ok(rent.disabled and rent.button_pressed, "rent is paid and can't be unticked")
	t.eq(rent.get_theme_color("font_disabled_color"), Palette.INK_FADED, "so it's printed in faded ink")
	t.ok(not rent.text.ends_with("(unpaid)"))
	var food: Button = ledger._toggles["food"]
	t.ok(not food.disabled, "food is a choice")
	t.eq(food.get_theme_color("font_color"), Palette.INK, "in full ink")


func test_ledger_on_an_eviction_night_shows_every_bill_unpaid() -> void:
	gs.begin_day()
	gs.run.savings = -100
	await _open(LedgerScreen.new())
	var ledger := screen as LedgerScreen
	t.ok(ledger.ledger["evicted"], "can't make rent")
	t.ok(ledger._toggles.size() >= 3, "rent, food and heat are listed")
	for id: String in ledger._toggles:
		var bill: Button = ledger._toggles[id]
		t.ok(bill.disabled, "%s can't be changed" % id)
		t.ok(not bill.button_pressed, "%s isn't ticked" % id)
		t.ok(bill.text.ends_with(" (unpaid)"), "%s says so: %s" % [id, bill.text])
		t.eq(bill.get_theme_color("font_disabled_color"), Palette.INK_FADED, "%s is faded" % id)
	t.eq(ledger._sleep.text, "CONTINUE")


func test_ledger_lists_only_the_bills_it_is_given() -> void:
	gs.begin_day()
	var night: Dictionary = gs.close_shift()
	# Nobody left to feed or keep warm: close_shift may return rent alone.
	night["bills"] = [night["bills"][0]]
	var ledger := LedgerScreen.new()
	ledger.ledger = night
	await _open(ledger)
	t.eq(ledger._toggles.keys(), ["rent"], "only the bills given")
	t.eq(ledger.paid_choices(), {"food": false, "heat": false, "medicine": {}})


func _masthead_date_after(day: int) -> String:
	return DateUtil.fmt_long(DateUtil.game_date(day) + 1).to_upper()


func test_night_ending_is_dated_the_next_morning() -> void:
	gs.run.day = 5
	gs.begin_day()
	gs.run.discontent = 150.0
	gs.close_shift()
	t.eq(gs.apply_ledger({"food": true, "heat": true, "medicine": {}}), Endings.SCAPEGOATED, "fired overnight")
	t.eq(gs.run.day, 5, "the run ended on day 5")
	await _open(EndingScreen.new())
	t.ok(_has_text(screen, _masthead_date_after(5)), "masthead says %s" % _masthead_date_after(5))
	t.ok(not _has_text(screen, DateUtil.fmt_long(DateUtil.game_date(5)).to_upper()), "not the day of the last shift")


func test_day_seven_ending_is_dated_the_next_morning() -> void:
	gs.run.day = 7
	gs.begin_day()
	var own: Claim = gs.claims_today[gs.claims_today.size() - 1]
	t.ok(own.is_player, "the last claim is the player's")
	gs.decide(own, true, "")
	t.eq(gs.run.ending, Endings.FIRED, "approved their own claim")
	await _open(EndingScreen.new())
	t.ok(_has_text(screen, _masthead_date_after(7)), "masthead says %s" % _masthead_date_after(7))
