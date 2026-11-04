extends RefCounted
## The screens between shifts: the morning day card, sheets that land on the
## table under the lamp, and the snapshot clipped to a letter.

var t: TestContext
var gs: Node
var tree: SceneTree
var screen: ScreenBase
var _reduce_motion: Variant


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	gs.save_path_override = TestContext.save_path()
	gs.new_run("Pat Doe", 3)
	_reduce_motion = Engine.get_meta("reduce_motion", false)


func after_each() -> void:
	Engine.set_meta("reduce_motion", _reduce_motion)
	# Nothing here should open the Esc menu, but a test that fails halfway must
	# not leave the next one paused behind it.
	var settings := tree.root.get_node_or_null("Settings")
	if settings != null and settings.has_method("close_menu"):
		settings.call("close_menu")
	tree.paused = false
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = null
	await tree.process_frame
	gs.delete_save()
	gs.delete_retry()
	gs.save_path_override = ""


## Adds `s` to the tree. With `settle`, waits a frame; without, returns right
## after _ready, so a test sees the state the first frame will draw.
func _open(s: ScreenBase, fast: bool, settle: bool = true) -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
		await tree.process_frame
	screen = s
	screen.fast = fast
	screen.theme = UiTheme.build()
	tree.root.add_child(screen)
	if settle:
		await tree.process_frame


## Waits (in real time) until `condition` holds or `seconds` pass.
func _until(condition: Callable, seconds: float = 4.0) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await tree.process_frame


func _first_child(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.is_class(type_name):
			return child
	return null


func _key(keycode: Key, pressed: bool, alt: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = pressed
	e.alt_pressed = alt
	return e


func _push_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		tree.root.push_input(_key(keycode, pressed))


## Hands a press of `keycode` straight to the card, the way the viewport would
## once nothing before it had taken the key, and says whether the card took it
## (skipped and marked it handled). Keys that belong to the Esc menu are tested
## this way: pushed through the viewport, Esc would open the real menu once the
## Settings autoload is registered.
func _card_takes(card: DayCardScreen, keycode: Key, alt: bool = false) -> bool:
	# A key release nothing listens to starts a fresh event, so "handled" below
	# speaks only for the card.
	tree.root.push_input(_key(KEY_F12, false))
	card._unhandled_input(_key(keycode, true, alt))
	return tree.root.is_input_handled()


func _push_click(c: Control, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var at := tree.root.get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.button_mask = (1 << (button - 1)) if pressed else 0
		e.position = at
		e.global_position = at
		tree.root.push_input(e)


func _day_card(day: int) -> DayCardScreen:
	var card := DayCardScreen.new()
	card.day = day
	return card


# --- the day card -----------------------------------------------------------

func test_day_card_types_the_date_then_punches_in_and_finishes() -> void:
	var card := _day_card(3)
	var payloads: Array = []
	card.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	await _open(card, false)
	t.eq(card.day_label.text, "DAY 3")
	t.eq(card.date_label.text, "WEDNESDAY 03/04/2026")
	t.eq(card.day_label.get_theme_font_size("font_size"), UiTheme.SIZE_HUGE, "the day at 96 px")
	t.eq(card.date_label.get_theme_font_size("font_size"), UiTheme.SIZE_TITLE, "the date at 32 px")
	t.eq(card.date_label.visible_characters, 0, "nothing typed before the card is shown")
	t.ok(card.card.position.y >= 1080.0, "the time card waits below the screen")
	t.ok(card.note_label == null, "no seven-days line before Sunday")
	card.on_shown()
	t.eq(card.date_label.visible_characters, 0, "the day fades in before the date types")
	await _until(func() -> bool: return card.date_label.visible_characters > 0, 2.0)
	var typed := card.date_label.visible_characters
	t.ok(typed > 0 and typed < card.date_label.text.length(), "the date types out a letter at a time: %d so far" % typed)
	t.ok(payloads.is_empty(), "still on screen")
	await _until(func() -> bool: return not payloads.is_empty(), 5.0)
	t.eq(payloads, [{}], "it finishes by itself")
	t.ok(card.card.punched, "the clock stamped the card")
	t.eq(card.card.todays_punch(), "IN  08:00")
	t.eq(card.card.position, card._card_rest, "the card slid up into place")


func test_sunday_card_says_the_company_never_closes() -> void:
	var card := _day_card(7)
	await _open(card, true)
	t.ok(card.note_label != null, "day 7 adds a line")
	t.eq(card.note_label.text, "Benevolence Mutual operates seven days a week.")
	t.eq(card.note_label.get_theme_font_size("font_size"), UiTheme.SIZE_SMALL, "in small type")
	t.eq(card.date_label.text, "SUNDAY 03/08/2026")


func test_a_key_or_click_skips_the_card_only_once_shown() -> void:
	var card := _day_card(2)
	var payloads: Array = []
	card.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	await _open(card, false)
	_push_key(KEY_SPACE)
	await tree.process_frame
	t.ok(payloads.is_empty(), "a key during the fade-in does nothing")
	card.on_shown()
	for keycode: Key in [KEY_ESCAPE, KEY_M, KEY_F11]:
		t.ok(not _card_takes(card, keycode), "%s is left for its own job" % OS.get_keycode_string(keycode))
	t.ok(payloads.is_empty(), "Esc, M and F11 never skip the card")
	t.ok(card.date_label.visible_characters != -1, "which is still typing")
	_push_key(KEY_ENTER)
	await tree.process_frame
	t.eq(payloads, [{}], "any other key skips")
	t.eq(card.date_label.visible_characters, -1, "and shows the whole card")
	await tree.create_timer(0.4).timeout
	t.eq(payloads.size(), 1, "finishes once")
	var clicked := _day_card(4)
	var clicks: Array = []
	clicked.done.connect(func(p: Dictionary) -> void: clicks.append(p))
	await _open(clicked, false)
	clicked.on_shown()
	_push_click(clicked)
	await tree.process_frame
	t.eq(clicks, [{}], "a click skips too")


func test_modifiers_shortcuts_and_the_wheel_never_skip_the_card() -> void:
	var card := _day_card(3)
	var payloads: Array = []
	card.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	await _open(card, false)
	card.on_shown()
	for keycode: Key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_PRINT]:
		t.ok(not _card_takes(card, keycode), "%s alone is part of something else" % OS.get_keycode_string(keycode))
	t.ok(not _card_takes(card, KEY_TAB, true), "Alt+Tab belongs to the window manager")
	t.ok(payloads.is_empty(), "none of them skipped")
	for button: MouseButton in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_MIDDLE]:
		_push_click(card, button)
	await tree.process_frame
	t.ok(payloads.is_empty(), "nor did the wheel or the middle button")
	t.ok(_card_takes(card, KEY_SPACE), "a plain key still does")
	t.eq(payloads, [{}])
	var right := _day_card(4)
	var clicks: Array = []
	right.done.connect(func(p: Dictionary) -> void: clicks.append(p))
	await _open(right, false)
	right.on_shown()
	_push_click(right, MOUSE_BUTTON_RIGHT)
	await tree.process_frame
	t.eq(clicks, [{}], "and so does a right click")


func test_a_skip_stops_everything_still_moving() -> void:
	# Mid-fade: the day is still coming up when the key lands.
	var fading := _day_card(2)
	await _open(fading, false)
	fading.on_shown()
	await tree.process_frame
	await tree.process_frame
	t.ok(fading.day_label.modulate.a < 1.0, "caught mid-fade: %s" % fading.day_label.modulate.a)
	fading.skip()
	await tree.process_frame
	await tree.process_frame
	t.eq(fading.day_label.modulate.a, 1.0, "the day stays up two frames later")
	# Mid-slide: the time card is on its way up.
	var sliding := _day_card(3)
	var payloads: Array = []
	sliding.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	await _open(sliding, false)
	sliding.on_shown()
	await _until(func() -> bool: return sliding.card.position.y < 1080.0, 4.0)
	t.ok(sliding.card.position.y > sliding._card_rest.y, "caught mid-slide at y=%s" % sliding.card.position.y)
	sliding.skip()
	t.eq(sliding.card.position, sliding._card_rest, "the card jumps into place")
	await tree.process_frame
	await tree.process_frame
	t.eq(sliding.card.position, sliding._card_rest, "and nothing slides it back down two frames later")
	t.eq(sliding.day_label.modulate.a, 1.0)
	t.eq(payloads, [{}], "finished once")


func test_the_card_waits_while_the_game_is_paused() -> void:
	var card := _day_card(3)
	var payloads: Array = []
	card.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	await _open(card, false)
	card.on_shown()
	await _until(func() -> bool: return card.date_label.visible_characters > 2, 3.0)
	# What the Esc menu does.
	tree.paused = true
	var typed := card.date_label.visible_characters
	# Longer than the whole card takes, timed by a clock that runs while paused.
	await tree.create_timer(4.0, true).timeout
	t.eq(card.date_label.visible_characters, typed, "nothing types behind the menu")
	t.ok(not card.card.punched, "the clock hasn't stamped the card")
	t.ok(payloads.is_empty(), "and the card hasn't finished")
	tree.paused = false
	await _until(func() -> bool: return not payloads.is_empty(), 6.0)
	t.eq(payloads, [{}], "it plays on once the game resumes")
	t.ok(card.card.punched)


func test_fast_day_card_is_whole_at_once() -> void:
	var card := _day_card(5)
	var payloads: Array = []
	card.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	await _open(card, true)
	t.eq(card.day_label.modulate.a, 1.0)
	t.eq(card.date_label.visible_characters, -1)
	t.ok(card.card.punched, "already punched")
	card.on_shown()
	t.eq(payloads, [{}], "and done as soon as it is shown")


func test_time_card_out_times_follow_the_patient_count() -> void:
	t.eq(DayCardScreen.TimeCard.out_time(1), "13:50", "5 patients")
	t.eq(DayCardScreen.TimeCard.out_time(2), "15:00", "6 patients")
	t.eq(DayCardScreen.TimeCard.out_time(5), "17:20", "8 patients")


# --- sheets on the table ----------------------------------------------------

func test_the_paper_drops_onto_the_table() -> void:
	var paper := NewspaperScreen.new()
	await _open(paper, false, false)
	var center := _first_child(paper, "CenterContainer") as CenterContainer
	t.ok(center != null, "the sheet's CenterContainer")
	t.ok(not is_zero_approx(center.rotation), "turned on its first frame: %s" % center.rotation_degrees)
	t.near(center.rotation_degrees, 3.0, 0.001, "by 3 degrees")
	t.eq(center.position.y, -60.0, "60 px above its place")
	t.eq(center.pivot_offset, Vector2(960, 540), "turning about the screen's center")
	await tree.process_frame
	t.ok(not is_zero_approx(center.rotation), "still turned a frame later")
	await tree.create_timer(0.6).timeout
	t.eq(center.rotation, 0.0, "settled flat after 0.6 s")
	t.eq(center.position, Vector2.ZERO, "and in place")


func test_slide_is_the_default_entrance() -> void:
	gs.begin_day()
	var ledger := LedgerScreen.new()
	await _open(ledger, false, false)
	var center := _first_child(ledger, "CenterContainer") as CenterContainer
	t.eq(center.position.y, 40.0, "rises 40 px from below")
	t.eq(center.modulate.a, 0.0, "fading in")
	t.eq(center.rotation, 0.0, "without turning")
	await tree.create_timer(0.4).timeout
	t.eq(center.position, Vector2.ZERO)
	t.eq(center.modulate.a, 1.0, "faded in")


func test_memo_pages_slide_up() -> void:
	gs.run.morning["letters"] = [_letter(false)]
	var memo := MemoScreen.new()
	await _open(memo, false, false)
	t.eq(memo._pages[0].position.y, 40.0, "the memo rises into place")
	await tree.create_timer(0.4).timeout
	t.eq(memo._pages[0].position, Vector2.ZERO)
	memo._advance()
	t.eq(memo._pages[1].position.y, 40.0, "and so does each letter")
	await tree.create_timer(0.4).timeout
	t.eq(memo._pages[1].position, Vector2.ZERO)


func test_fast_mode_and_reduce_motion_skip_entrances() -> void:
	var paper := NewspaperScreen.new()
	await _open(paper, true)
	var center := _first_child(paper, "CenterContainer") as CenterContainer
	t.eq(center.rotation, 0.0, "fast: no turn")
	t.eq(center.position, Vector2.ZERO, "fast: in place")
	Engine.set_meta("reduce_motion", true)
	var calm := NewspaperScreen.new()
	await _open(calm, false, false)
	center = _first_child(calm, "CenterContainer") as CenterContainer
	t.eq(center.rotation, 0.0, "reduce motion: no turn")
	t.eq(center.position, Vector2.ZERO, "reduce motion: no drop")


func test_every_sheet_sits_in_a_pool_of_lamplight() -> void:
	gs.begin_day()
	for s: ScreenBase in [NewspaperScreen.new(), MemoScreen.new(), LedgerScreen.new(), AgreementScreen.new()]:
		await _open(s, true)
		var pool := s.get_node_or_null("LampPool") as TextureRect
		t.ok(pool != null, "%s has the lamp pool" % s.get_script().get_global_name())
		if pool == null:
			continue
		var texture := pool.texture as GradientTexture2D
		t.ok(texture != null and texture.fill == GradientTexture2D.FILL_RADIAL, "a radial gradient")
		t.near(texture.gradient.get_color(0).a, 0.25, 0.001, "warm light at alpha 0.25")
		t.eq(texture.gradient.get_color(texture.gradient.get_point_count() - 1).a, 0.0, "fading to nothing")
		t.eq(pool.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		var sheet_index := 999
		for child in s.get_children():
			if child is CenterContainer or (child.get_child_count() > 0 and child.get_child(0) is CenterContainer):
				sheet_index = mini(sheet_index, child.get_index())
		t.ok(pool.get_index() < sheet_index, "%s: under the sheets" % s.get_script().get_global_name())
		t.eq(s.get_children().filter(func(c: Node) -> bool: return c.name == "LampPool").size(), 1, "just one")


# --- letters ---------------------------------------------------------------

func _letter(with_photo: bool) -> Dictionary:
	var letter := {"from": "Karen Brennan", "paragraphs": PackedStringArray(["To whoever handled my father's claim,", "Karen Brennan"])}
	if with_photo:
		letter["photo_seed"] = 4242
		letter["photo_age"] = 58
	return letter


func test_a_letter_with_a_photo_has_it_clipped_on() -> void:
	gs.run.morning["letters"] = [_letter(true), _letter(false)]
	var memo := MemoScreen.new()
	await _open(memo, true)
	t.eq(memo._pages.size(), 3, "memo and two letters")
	t.eq(memo.snapshots.size(), 1, "one snapshot, on the letter that came with one")
	var photo := memo.snapshots[0]
	t.ok(memo._pages[1].is_ancestor_of(photo), "clipped to the first letter")
	t.eq(photo.size, Vector2(80, 96), "a small print")
	var holder := photo.get_parent().get_parent() as Control
	t.ok(not (holder is Container), "turned inside a plain holder")
	t.ok(not is_zero_approx(photo.get_parent().rotation), "slightly rotated")


func test_the_memo_says_a_copy_is_in_the_manual() -> void:
	gs.run.morning["letters"] = [_letter(false)]
	var memo := MemoScreen.new()
	await _open(memo, true)
	t.eq(memo._filed.text, "A copy has been filed in your manual.")
	t.ok(memo._filed.visible, "under the memo")
	t.ok(memo._filed.position.y + memo._filed.size.y <= memo._button.position.y, "above the button")
	memo._advance()
	t.ok(not memo._filed.visible, "not under a letter")
	t.eq(memo.snapshots.size(), 0, "a letter without a photo has none")
