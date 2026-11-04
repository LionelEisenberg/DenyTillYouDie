extends Node
## The screenshot tour itself, loaded at runtime by screenshot_tour.gd so that
## scripts referencing autoloads compile after the autoloads exist.
##
## One run plays a week by the book and shoots every screen on the way: the day
## card, the desk (including event days, a stamp landing, R.H.'s favor note on
## day 7 and the day-7 climax), the ledgers, papers with photos, a letter with a
## snapshot, the Esc menu when the Settings autoload exists, and all three pages
## of every ending.

var out_dir := ""
var root: Window
var gs: Node


func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var window := DisplayServer.window_get_size()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://tour_%dx%d" % [window.x, window.y])
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.theme = UiTheme.build()
	gs = root.get_node("GameState")
	gs.save_path_override = "user://tour_save_%d.json" % OS.get_process_id()
	gs.delete_retry()
	gs.clear_record()

	await _show(TitleScreen.new(), "01_title")
	await _show(AgreementScreen.new(), "02_agreement")
	await _agreement_signed()

	gs.new_run("Pat Doe", 2026)
	await _show_slow(_day_card(1), "02c_day_card", 2.4)
	await _show(MemoScreen.new(), "03_memo_day1")

	var desk := DeskScreen.new()
	desk.fast = true
	root.add_child(desk)
	await _frames(2)
	await _shot("04_desk_empty")
	desk.call_next_patient()
	await _frames(2)
	await _shot("05_desk_patient")
	await _esc_menu()
	# Walk to the first claim with a violation and cite it.
	while not RuleChecker.has_valid_reason(desk.active_claim(), desk.day):
		await desk.stamp(true)
		desk.call_next_patient()
	desk._set_inspect(true)
	await _frames(2)
	await _shot("06_desk_inspect")
	var v: Dictionary = RuleChecker.violations(desk.active_claim(), desk.day)[0]
	desk.try_cite(v["rule"], (v["evidence"] as PackedStringArray)[0])
	await _frames(2)
	await _shot("07_desk_cited")
	desk.fast = false
	desk.stamp(false)
	await get_tree().create_timer(0.22).timeout
	await _shot("08a_desk_stamp_landing")
	await get_tree().create_timer(0.38).timeout
	await _shot("08_desk_stamped")
	desk.fast = true
	await get_tree().create_timer(2.5).timeout
	# Finish the day, stopping for the first patient who brings an exhibit (Walt).
	var exhibit_shot := false
	while not desk.end_shift_ready():
		desk.call_next_patient()
		if desk.active_claim() == null:
			break
		if not exhibit_shot and not desk.active_claim().exhibit.is_empty():
			exhibit_shot = true
			await _frames(2)
			await _shot("08b_desk_day1_exhibit")
		await desk.stamp(true)
	desk.queue_free()
	await _frames(1)

	await _show(LedgerScreen.new(), "09_ledger_day1", false)
	var ledger: LedgerScreen = root.get_child(root.get_child_count() - 1)
	ledger._on_sleep()
	ledger.queue_free()
	await _show(NewspaperScreen.new(), "10_paper_day2")
	await _paper_with_photos()
	await _child_with_parent()
	await _event_desks()

	# Day 2 by the book; day 3 shows the night Riley gets sick.
	_play_day_by_the_book()
	_play_day_by_the_book(false)
	await _show(LedgerScreen.new(), "10b_ledger_night3_riley", false)
	ledger = root.get_child(root.get_child_count() - 1)
	ledger._on_sleep()
	ledger.queue_free()
	await _show(MemoScreen.new(), "10c_memo_day4")
	# Day 4: approve the first patients (a citation slip may print), then Eleanor.
	desk = DeskScreen.new()
	desk.fast = true
	root.add_child(desk)
	await _frames(1)
	var eleanor_slot: int = Scripted.for_day(4)["slot"]
	for i in eleanor_slot:
		desk.call_next_patient()
		await desk.stamp(true)
	await _frames(2)
	await _shot("10d_desk_day4_after_approvals")
	desk.call_next_patient()
	await _frames(2)
	await _shot("10e_desk_day4_eleanor")
	desk.queue_free()
	await _frames(1)
	gs.run.day = 4
	_play_day_by_the_book()
	_play_day_by_the_book()
	var paper := NewspaperScreen.new()
	await _show(paper, "11_paper_day6")
	await _show(MemoScreen.new(), "12_memo_day6")
	await _letter_with_snapshot()
	desk = DeskScreen.new()
	desk.fast = true
	root.add_child(desk)
	await _frames(1)
	desk.call_next_patient()
	await _frames(2)
	await _shot("13_desk_day6")
	desk._rulebook.show_page("EXCLUSIONS")
	await _frames(1)
	await _shot("14_desk_day6_exclusions")
	desk.queue_free()
	await _frames(1)

	# Night 6 at its worst: a full day, the whole family sick.
	_play_day_by_the_book(false)
	for m: Dictionary in gs.run.family:
		if m["alive"]:
			m["sick"] = true
	await _show(LedgerScreen.new(), "14b_ledger_night6_worst", false)
	ledger = root.get_child(root.get_child_count() - 1)
	ledger._on_sleep()
	ledger.queue_free()
	await _frames(1)

	await _show_slow(_day_card(7), "14c_day_card_day7", 2.6)
	desk = DeskScreen.new()
	desk.fast = true
	root.add_child(desk)
	await _frames(1)
	while true:
		desk.call_next_patient()
		var c := desk.active_claim()
		if c == null or c.is_player:
			break
		await desk.stamp(false)
	desk._rulebook.show_page("DENYBOT")
	await _frames(2)
	await _shot("15_desk_day7_you")
	desk.queue_free()
	await _frames(1)
	await _day_seven_favor()
	await _day_seven_climax()

	# Rule on your own claim for real, so the ending pages have a record.
	gs.begin_day()
	gs.decide(gs.claims_today[gs.claims_today.size() - 1], false, "R-05")
	for ending: String in Endings.ALL:
		gs.run.ending = ending
		var screen := EndingScreen.new()
		await _show(screen, "20_ending_%s_p1" % ending, false)
		for page in [2, 3]:
			screen._advance()
			await _frames(3)
			await _shot("20_ending_%s_p%d" % [ending, page])
		screen.queue_free()
		await _frames(1)

	gs.delete_save()
	gs.delete_retry()
	gs.clear_record()
	print("screenshots in ", out_dir)
	get_tree().quit()


## Plays today's claims (cite or approve). With `sleep`, also closes the night.
func _play_day_by_the_book(sleep: bool = true) -> void:
	gs.begin_day()
	for c: Claim in gs.claims_today:
		var violations := RuleChecker.violations(c, gs.run.day)
		gs.decide(c, violations.is_empty(), "" if violations.is_empty() else violations[0]["rule"])
	if not sleep:
		return
	var ledger: Dictionary = gs.close_shift()
	var medicine := {}
	for m: Dictionary in gs.run.family:
		medicine[m["id"]] = true
	# Prescriptions and the household event too, so later shots show a family
	# that was looked after.
	var extras := {}
	for bill: Dictionary in ledger["bills"]:
		var id: String = bill["id"]
		if id.begins_with("rx:") or id.begins_with("event:"):
			extras[id] = true
	gs.apply_ledger({"food": true, "heat": true, "medicine": medicine, "extras": extras})


## The agreement right after SIGN AND START WORK (the signature and badge,
## once the sound workstream's version is in).
func _agreement_signed() -> void:
	var agreement := AgreementScreen.new()
	agreement.fast = false
	root.add_child(agreement)
	agreement.on_shown()
	await _frames(2)
	agreement.name_edit.text = "Pat Doe"
	var sign := _find_button(agreement, "SIGN AND START WORK")
	if sign:
		sign.pressed.emit()
	await get_tree().create_timer(2.5).timeout
	await _shot("02b_agreement_signed")
	agreement.queue_free()
	await _frames(1)


func _day_card(day: int) -> DayCardScreen:
	var card := DayCardScreen.new()
	card.day = day
	return card


## The day-2 paper again, with a face on file for the lead and an obituary.
func _paper_with_photos() -> void:
	var edition: Dictionary = (gs.run.morning.get("paper", {}) as Dictionary).duplicate(true)
	var lead: Dictionary = edition.get("lead", {})
	lead["portrait_seed"] = 58
	lead["age"] = 58
	var items: Array = edition.get("items", [])
	var obituary := {}
	for item: Dictionary in items:
		if item.get("headline", "") == "Obituaries":
			obituary = item
	if obituary.is_empty():
		obituary = {"headline": "Obituaries", "body": "Ana Lee, 71, of the East Side, died Monday after a stroke. She is survived by two sons."}
		items.insert(0, obituary)
	obituary["portrait_seed"] = 7101
	obituary["age"] = 71
	var screen := NewspaperScreen.new()
	screen.paper = edition
	await _show(screen, "10f_paper_obituary_photo")


## A child at the window, the parent's hand on their shoulder: today's first
## child patient whose parent does the talking, called first.
func _child_with_parent() -> void:
	var desk := DeskScreen.new()
	desk.fast = true
	root.add_child(desk)
	await _frames(1)
	for i in desk.claims.size():
		if desk.claims[i].is_child() and desk.claims[i].parent_speaks:
			var child: Claim = desk.claims[i]
			desk.claims[i] = desk.claims[0]
			desk.claims[0] = child
			break
	desk.call_next_patient()
	await _frames(2)
	await _shot("10a_desk_day2_child_with_parent")
	desk.queue_free()
	await _frames(1)


## The desk under each public event, dressed by the desk workstream's booth.
func _event_desks() -> void:
	var saved: Dictionary = gs.run.effects.duplicate()
	for effect: String in ["protest", "audit", "compassion"]:
		gs.run.effects = {"protest": effect == "protest", "audit": effect == "audit", "compassion": effect == "compassion"}
		var desk := DeskScreen.new()
		desk.fast = true
		root.add_child(desk)
		await _frames(1)
		desk.call_next_patient()
		# Mid-march, so the protest's placards are in the window.
		desk._booth._march_t = 1.3
		await _frames(2)
		await _shot("05b_desk_%s" % effect)
		desk.queue_free()
		await _frames(1)
	gs.run.effects = saved


## Day 6's memo with a letter that came with a photo.
func _letter_with_snapshot() -> void:
	var saved: Array = (gs.run.morning.get("letters", []) as Array).duplicate(true)
	gs.run.morning["letters"] = [{
		"from": "Karen Brennan", "photo_seed": 58, "photo_age": 58,
		"paragraphs": PackedStringArray([
			"To whoever handled my father's claim,",
			"Dad died last night. He paid Benevolence Mutual for nineteen years.",
			"I just wanted someone there to know his name. It was Walter.",
			"Karen Brennan",
		]),
	}]
	var memo := MemoScreen.new()
	memo.fast = true
	root.add_child(memo)
	memo.on_shown()
	memo._advance()
	await _frames(3)
	await _shot("12b_memo_letter_snapshot")
	memo.queue_free()
	await _frames(1)
	gs.run.morning["letters"] = saved


## Day 7 with a favor owed: Eleanor was approved, so R.H.'s note rides on the
## player's own claim. Shows where the desk puts the note.
func _day_seven_favor() -> void:
	var saved: Dictionary = gs.run.scripted_outcomes.duplicate()
	gs.run.scripted_outcomes["eleanor"] = "approved"
	var desk := DeskScreen.new()
	desk.fast = true
	root.add_child(desk)
	await _frames(1)
	while true:
		desk.call_next_patient()
		var c := desk.active_claim()
		if c == null or c.is_player:
			break
		await desk.stamp(false)
	await _frames(2)
	await _shot("15c_desk_day7_favor")
	desk.queue_free()
	await _frames(1)
	gs.run.scripted_outcomes = saved


## Day 7's last patient, staged by the desk workstream: everyone before them
## in fast mode, then the player's own claim with the animations on.
func _day_seven_climax() -> void:
	var desk := DeskScreen.new()
	desk.fast = true
	root.add_child(desk)
	await _frames(1)
	for i in desk.claims.size() - 1:
		desk.call_next_patient()
		await desk.stamp(false)
	desk.fast = false
	desk.call_next_patient()
	await get_tree().create_timer(4.5).timeout
	await _shot("15b_desk_day7_climax")
	desk.queue_free()
	await _frames(1)


## The Esc menu over the desk, when the Settings autoload is registered.
func _esc_menu() -> void:
	var settings := root.get_node_or_null("Settings")
	if settings == null or not settings.has_method("open_menu"):
		print("tour: no Settings autoload, skipping 16_esc_menu")
		return
	settings.call("open_menu")
	await get_tree().create_timer(0.6).timeout
	await _shot("16_esc_menu")
	if settings.has_method("close_menu"):
		settings.call("close_menu")
	else:
		for pressed: bool in [true, false]:
			var esc := InputEventKey.new()
			esc.keycode = KEY_ESCAPE
			esc.physical_keycode = KEY_ESCAPE
			esc.pressed = pressed
			root.push_input(esc)
	await _frames(2)
	get_tree().paused = false


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found:
			return found
	return null


func _show(screen: ScreenBase, shot_name: String, free_after: bool = true) -> void:
	screen.fast = true
	root.add_child(screen)
	screen.on_shown()
	await _frames(3)
	await _shot(shot_name)
	if free_after:
		screen.queue_free()
		await _frames(1)


## A screen with its animations running, shot `seconds` after it is shown.
func _show_slow(screen: ScreenBase, shot_name: String, seconds: float) -> void:
	screen.fast = false
	root.add_child(screen)
	screen.on_shown()
	await get_tree().create_timer(seconds).timeout
	await _shot(shot_name)
	screen.queue_free()
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
