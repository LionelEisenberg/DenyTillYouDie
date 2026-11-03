extends Node
## The screenshot tour itself, loaded at runtime by screenshot_tour.gd so that
## scripts referencing autoloads compile after the autoloads exist.

var out_dir := ""
var root: Window
var gs: Node


func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://tests/screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.theme = UiTheme.build()
	gs = root.get_node("GameState")
	gs.save_path_override = "user://tour_save.json"

	await _show(TitleScreen.new(), "01_title")
	await _show(AgreementScreen.new(), "02_agreement")

	gs.new_run("Pat Doe", 2026)
	await _show(MemoScreen.new(), "03_memo_day1")

	var desk := DeskScreen.new()
	desk.fast = true
	root.add_child(desk)
	await _frames(2)
	await _shot("04_desk_empty")
	desk.call_next_patient()
	await _frames(2)
	await _shot("05_desk_patient")
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
	await get_tree().create_timer(0.6).timeout
	await _shot("08_desk_stamped")
	desk.fast = true
	await get_tree().create_timer(2.5).timeout
	# Finish the day.
	while not desk.end_shift_ready():
		desk.call_next_patient()
		if desk.active_claim() == null:
			break
		await desk.stamp(true)
	desk.queue_free()
	await _frames(1)

	await _show(LedgerScreen.new(), "09_ledger_day1", false)
	var ledger: LedgerScreen = root.get_child(root.get_child_count() - 1)
	ledger._on_sleep()
	ledger.queue_free()
	await _show(NewspaperScreen.new(), "10_paper_day2")

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

	_play_day_by_the_book()
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

	for ending in [Endings.SCAPEGOATED, Endings.EVICTED, Endings.FIRED, Endings.EMPLOYEE_OF_MONTH, Endings.PROMOTED]:
		gs.run.ending = ending
		await _show(EndingScreen.new(), "20_ending_%s" % ending)

	gs.delete_save()
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
	gs.close_shift()
	var medicine := {}
	for m: Dictionary in gs.run.family:
		medicine[m["id"]] = true
	gs.apply_ledger({"food": true, "heat": true, "medicine": medicine})


func _show(screen: ScreenBase, shot_name: String, free_after: bool = true) -> void:
	screen.fast = true
	root.add_child(screen)
	await _frames(3)
	await _shot(shot_name)
	if free_after:
		screen.queue_free()
		await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
