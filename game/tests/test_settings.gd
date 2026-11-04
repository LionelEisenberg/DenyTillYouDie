extends RefCounted
## Settings and the Esc menu, the pixel cursors, and the staff badge, headless.
## Uses /root/Settings when the autoload is registered, else its own instance.

const SETTINGS := preload("res://autoload/settings.gd")

var t: TestContext
var tree: SceneTree
var gs: Node
var settings: Node
var cfg_path := ""
var _owned := false
var _nodes: Array[Node] = []


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	gs.save_path_override = TestContext.save_path()
	cfg_path = "user://test_settings_%d.cfg" % OS.get_process_id()
	_remove(cfg_path)
	settings = tree.root.get_node_or_null("Settings")
	_owned = settings == null
	if _owned:
		settings = SETTINGS.new()
		settings.name = "Settings"
		settings.path_override = cfg_path
		tree.root.add_child(settings)
	else:
		settings.path_override = cfg_path
		settings.load_settings()
	await tree.process_frame


func after_each() -> void:
	if settings.menu.is_open():
		settings.menu.close()
	tree.paused = false
	# A shared autoload keeps its note on show into the next test otherwise.
	var note: Variant = settings.get("_note")
	if is_instance_valid(note):
		(note as Node).queue_free()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	if _owned:
		settings.queue_free()
	else:
		settings.path_override = ""
		settings.load_settings()
		settings.apply_audio()
		settings.apply_motion()
	AudioServer.set_bus_volume_db(0, 0.0)
	AudioServer.set_bus_mute(0, false)
	Engine.set_meta("reduce_motion", false)
	await tree.process_frame
	_remove(cfg_path)
	gs.delete_save()
	gs.save_path_override = ""


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _keep(n: Node) -> Node:
	_nodes.append(n)
	return n


func _push_key(code: Key) -> void:
	_push_raw(code, code)


## A key as a layout sends it: `code` is the key's label, `physical` its place
## on a US board.
func _push_raw(code: Key, physical: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = physical
		e.pressed = pressed
		tree.root.push_input(e)


# --- the Esc menu ----------------------------------------------------------------

func test_first_esc_leaves_inspect_and_the_second_opens_the_menu() -> void:
	gs.new_run("Pat Doe", 3)
	var desk := DeskScreen.new()
	desk.fast = true
	tree.root.add_child(_keep(desk))
	await tree.process_frame
	desk.call_next_patient()
	desk._set_inspect(true)
	t.ok(desk.inspect, "inspecting")
	_push_key(KEY_ESCAPE)
	await tree.process_frame
	t.ok(not desk.inspect, "the first Esc leaves inspect mode")
	t.ok(not settings.menu.is_open(), "and the menu stays closed")
	t.ok(not tree.paused, "nothing paused")
	_push_key(KEY_ESCAPE)
	await tree.process_frame
	t.ok(settings.menu.is_open(), "the second Esc opens the menu")
	t.ok(tree.paused, "and pauses the game")
	t.ok(settings.menu.visible, "the menu shows")
	t.ok(settings.menu.warning_label.text.contains("loses today's shift"), "the warning is ready")
	settings.menu.resume_button.pressed.emit()
	t.ok(not settings.menu.is_open(), "RESUME closes it")
	t.ok(not tree.paused, "and unpauses")


func test_esc_closes_the_menu_and_backs_out_of_pages() -> void:
	settings.open_menu()
	t.ok(tree.paused)
	settings.menu.how_button.pressed.emit()
	t.eq(settings.menu.page, "how", "HOW TO PLAY")
	_push_key(KEY_ESCAPE)
	await tree.process_frame
	t.eq(settings.menu.page, "main", "Esc goes back to the main page")
	t.ok(settings.menu.is_open(), "without closing")
	_push_key(KEY_ESCAPE)
	await tree.process_frame
	t.ok(not settings.menu.is_open(), "Esc on the main page closes")
	t.ok(not tree.paused)


func test_menu_focuses_resume_and_gives_focus_back() -> void:
	var button := Button.new()
	tree.root.add_child(_keep(button))
	button.grab_focus()
	settings.open_menu()
	t.eq(tree.root.gui_get_focus_owner(), settings.menu.resume_button, "RESUME takes focus")
	settings.close_menu()
	t.eq(tree.root.gui_get_focus_owner(), button, "the screen gets its focus back")


func test_slider_sets_the_master_volume() -> void:
	settings.open_menu()
	settings.menu.volume_slider.value = 50.0
	t.near(AudioServer.get_bus_volume_db(0), linear_to_db(0.5), 0.01, "50% is about -6 dB")
	t.near(settings.volume, 0.5, 0.001)
	t.eq(settings.menu.volume_label.text, "50%")
	settings.menu.volume_slider.value = 0.0
	t.eq(AudioServer.get_bus_volume_db(0), -80.0, "0% is silence, not -inf")


func test_m_toggles_mute_on_any_screen() -> void:
	t.ok(not AudioServer.is_bus_mute(0), "starts unmuted")
	_push_key(KEY_M)
	await tree.process_frame
	t.ok(AudioServer.is_bus_mute(0), "M mutes the Master bus")
	t.ok(settings.muted)
	t.eq(settings.menu.mute_button.text, "MUTED", "the menu shows it")
	_push_key(KEY_M)
	await tree.process_frame
	t.ok(not AudioServer.is_bus_mute(0), "M again unmutes")


func test_m_mutes_by_the_key_label_not_its_place() -> void:
	# AZERTY: the comma sits where a US M would be; M sits where a US ; would.
	_push_raw(KEY_COMMA, KEY_M)
	await tree.process_frame
	t.ok(not settings.muted, "the comma in the US M's place leaves the sound on")
	_push_raw(KEY_M, KEY_SEMICOLON)
	await tree.process_frame
	t.ok(settings.muted, "the key labeled M mutes")


func test_m_says_so_on_screen() -> void:
	_push_key(KEY_M)
	await tree.process_frame
	t.eq(settings.note_text(), "Sound off. Press M to turn it back on.", "a stray press explains the silence")
	_push_key(KEY_M)
	await tree.process_frame
	t.eq(settings.note_text(), "Sound on.", "the next press says so too")
	var notes := settings.get_children().filter(func(n: Node) -> bool: return n is CanvasLayer and n != settings.menu and not n.is_queued_for_deletion())
	t.eq(notes.size(), 1, "one note at a time")
	settings.open_menu()
	_push_key(KEY_M)
	await tree.process_frame
	t.ok(settings.muted, "M still mutes with the menu open")
	t.eq(settings.menu.mute_button.text, "MUTED", "where the MUTE button shows it")
	t.eq(settings.note_text(), "Sound on.", "so no note covers the menu")


func test_m_typed_into_a_name_field_does_not_mute() -> void:
	var field := LineEdit.new()
	tree.root.add_child(_keep(field))
	field.grab_focus()
	var e := InputEventKey.new()
	e.keycode = KEY_M
	e.physical_keycode = KEY_M
	e.unicode = "m".unicode_at(0)
	e.pressed = true
	tree.root.push_input(e)
	await tree.process_frame
	t.eq(field.text, "m", "the letter is typed")
	t.ok(not AudioServer.is_bus_mute(0), "and nothing mutes")


func test_display_and_motion_toggles() -> void:
	settings.open_menu()
	var was: bool = settings.fullscreen
	settings.menu.display_button.pressed.emit()
	t.eq(settings.fullscreen, not was, "DISPLAY switches the mode")
	t.eq(settings.menu.display_button.text, "FULLSCREEN" if not was else "WINDOWED")
	settings.menu.motion_button.button_pressed = true
	t.ok(settings.reduce_motion, "REDUCE MOTION on")
	t.ok(Engine.get_meta("reduce_motion", false), "the shared meta follows")
	t.eq(settings.menu.motion_button.text, "ON")
	settings.menu.motion_button.button_pressed = false
	t.ok(not Engine.get_meta("reduce_motion", true), "and off again")


func test_f11_still_works_while_the_menu_pauses_main() -> void:
	settings.open_menu()
	var was: bool = settings.fullscreen
	_push_key(KEY_F11)
	await tree.process_frame
	t.eq(settings.fullscreen, not was, "F11 switches the display from the menu")
	t.ok(settings.menu.is_open(), "and leaves the menu open")


## Values loaded after the menu was built (a shared autoload between tests, a
## reload) reach the menu, and DISPLAY and F11 flip them, not a stale copy.
func test_display_flips_the_loaded_value_not_a_stale_copy() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", false)
	cfg.save(cfg_path)
	settings.load_settings()
	t.ok(not settings.fullscreen, "the file says windowed")
	t.eq(settings.menu.display_button.text, "WINDOWED", "and the menu shows it")
	settings.open_menu()
	settings.menu.display_button.pressed.emit()
	t.ok(settings.fullscreen, "DISPLAY flips what was loaded")
	cfg.save(cfg_path)
	settings.load_settings()
	t.eq(settings.menu.display_button.text, "WINDOWED", "windowed again")
	_push_key(KEY_F11)
	await tree.process_frame
	t.ok(settings.fullscreen, "F11 in the menu flips what was loaded too")
	t.eq(settings.menu.display_button.text, "FULLSCREEN")
	t.ok(settings.menu.is_open())


func test_values_persist_and_reload() -> void:
	settings.set_volume(0.35)
	settings.set_muted(true)
	settings.set_fullscreen(false)
	settings.set_reduce_motion(true)
	settings.save_settings()
	t.ok(FileAccess.file_exists(cfg_path), "written to the override path")
	var again: Node = SETTINGS.new()
	again.path_override = cfg_path
	again.load_settings()
	t.near(again.volume, 0.35, 0.001, "volume")
	t.ok(again.muted, "mute")
	t.ok(not again.fullscreen, "windowed")
	t.ok(again.reduce_motion, "reduce motion")
	again.free()


func test_saved_values_apply_at_startup() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sound", "volume", 0.25)
	cfg.set_value("sound", "muted", true)
	cfg.set_value("access", "reduce_motion", true)
	cfg.save(cfg_path)
	var fresh: Node = SETTINGS.new()
	fresh.path_override = cfg_path
	tree.root.add_child(fresh)
	t.near(AudioServer.get_bus_volume_db(0), linear_to_db(0.25), 0.01, "volume applied")
	t.ok(AudioServer.is_bus_mute(0), "mute applied")
	t.ok(Engine.get_meta("reduce_motion", false), "reduce motion applied")
	fresh.free()


func test_first_launch_defaults_to_fullscreen() -> void:
	var fresh: Node = SETTINGS.new()
	fresh.path_override = cfg_path
	fresh.load_settings()
	t.ok(fresh.fullscreen, "no file: full screen")
	t.near(fresh.volume, SETTINGS.DEFAULT_VOLUME, 0.001)
	fresh.free()
	t.ok(SETTINGS.window_locked(), "headless never touches the window")


func test_tools_never_touch_the_players_file() -> void:
	t.ok(SETTINGS.is_tool_run(), "the test runner counts as a tool, like the tour")
	var fresh: Node = SETTINGS.new()
	t.ok(not fresh._uses_file(), "no file for tools")
	fresh.path_override = cfg_path
	t.ok(fresh._uses_file(), "unless a test names one")
	fresh.free()


func test_quit_to_title_confirms_unpauses_and_asks_main() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar quit_called := false\nfunc quit_to_title() -> void:\n\tquit_called = true\n"
	script.reload()
	var fake: Node = script.new()
	tree.root.add_child(_keep(fake))
	tree.current_scene = fake
	settings.open_menu()
	settings.menu.title_button.pressed.emit()
	t.eq(settings.menu.page, "confirm", "asks first")
	t.ok(not settings.menu.warning_label.visible, "no lost-shift warning off the desk")
	t.ok(tree.paused, "still paused while asking")
	settings.menu.confirm_button.pressed.emit()
	t.ok(not tree.paused, "unpaused")
	t.ok(not settings.menu.is_open(), "menu closed")
	t.ok(fake.quit_called, "main's quit_to_title() was called")
	tree.current_scene = null


func test_quit_to_title_falls_back_to_go_title() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar went := -1\nfunc go(screen: int) -> void:\n\twent = screen\n"
	script.reload()
	var fake: Node = script.new()
	tree.root.add_child(_keep(fake))
	tree.current_scene = fake
	settings.quit_to_title()
	t.eq(fake.went, 0, "go(0), the title")
	tree.current_scene = null


## Shown straight away (a tool's hook), the confirm page asks about the title,
## and its CONFIRM goes there; it never quits the game unasked.
func test_the_confirm_page_always_says_what_confirm_does() -> void:
	var m := PauseMenu.new()
	tree.root.add_child(_keep(m))
	var said: Array[String] = []
	m.quit_to_title_confirmed.connect(func() -> void: said.append("title"))
	m.quit_game_confirmed.connect(func() -> void: said.append("quit"))
	m.open()
	m.show_page("confirm")
	t.eq(m.confirm_title.text, "QUIT TO TITLE?", "a heading, and the safe one")
	m.confirm_button.pressed.emit()
	t.eq(said, ["title"] as Array[String], "CONFIRM goes to the title")
	m.quit_button.pressed.emit()
	t.eq(m.confirm_title.text, "QUIT THE GAME?", "QUIT GAME asks about the game")
	m.cancel_button.pressed.emit()
	m.close()
	m.open()
	m.show_page("confirm")
	t.eq(m.confirm_title.text, "QUIT TO TITLE?", "reopened, it is the title again")
	m.close()
	t.ok(not tree.paused)


func test_desk_quit_warns_and_the_title_hides_quit_to_title() -> void:
	gs.new_run("Pat Doe", 3)
	var desk := DeskScreen.new()
	desk.fast = true
	tree.root.add_child(_keep(desk))
	await tree.process_frame
	settings.open_menu()
	t.ok(settings.menu.title_button.visible, "QUIT TO TITLE on the desk")
	settings.menu.quit_button.pressed.emit()
	t.ok(settings.menu.warning_label.visible, "warns that today's shift is lost")
	t.eq(settings.menu.warning_label.text, "Your week is saved each morning. Leaving now loses today's shift.")
	settings.menu.cancel_button.pressed.emit()
	t.eq(settings.menu.page, "main", "CANCEL goes back")
	settings.close_menu()
	desk.queue_free()
	await tree.process_frame
	var title := TitleScreen.new()
	title.fast = true
	tree.root.add_child(_keep(title))
	await tree.process_frame
	settings.open_menu()
	t.ok(not settings.menu.title_button.visible, "no QUIT TO TITLE on the title")


func test_how_to_play_reads_like_a_reference_card() -> void:
	settings.open_menu()
	settings.menu.how_button.pressed.emit()
	var text := " ".join(_texts(settings.menu))
	for needle in ["QUICK REFERENCE", "NEXT!, Enter or N", "INSPECT or Space", "Esc", "Tab", "APPROVE / DENY", "Full commission.", "Half commission.", Fmt.money(Economy.COMPLIANCE_FEE)]:
		t.ok(text.contains(needle), "card mentions %s" % needle)
	t.eq(tree.root.gui_get_focus_owner(), settings.menu.back_button, "BACK is focused")


func test_the_reference_card_columns_line_up() -> void:
	settings.open_menu()
	settings.menu.how_button.pressed.emit()
	await tree.process_frame
	var grids := _grids(settings.menu)
	t.eq(grids.size(), 2, "CONTROLS and THE BASICS")
	if grids.size() != 2:
		return
	var second_x: Array[float] = []
	for g in grids:
		var keys_end := 0.0
		for i in range(0, g.get_child_count(), 2):
			keys_end = maxf(keys_end, (g.get_child(i) as Control).get_global_rect().end.x)
		var x := (g.get_child(1) as Control).get_global_rect().position.x
		t.ok(x > keys_end, "the meanings start after the longest key")
		second_x.append(x)
	t.near(second_x[0], second_x[1], 0.5, "both tables start their second column at the same x")


func _grids(node: Node) -> Array[GridContainer]:
	var out: Array[GridContainer] = []
	if node is GridContainer and (node as Control).is_visible_in_tree():
		out.append(node)
	for child in node.get_children():
		out.append_array(_grids(child))
	return out


func test_scale_note_names_the_percent() -> void:
	t.eq(SETTINGS.scale_note_text(1600.0 / 1920.0), "This office is shown at 83% size. Press F11 for full screen.")
	t.ok(SETTINGS.wants_scale_note(0.833, false), "a 1600x900 window")
	t.ok(not SETTINGS.wants_scale_note(1.0, false), "a 1920x1080 window")
	t.ok(not SETTINGS.wants_scale_note(0.7, true), "full screen already fits as best it can")


# --- every button --------------------------------------------------------------------

func test_buttons_get_a_pointing_hand_and_a_clack() -> void:
	var sfx := tree.root.get_node("Sfx")
	var heard: Array[String] = []
	var listen := func(n: String) -> void: heard.append(n)
	sfx.played.connect(listen)
	var b := Button.new()
	tree.root.add_child(_keep(b))
	t.eq(b.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "pointing hand")
	t.eq(b.pressed.get_connections().size(), 1, "one pressed connection")
	b.pressed.emit()
	t.eq(heard, ["clack"] as Array[String], "pressing it clacks")
	heard.clear()
	var quiet := Button.new()
	quiet.set_meta("silent", true)
	tree.root.add_child(_keep(quiet))
	t.eq(quiet.pressed.get_connections().size(), 0, "a silent button gets no connection")
	t.eq(quiet.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "but still the hand")
	quiet.pressed.emit()
	t.eq(heard.size(), 0, "and makes no clack")
	var late := Button.new()
	tree.root.add_child(_keep(late))
	late.set_meta("silent", true)
	late.pressed.emit()
	t.eq(heard.size(), 0, "silent set after it entered the tree is honored too")
	sfx.played.disconnect(listen)


func test_rewired_buttons_never_clack_twice() -> void:
	var holder := Control.new()
	tree.root.add_child(_keep(holder))
	var b := Button.new()
	holder.add_child(b)
	holder.remove_child(b)
	holder.add_child(b)
	t.eq(b.pressed.get_connections().size(), 1, "re-entering the tree adds nothing")


func test_cursors_are_32_px_pixel_art() -> void:
	var seen: Array[PackedByteArray] = []
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_MOVE, Input.CURSOR_DRAG, Input.CURSOR_CROSS]:
		var img: Image = Cursors.build(shape)
		t.ok(img != null, "shape %d built" % shape)
		t.eq(img.get_size(), Vector2i(32, 32), "32x32")
		var ink := 0
		var paper := 0
		var clear := 0
		for y in 32:
			for x in 32:
				var c := img.get_pixel(x, y)
				if c.a == 0.0:
					clear += 1
				elif c.is_equal_approx(Palette.INK):
					ink += 1
				elif c.is_equal_approx(Palette.PAPER) or c.is_equal_approx(Palette.PAPER_SHADE):
					paper += 1
		t.ok(ink > 0 and paper > 0 and clear > 0, "ink, paper and clear pixels (%d/%d/%d)" % [ink, paper, clear])
		t.eq(ink + paper + clear, 32 * 32, "nothing off the palette")
		t.ok(img.get_pixel(0, 0) == img.get_pixel(1, 1), "drawn in 2x2 pixels")
		var hot := Cursors.hotspot(shape)
		t.ok(hot.x >= 0 and hot.y >= 0 and hot.x < 32 and hot.y < 32, "hotspot inside")
		t.ok(not seen.has(img.get_data()), "each shape is different")
		seen.append(img.get_data())
	t.ok(Cursors.build(Input.CURSOR_IBEAM) == null, "shapes it doesn't draw stay the system's")


# --- the staff badge ----------------------------------------------------------------

func test_badge_photo_is_the_players_own_face() -> void:
	var badge := IdBadge.create("Pat Doe", 0.5)
	var own := ClaimGenerator.new(9, "Pat Doe").make_player_claim(7)
	t.eq(badge.portrait_seed, own.portrait_seed, "same seed as the player's claim")
	t.eq(badge.age, int(Scripted.PLAYER["age"]), "same age")
	var reference := PortraitView.new()
	reference.show_patient(own.portrait_seed, own.age, false)
	t.eq(badge.portrait._skin, reference._skin, "the photo shows that face")
	t.eq(badge.portrait._hair, reference._hair)
	t.ok(not badge.portrait._sick, "healthy at the physical")
	t.eq(badge.portrait.process_mode, Node.PROCESS_MODE_DISABLED, "a photo doesn't move")
	reference.free()
	badge.free()


func test_full_badge_carries_the_physical_and_the_desk() -> void:
	var badge := IdBadge.create("Pat Doe", IdBadge.FULL)
	var text := " | ".join(badge.texts())
	t.ok(text.contains("02/20/2026"), "the physical's date: %s" % text)
	t.ok(text.contains("BP 158/102"), "the blood pressure")
	t.ok(text.contains("BENEVOLENCE MUTUAL - STAFF"))
	t.ok(text.contains("Pat Doe"), "the name as signed")
	t.ok(text.contains("CLAIMS ADJUSTER #4471 - DESK 11"))
	t.eq(badge.photo_rect.size, Vector2(128, 160), "8 px blocks drawn at 4 px")
	badge.free()


func test_mini_badge_fits_the_booth_slot() -> void:
	var badge := IdBadge.create_mini("Bartholomew Richardson")
	t.eq(badge.scale_factor, IdBadge.MINI)
	t.ok(badge.size.x <= 280 and badge.size.y <= 96, "fits Rect2(16, 976, 280, 96): %s" % badge.size)
	t.eq(badge.photo_rect.size, Vector2(64, 80), "8 px blocks drawn at 2 px")
	t.ok(not " ".join(badge.texts()).contains("02/20/2026"), "the mini badge leaves out the vitals")
	var snapped := IdBadge.create("X", 0.3)
	t.eq(snapped.scale_factor, IdBadge.MINI, "other factors snap")
	snapped.free()
	t.eq(_ignores_mouse(badge), true, "the badge never takes a click")
	# Built before it joins a themed tree, the header is still centered in its
	# 192 px band (x 80 to 272), measured in the pixel font it is drawn with.
	var header_w := UiTheme.font().get_string_size(IdBadge.HEADER, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
	t.ok(header_w <= 192.0, "the header fits the band (%d px)" % header_w)
	var found := false
	for child in badge.get_children():
		if child is Label and (child as Label).text == IdBadge.HEADER:
			found = true
			t.near((child as Label).position.x + header_w / 2.0, 80.0 + 96.0, 1.0, "centered in the band")
			t.eq((child as Label).get_theme_font("font"), UiTheme.font(), "in the pixel font")
	t.ok(found, "the header is there")
	badge.free()


func _ignores_mouse(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _ignores_mouse(child):
			return false
	return true


func _texts(node: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		out.append_array(_texts(child))
	return out
