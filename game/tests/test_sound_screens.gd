extends RefCounted
## The opening minute: the title's slammed stamp and OPTIONS button, and the
## agreement's typewriter, signature, RECEIVED stamp, hang-up and staff badge.
## Timings are measured in game time (tween steps, frame deltas), never against
## the wall clock, so a loaded machine can't fail them.

const SETTINGS := preload("res://autoload/settings.gd")

var t: TestContext
var tree: SceneTree
var gs: Node
var sfx: Node
var screen: ScreenBase
var heard: Array[String] = []
var _settings: Node
var _payloads: Array[Dictionary] = []


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	sfx = tree.root.get_node("Sfx")
	gs.save_path_override = TestContext.save_path()
	gs.delete_save()
	heard.clear()
	_payloads.clear()
	sfx.played.connect(_on_played)


func after_each() -> void:
	sfx.played.disconnect(_on_played)
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = null
	if _settings != null and is_instance_valid(_settings):
		if _settings.menu.is_open():
			_settings.menu.close()
		_settings.queue_free()
	_settings = null
	tree.paused = false
	Engine.set_meta("reduce_motion", false)
	await tree.process_frame
	gs.delete_save()
	gs.save_path_override = ""


func _on_played(sound_name: String) -> void:
	heard.append(sound_name)


func _open(s: ScreenBase, fast: bool) -> void:
	_add(s, fast)
	await tree.process_frame


func _add(s: ScreenBase, fast: bool) -> void:
	screen = s
	screen.fast = fast
	screen.theme = UiTheme.build()
	screen.done.connect(func(p: Dictionary) -> void: _payloads.append(p))
	tree.root.add_child(screen)


## A title whose intro moves only when the test steps it (custom_step), so its
## timing is exact whatever the machine's frame rate.
func _paused_title() -> TitleScreen:
	_add(TitleScreen.new(), false)
	var title := screen as TitleScreen
	title._intro.pause()
	return title


## /root/Settings when registered, else an instance of our own.
func _settings_node() -> Node:
	var settings: Node = tree.root.get_node_or_null("Settings")
	if settings == null:
		_settings = SETTINGS.new()
		_settings.name = "Settings"
		tree.root.add_child(_settings)
		settings = _settings
	return settings


## Waits until `condition` holds or `seconds` of game time (summed frame
## deltas, the time tweens and timers see) pass.
func _until(condition: Callable, seconds: float = 4.0) -> void:
	var waited := 0.0
	while not condition.call() and waited < seconds:
		waited += tree.root.get_process_delta_time()
		await tree.process_frame


func _seconds(s: float) -> void:
	await tree.create_timer(s).timeout


func _push_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		tree.root.push_input(e)


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


# --- title ----------------------------------------------------------------------

func test_fast_title_has_options_and_the_new_controls_line() -> void:
	await _open(TitleScreen.new(), true)
	var title := screen as TitleScreen
	t.ok(title.options_button != null, "an OPTIONS button")
	t.eq(title.options_button.text, "OPTIONS")
	t.ok(title.options_button.is_visible_in_tree(), "on the menu")
	t.eq(title.controls_label.text, "F11 fullscreen  -  M mute  -  Esc menu")
	t.eq(title.controls_label.get_theme_color("font_color"), Palette.TEXT_DIM, "in TEXT_DIM")
	t.ok(title.intro_done and title.stamp_landed, "fast mode skips the intro")
	t.eq(title.stamp.modulate.a, 1.0, "the stamp is down")
	t.eq(heard.size(), 0, "silently")


func test_options_opens_the_settings_menu() -> void:
	var settings := _settings_node()
	await _open(TitleScreen.new(), true)
	var title := screen as TitleScreen
	t.ok(not title.options_button.disabled, "enabled when Settings is there")
	title.options_button.pressed.emit()
	t.ok(settings.menu.is_open(), "OPTIONS opens the Esc menu")
	t.ok(not settings.menu.title_button.visible, "without QUIT TO TITLE on the title")
	settings.menu.close()


func test_options_waits_for_settings() -> void:
	if tree.root.has_node("Settings"):
		return
	await _open(TitleScreen.new(), true)
	t.ok((screen as TitleScreen).options_button.disabled, "disabled while no Settings autoload exists")


func test_the_stamp_lands_0_4_s_after_the_screen_opens_then_the_menu_fades_in() -> void:
	var title := _paused_title()
	t.eq(title.stamp.modulate.a, 0.0, "no stamp at first")
	t.eq(title.first_button.get_parent().modulate.a, 0.0, "no menu at first")
	title._intro.custom_step(TitleScreen.LAND_AT - 0.01)
	t.ok(not title.stamp_landed and heard.is_empty(), "still in the air at 0.39 s")
	t.ok(title.stamp.modulate.a == 1.0 and title.stamp.scale.x > 1.0, "falling from above")
	title._intro.custom_step(0.02)
	t.ok(title.stamp_landed, "the stamp lands at 0.4 s")
	t.eq(heard, ["stamp"] as Array[String], "with a thud")
	t.eq(title.stamp.scale, Vector2.ONE, "from 1.6x down to 1x")
	t.ok(not title.intro_done, "the menu is still fading in")
	title._intro.custom_step(TitleScreen.REVEAL_TIME - 0.02)
	t.ok(not title.intro_done, "for 0.3 s")
	title._intro.custom_step(0.03)
	t.ok(title.intro_done, "then it is up")
	t.eq(title.first_button.get_parent().modulate.a, 1.0, "the menu")
	t.eq(title.footer.modulate.a, 1.0, "the footer too")


func test_reduce_motion_drops_the_stamp_without_the_fall() -> void:
	Engine.set_meta("reduce_motion", true)
	await _open(TitleScreen.new(), false)
	var title := screen as TitleScreen
	await _until(func() -> bool: return title.stamp.modulate.a > 0.0, 2.0)
	t.eq(title.stamp.scale, Vector2.ONE, "no 1.6x fall")
	await _until(func() -> bool: return title.intro_done, 2.0)
	t.ok(heard.has("stamp"), "still the thud")


func test_a_key_skips_the_intro_without_pressing_a_button() -> void:
	var title := _paused_title()
	await tree.process_frame
	title.on_shown()
	t.eq(tree.root.gui_get_focus_owner(), title.first_button, "NEW GAME has focus already")
	_push_key(KEY_ENTER)
	await tree.process_frame
	t.ok(title.intro_done, "the key skipped the intro")
	t.eq(title.first_button.get_parent().modulate.a, 1.0, "menu shown at once")
	t.eq(_payloads.size(), 0, "and pressed nothing")
	_push_key(KEY_ENTER)
	await tree.process_frame
	t.eq(_payloads.size(), 1, "the next Enter presses the focused button")


func test_a_click_before_the_stamp_skips_and_after_it_goes_through() -> void:
	var title := _paused_title()
	await tree.process_frame
	t.ok(not title.stamp_landed)
	_push_click(title.first_button)
	await tree.process_frame
	t.ok(title.intro_done, "a click skips the intro")
	t.eq(_payloads.size(), 0, "but doesn't press a button nobody saw")
	screen.queue_free()
	await tree.process_frame
	title = _paused_title()
	await tree.process_frame
	title._intro.custom_step(TitleScreen.LAND_AT + 0.01)
	t.ok(title.stamp_landed and not title.intro_done, "landed, still fading in")
	_push_click(title.first_button)
	await tree.process_frame
	t.eq(_payloads.size(), 1, "the menu takes clicks as soon as the stamp lands")


func test_the_intro_passes_keys_by_their_label() -> void:
	var cases: Array = [
		[KEY_M, KEY_SEMICOLON, true, "the key labeled M (AZERTY) reaches the mute"],
		[KEY_COMMA, KEY_M, false, "the comma where a US M would be does not"],
		[KEY_ESCAPE, KEY_ESCAPE, true, "Esc reaches the menu"],
		[KEY_F11, KEY_F11, true, "F11 reaches the window"],
		[KEY_ENTER, KEY_ENTER, false, "Enter stays with the intro"],
	]
	for c: Array in cases:
		var e := InputEventKey.new()
		e.keycode = c[0]
		e.physical_keycode = c[1]
		e.pressed = true
		t.eq(TitleScreen._passes_through(e), c[2], c[3])


func test_the_hold_chime_puts_a_line_in_the_footer() -> void:
	await _open(TitleScreen.new(), true)
	var title := screen as TitleScreen
	t.eq(title.footer.text, TitleScreen.FOOTER)
	title.show_hold_message()
	t.eq(title.footer.text, "Your call is important to us.", "the line shows")
	await _seconds(TitleScreen.HOLD_LINE_SECONDS + 0.3)
	t.eq(title.footer.text, TitleScreen.FOOTER, "then the footer comes back")


func test_title_listens_to_the_ambience_chime() -> void:
	var amb: Node = tree.root.get_node_or_null("Ambience")
	var owned := amb == null
	if owned:
		amb = (load("res://autoload/ambience.gd") as GDScript).new()
		amb.name = "Ambience"
		tree.root.add_child(amb)
	await _open(TitleScreen.new(), true)
	amb.hold_chime.emit()
	t.eq((screen as TitleScreen).footer.text, "Your call is important to us.", "the chime puts the line up")
	if owned:
		amb.queue_free()


# --- agreement -------------------------------------------------------------------

func test_fast_signing_finishes_at_once_with_the_name() -> void:
	await _open(AgreementScreen.new(), true)
	var a := screen as AgreementScreen
	a.name_edit.text = "Pat Doe"
	a._sign()
	t.eq(_payloads, [{"name": "Pat Doe"}] as Array[Dictionary], "the same payload as always")


func test_each_typed_letter_strikes_the_typewriter() -> void:
	await _open(AgreementScreen.new(), true)
	var a := screen as AgreementScreen
	a.on_shown()
	if not a.name_edit.is_editing():
		a.name_edit.edit()
	# One key a frame, like a person typing (LineEdit reports each frame's change once).
	for ch in "Pat":
		var e := InputEventKey.new()
		e.unicode = ch.unicode_at(0)
		e.keycode = OS.find_keycode_from_string(ch.to_upper())
		e.pressed = true
		tree.root.push_input(e)
		await tree.process_frame
	t.eq(a.name_edit.text, "Pat", "typed")
	t.eq(heard.count("typewriter"), 3, "one strike per letter")


## The field would take the first Esc just to stop editing; the menu opens on
## the first press instead, and closing it hands the field back, still typing.
func test_esc_while_typing_the_name_opens_the_menu_at_once() -> void:
	var settings := _settings_node()
	await _open(AgreementScreen.new(), true)
	var a := screen as AgreementScreen
	a.on_shown()
	t.ok(a.name_edit.has_focus() and a.name_edit.is_editing(), "typing the name")
	_push_key(KEY_ESCAPE)
	await tree.process_frame
	t.ok(settings.menu.is_open(), "the first Esc opens the menu")
	t.ok(tree.paused, "and pauses the game")
	_push_key(KEY_ESCAPE)
	await tree.process_frame
	t.ok(not settings.menu.is_open(), "Esc closes it")
	t.ok(a.name_edit.has_focus() and a.name_edit.is_editing(), "the name field is back, still editing")
	var e := InputEventKey.new()
	e.keycode = KEY_Q
	e.unicode = "Q".unicode_at(0)
	e.pressed = true
	tree.root.push_input(e)
	await tree.process_frame
	t.eq(a.name_edit.text, "Q", "and typing carries on")


func test_signing_inks_stamps_hangs_up_and_clips_on_a_badge() -> void:
	await _open(AgreementScreen.new(), false)
	var a := screen as AgreementScreen
	a.name_edit.text = "  Pat Doe "
	a._sign()
	await tree.process_frame
	t.ok(a.signed and a.back_button.disabled, "signed; no going back")
	t.ok(not a.name_edit.visible and a.signature.is_visible_in_tree(), "the name is redrawn as a signature")
	t.eq(a.signature.text, "Pat Doe", "as the run will record it")
	t.eq(a.signature.get_theme_color("font_color"), Palette.INK_BLUE, "in blue ink")
	t.ok(heard.has("pen_scratch"), "with the pen")
	t.ok(a.signature.get_parent().get_parent() is HBoxContainer and not (a.signature.get_parent() is Container), "slanted in a plain holder")
	await _until(func() -> bool: return a.received != null, 2.0)
	t.ok(a.received != null and a.received.word == "RECEIVED", "RECEIVED")
	t.eq(a.received.code, "CLAIMS INTEGRITY")
	t.eq(a.received.ink, Palette.RED, "in red")
	await _until(func() -> bool: return heard.has("handset"), 2.0)
	t.ok(heard.has("stamp"), "the stamp thuds")
	t.ok(heard.find("stamp") < heard.find("handset"), "then the line hangs up")
	t.ok(a.badge == null, "no badge yet: silence first")
	# The game time the sequence's timers see from the hang-up: each frame's
	# delta, read at the frame's start, counted once the frame has run.
	var hush := 0.0
	var last := 0.0
	while a.badge == null and hush < 3.0:
		last = a.get_process_delta_time()
		await tree.process_frame
		hush += last
	t.ok(a.badge != null, "the badge comes")
	t.ok(hush >= AgreementScreen.HUSH - 0.0001, "after %.3f s of silence, not less than %.1f" % [hush, AgreementScreen.HUSH])
	t.ok(hush - last < AgreementScreen.HUSH + 0.0001, "in the frame the silence ran out (%.3f s before it)" % (hush - last))
	t.ok(a.clip_button.is_visible_in_tree() and not a.sign_button.visible, "CLIP ON BADGE replaces SIGN")
	t.eq(a.badge.player_name, "Pat Doe")
	t.eq(_payloads.size(), 0, "the screen waits for the badge to be clipped on")
	await _until(func() -> bool: return heard.has("card_tick"), 1.0)
	a.clip_button.pressed.emit()
	t.eq(_payloads, [{"name": "  Pat Doe "}] as Array[Dictionary], "the same payload as fast mode")


func test_a_blank_name_signs_as_the_default() -> void:
	await _open(AgreementScreen.new(), true)
	var a := screen as AgreementScreen
	a.name_edit.text = "   "
	t.eq(a.signed_name(), gs.DEFAULT_NAME, "the name GameState will use")


func test_show_signed_lays_out_the_signed_sheet_for_the_tour() -> void:
	await _open(AgreementScreen.new(), true)
	var a := screen as AgreementScreen
	a.name_edit.text = "Pat Doe"
	a.show_signed()
	await tree.process_frame
	await tree.process_frame
	t.ok(a.badge != null and a.badge.is_visible_in_tree(), "the badge is on the sheet")
	t.ok(a.clip_button.is_visible_in_tree(), "CLIP ON BADGE")
	t.eq(_payloads.size(), 0, "not finished")
	var sheet := (a.name_edit.get_parent().get_parent().get_parent() as Control).get_global_rect()
	var badge_rect := a.badge.get_global_rect()
	t.ok(sheet.grow(40).encloses(badge_rect), "the badge lies on the sheet: %s in %s" % [badge_rect, sheet])
	var row := (a.name_edit.get_parent() as Control).get_global_rect()
	t.ok(badge_rect.end.y < row.position.y, "clear of the signature line")
	var drawn := a.received.size * a.received.scale
	var stamp_rect := Rect2(a.received.position + (a.received.size - drawn) / 2.0, drawn)
	t.ok(stamp_rect.position.x >= a.signature.get_parent().get_global_rect().end.x, "the stamp sits beside the signature")
	for b: Button in [a.back_button, a.clip_button]:
		t.ok(not stamp_rect.intersects(b.get_global_rect()), "the stamp leaves %s clear" % b.text)
	var date := (a.name_edit.get_parent() as Control).get_child(3) as Label
	t.ok(stamp_rect.end.x <= date.get_global_rect().end.x - date.get_minimum_size().x, "and the date readable")
