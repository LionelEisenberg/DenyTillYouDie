extends RefCounted
## The night's ledger as the player sees it: carbon copies, household bills with
## their notes, live family notes, the line from home, the worst-case sheet
## height and the adding-machine printout.

var t: TestContext
var gs: Node
var tree: SceneTree
var screen: LedgerScreen


## Stands in for the Settings autoload, which mutes on M and opens the menu on
## Esc from _unhandled_input (main.gd toggles fullscreen there too).
class KeyProbe extends Node:
	var heard: Array[int] = []

	func _unhandled_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed:
			heard.append(key.keycode)


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


func _open(fast: bool = true) -> void:
	screen = LedgerScreen.new()
	screen.fast = fast
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


func _texts() -> PackedStringArray:
	var texts: PackedStringArray = []
	for l in _labels(screen):
		texts.append(l.text)
	return texts


## Marks every household event but `keep` as seen, so `keep` happens tonight.
func _only_event(keep: String) -> void:
	var seen: Array = []
	for e: Dictionary in Household.EVENTS:
		if e["id"] != keep:
			seen.append({"id": e["id"], "night": 0, "paid": true})
	gs.run.household["events"] = seen


func _status(member_index: int) -> String:
	return (screen._family_rows[member_index]["status"] as Label).text


func _note(member_index: int) -> String:
	return (screen._family_rows[member_index]["note"] as Label).text


func _click(toggle: Button) -> void:
	toggle.button_pressed = not toggle.button_pressed


func _sheet_height() -> float:
	for node in screen.get_children():
		if node is CenterContainer:
			return ((node as CenterContainer).get_child(0) as Control).size.y
	return INF


## Night 6 at its fullest: every patient on the carbons with long names, every
## income line, three sick, both prescriptions, the longest household event.
func _worst_night_six(furnace_out: bool) -> void:
	gs.run.day = 6
	gs.begin_day()
	var run: RunState = gs.run
	run.savings = 160
	run.effects["audit"] = true
	_only_event("dentist")
	if furnace_out:
		run.household["no_heat_through"] = 6
	for m in run.family:
		m["sick"] = true
	run.member("partner")["sick_nights"] = 1
	var decisions: Array = []
	for i in 8:
		var rec := {
			"claim_no": "BM-0307-10%02d" % i, "name": "Bartholomew Featherstonehaugh-%d" % i, "age": 88,
			"diagnosis": "Kidney stone", "priority": 1, "scripted_id": "", "child": false, "is_player": false,
			"fatal": false, "approved": i == 7, "cited_rule": "R-06" if i < 4 else "", "blind": i >= 4 and i < 7,
			"valid_reason": i < 4 or i == 7, "exempt": false, "amount": 210000 + i, "pay": 25 if i < 4 else 12,
			"fine": 5 if i == 7 else 0, "missed_rule": "R-06" if i == 7 else "", "citation": i == 7, "portrait_seed": i,
		}
		if i == 6:
			rec["scripted_id"] = "eleanor"
		decisions.append(rec)
	run.today["decisions"] = decisions
	run.today["commissions"] = 136
	run.today["deductions"] = 6
	run.today["fines"] = 5
	run.today["fees"] = 8


func test_the_sheet_is_addressed_and_labels_savings_by_time() -> void:
	gs.begin_day()
	await _open()
	var texts := _texts()
	t.ok(texts.has("HOUSEHOLD LEDGER - UNIT 4B, 1120 CALLOWAY ST."), "%s" % texts)
	t.ok(texts.has("Savings (this morning)"))
	t.ok(not texts.has("Savings"), "the old label is gone")
	t.ok(texts.has("Rent is due again tomorrow night."))
	t.ok(texts.has(HomeLines.NIGHT_ONE), "the line from home")


func test_carbon_copies_print_under_available() -> void:
	gs.begin_day()
	for c: Claim in gs.claims_today:
		gs.decide(c, true, "")
	await _open()
	var texts := _texts()
	t.ok(texts.has("CARBON COPIES"))
	for line: String in screen.ledger["carbons"]:
		t.ok(texts.has(line), line)
	t.eq((screen.ledger["carbons"] as PackedStringArray).size(), gs.claims_today.size(), "one per patient")
	t.ok(texts.has(screen.ledger["carbon_total"]))


func test_household_bills_show_their_note_on_the_same_row() -> void:
	gs.run.day = 4
	gs.begin_day()
	_only_event("dentist")
	await _open()
	for pair: Array in [["rx:pills", "(not covered: R-06)"], ["rx:inhaler", "(not covered: R-05, pre-existing)"], ["event:dentist", "(skip: Sam gets sick)"]]:
		var toggle: Button = screen._toggles[pair[0]]
		var row := toggle.get_parent()
		var notes: PackedStringArray = []
		for l in _labels(row):
			notes.append(l.text)
		t.ok(notes.has(pair[1]), "%s row says %s: %s" % [pair[0], pair[1], notes])
		var note: Label = toggle.get_meta("note")
		t.eq(note.get_theme_font_size("font_size"), UiTheme.SIZE_SMALL, "16 px")
		var ink := note.get_theme_color("font_color")
		t.eq(ink, LedgerScreen.note_ink, "%s: the fine print's ink" % pair[0])
		t.ok(ink.get_luminance() < Palette.INK_FADED.get_luminance(), "darker than faded ink, to read when scaled down")
	t.ok(_texts().has(Household.event("dentist")["text"]), "the night's event is printed")


func test_toggles_stay_silent_for_the_click_sound() -> void:
	gs.begin_day()
	await _open()
	for id: String in screen._toggles:
		t.ok((screen._toggles[id] as Button).get_meta("silent", false), id)
	t.ok(screen._sleep.get_meta("silent", false), "SLEEP plays the lamp instead")


func test_family_notes_follow_the_boxes_live() -> void:
	gs.begin_day()
	await _open()
	var food: Button = screen._toggles["food"]
	t.ok(food.button_pressed, "food is pre-checked")
	t.eq(_status(0), "HEALTHY")
	t.eq(_note(0), "")
	_click(food)
	t.eq(_status(0), "HUNGRY")
	t.eq(_note(0), "Another night without food and they get sick.")
	t.ok(_texts().has("Tonight: Sam, Riley and Mom go hungry."))
	_click(food)
	t.eq(_status(0), "HEALTHY")
	t.ok(not _texts().has("Tonight: Sam, Riley and Mom go hungry."))


func test_medicine_notes_say_how_long_is_left() -> void:
	gs.run.savings = 500
	gs.run.member("mother")["sick"] = true
	gs.run.member("mother")["sick_nights"] = 1
	gs.begin_day()
	await _open()
	var medicine: Button = screen._toggles["medicine:mother"]
	t.eq(_status(2), "HEALTHY", "treated")
	_click(medicine)
	t.eq(_status(2), "SICK")
	t.eq(_note(2), "Will not survive the night without medicine.")
	t.eq((screen._family_rows[2]["note"] as Label).get_theme_color("font_color"), Palette.RED_DARK, "in red")


func test_the_furnace_locks_the_heat() -> void:
	gs.run.day = 4
	gs.run.savings = 500
	gs.begin_day()
	_only_event("furnace")
	await _open()
	var furnace: Button = screen._toggles["event:furnace"]
	var heat: Button = screen._toggles["heat"]
	t.ok(furnace.button_pressed and heat.button_pressed and not heat.disabled, "both pre-checked")
	_click(furnace)
	t.ok(not heat.button_pressed and heat.disabled, "no repair, no heat")
	t.eq((heat.get_meta("note") as Label).text, "(needs the furnace repair)")
	t.eq(_status(0), "COLD")
	_click(furnace)
	t.ok(not heat.disabled, "repaired: heat can be bought again")
	_click(heat)
	t.eq(_status(0), "HEALTHY")


func test_sleep_pays_the_household_bills_ticked() -> void:
	gs.run.day = 2
	gs.run.savings = 500
	gs.begin_day()
	_only_event("class_trip")
	await _open()
	var paid := screen.paid_choices()
	t.eq(paid.get("extras", {}), {"rx:pills": true, "event:class_trip": true})
	screen._on_sleep()
	t.eq(gs.run.household["missed"]["pills"], 0, "the pills were bought")
	t.eq(gs.run.household["events"][gs.run.household["events"].size() - 1]["paid"], true)


func test_blank_notes_take_no_room_and_the_sheet_holds_still() -> void:
	gs.begin_day()
	await _open()
	var food: Button = screen._toggles["food"]
	t.ok(food.button_pressed, "everyone fed and warm")
	for i in 3:
		t.ok(not (screen._family_rows[i]["holder"] as Control).visible, "row %d leaves no blank line" % i)
	t.ok(not screen._tonight_box.visible, "no blank Tonight lines")
	var mom_block: Control = (screen._family_rows[2]["status"] as Label).get_parent().get_parent()
	var home := _home_label()
	t.ok(home.get_global_rect().position.y - mom_block.get_global_rect().end.y <= 8.0, "the line from home sits under the family: %s, %s" % [mom_block.get_global_rect(), home.get_global_rect()])
	var height := _sheet_height()
	var food_top := food.get_global_rect().position.y
	_click(food)
	await tree.process_frame
	await tree.process_frame
	for i in 3:
		t.ok((screen._family_rows[i]["holder"] as Control).visible, "row %d says what a hungry night does" % i)
	t.ok(screen._tonight_box.visible, "and who goes hungry")
	t.eq(_sheet_height(), height, "the sheet keeps its height")
	t.eq(food.get_global_rect().position.y, food_top, "so the box stays under the pointer")
	_click(food)
	await tree.process_frame
	t.ok(not screen._tonight_box.visible, "fed again")


func _home_label() -> Label:
	for l in _labels(screen):
		if l.has_meta("home_line"):
			return l
	return null


func test_no_rent_reminder_on_the_last_night() -> void:
	for day in [5, 6]:
		gs.run.day = day
		gs.run.savings = 500
		gs.begin_day()
		await _open()
		t.eq(_texts().has(LedgerScreen.RENT_REMINDER), day < 6, "night %d" % day)
		screen.queue_free()
		screen = null
		await tree.process_frame
		gs.new_run("Pat Doe", 3)


func test_eviction_shows_where_the_family_stands() -> void:
	gs.run.member("partner")["hungry"] = 1
	gs.begin_day()
	gs.run.savings = -100
	await _open()
	t.eq(_status(0), "HUNGRY")
	t.eq(_note(0), "", "no forecast for a night that never comes")
	t.ok(not _texts().has("Rent is due again tomorrow night."))


func test_the_worst_night_six_fits_on_one_sheet() -> void:
	for furnace_out in [false, true]:
		_worst_night_six(furnace_out)
		await _open()
		t.eq((screen.ledger["carbons"] as PackedStringArray).size(), 8)
		t.ok((screen.ledger["income"] as Array).size() >= 8, "every income line: %s" % [screen.ledger["income"]])
		t.eq((screen.ledger["bills"] as Array).size(), 8 if furnace_out else 9)
		var height := _sheet_height()
		t.ok(height <= 1000.0, "furnace out %s: the sheet is %d px tall" % [furnace_out, height])
		screen.queue_free()
		screen = null
		await tree.process_frame
		gs.new_run("Pat Doe", 3)


func test_the_ledger_prints_line_by_line_until_clicked() -> void:
	gs.begin_day()
	await _open(false)
	var total := screen._steps.size()
	var first := screen.printed_rows()
	t.ok(screen.revealing(), "printing")
	t.ok(first < total, "first frames: %d of %d lines" % [first, total])
	screen.on_shown()
	t.eq(tree.root.gui_get_focus_owner(), screen._sleep, "SLEEP takes focus when shown, printed or not")
	screen._on_sleep()
	t.eq(gs.run.day, 1, "SLEEP isn't there to press yet")
	t.eq(screen.printed_rows(), total, "but the press prints everything")
	t.ok(not screen.revealing())


func test_the_printout_finishes_on_its_own() -> void:
	gs.begin_day()
	await _open(false)
	var deadline := Time.get_ticks_msec() + 15000
	while screen.revealing() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	t.ok(not screen.revealing(), "done printing")
	t.eq(screen.printed_rows(), screen._steps.size(), "every line is on the sheet")
	t.eq((screen._available_amount as Label).text, UiTheme.money(int(screen.ledger["available"])), "the total rolled up to Available")


func test_a_click_finishes_the_printout() -> void:
	gs.begin_day()
	await _open(false)
	screen.on_shown()
	var first := screen.printed_rows()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	tree.root.push_input(click)
	t.ok(first < screen.printed_rows(), "%d lines, then %d after the click" % [first, screen.printed_rows()])
	t.eq(screen.printed_rows(), screen._steps.size())
	t.eq(gs.run.day, 1, "the click didn't press anything")
	t.ok(not screen._sleep.disabled, "SLEEP is ready")


func test_a_key_finishes_the_printout_without_sleeping() -> void:
	gs.begin_day()
	await _open(false)
	screen.on_shown()
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	tree.root.push_input(key)
	t.eq(screen.printed_rows(), screen._steps.size(), "printed")
	t.eq(gs.run.day, 1, "Enter only finished the printout")
	t.eq(tree.root.gui_get_focus_owner(), screen._sleep, "SLEEP has focus for the next press")


func test_fast_mode_prints_everything_at_once() -> void:
	gs.begin_day()
	await _open(true)
	screen.on_shown()
	t.eq(screen.printed_rows(), screen._steps.size())
	t.ok(not screen.revealing())


func test_esc_m_and_f11_pass_through_the_printout() -> void:
	gs.begin_day()
	await _open(false)
	screen.on_shown()
	# Settings would act on these keys (open the menu, mute). This test only asks
	# whether the ledger leaves them alone, so it listens in Settings' place.
	var settings := tree.root.get_node_or_null("Settings")
	if settings:
		settings.set_process_unhandled_input(false)
	var probe := KeyProbe.new()
	tree.root.add_child(probe)
	var first := screen.printed_rows()
	for code: Key in [KEY_ESCAPE, KEY_M, KEY_F11]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = true
		tree.root.push_input(key)
		t.ok(not tree.root.is_input_handled(), "%s is left for the menu, mute or fullscreen" % OS.get_keycode_string(code))
	var heard: Array[int] = probe.heard.duplicate()
	probe.queue_free()
	if settings:
		settings.set_process_unhandled_input(true)
	var expected: Array[int] = [KEY_ESCAPE, KEY_M, KEY_F11]
	t.eq(heard, expected, "all three reach _unhandled_input")
	t.ok(screen.revealing(), "and the printout keeps going")
	t.ok(screen.printed_rows() < screen._steps.size(), "%d lines printed (%d before)" % [screen.printed_rows(), first])
	t.eq(gs.run.day, 1)


func test_reduce_motion_puts_the_sheet_down_at_once() -> void:
	var had := Engine.has_meta("reduce_motion")
	var before: Variant = Engine.get_meta("reduce_motion") if had else false
	Engine.set_meta("reduce_motion", true)
	gs.begin_day()
	await _open(false)
	var printed := screen.printed_rows()
	var revealing := screen.revealing()
	if had:
		Engine.set_meta("reduce_motion", before)
	else:
		Engine.remove_meta("reduce_motion")
	t.eq(printed, screen._steps.size(), "every line at once")
	t.ok(not revealing)
	t.eq((screen._available_amount as Label).text, UiTheme.money(int(screen.ledger["available"])))
