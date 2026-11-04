extends Node
## Player settings and the Esc menu. Registered as the autoload "Settings"
## (after Sfx and Ambience); tests load it with load().new() unless
## /root/Settings exists.
##
## Saves sound, display and reduce-motion choices to user://settings.cfg and
## applies them at startup. Esc opens the menu (the desk keeps the first Esc
## while inspecting), M mutes on every screen (and says so), every Button gets
## the pointing hand and a clack unless it has meta "silent", and the cursors
## are pixel art. Tools (headless runs, or anything started with --script, like
## the screenshot tour) never read or write the player's file unless
## path_override is set.

## Any value changed, however it changed (the menu redraws from it).
signal changed

const PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 0.8
## A window drawing the office smaller than this gets a one-time F11 hint.
const NOTE_BELOW := 0.95
const NOTE_SECONDS := 5.0
const MUTE_NOTE_SECONDS := 2.5
const MUTED_NOTE := "Sound off. Press M to turn it back on."
const UNMUTED_NOTE := "Sound on."
const SAVE_DELAY := 0.4
const WIRED := &"_settings_wired"

## Tests point this at a scratch file.
var path_override: String = ""
var volume: float = DEFAULT_VOLUME
var muted: bool = false
var fullscreen: bool = true
var reduce_motion: bool = false
var menu: PauseMenu
var _note_shown := false
## The note on show (the scale hint or the mute line), one at a time.
var _note: CanvasLayer
var _note_label: Label
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Wired before the menu is built, so its own buttons clack too.
	get_tree().node_added.connect(_on_node_added)
	load_settings()
	apply_audio()
	apply_motion()
	apply_window()
	menu = PauseMenu.new()
	add_child(menu)
	menu.volume_changed.connect(set_volume)
	menu.mute_toggled.connect(set_muted)
	menu.display_toggle_requested.connect(toggle_fullscreen)
	menu.motion_toggled.connect(set_reduce_motion)
	menu.quit_to_title_confirmed.connect(quit_to_title)
	menu.quit_game_confirmed.connect(func() -> void: get_tree().quit())
	changed.connect(_refresh_menu)
	_refresh_menu()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)
	get_tree().root.size_changed.connect(_on_window_resized)
	if DisplayServer.get_name() != "headless":
		Cursors.install()
		# Give the window a moment to settle at its final size.
		get_tree().create_timer(1.0, true).timeout.connect(_maybe_note_scale)


func _exit_tree() -> void:
	if _save_timer != null and not _save_timer.is_stopped():
		save_settings()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _is(key, KEY_M):
		toggle_mute()
		# The open menu shows it on its MUTE button; anywhere else, say so, or a
		# stray press leaves the game silent with no clue why.
		if not menu.is_open():
			_show_note(MUTED_NOTE if muted else UNMUTED_NOTE, MUTE_NOTE_SECONDS)
		get_viewport().set_input_as_handled()
	elif _is(key, KEY_ESCAPE) and not menu.is_open():
		open_menu()
		get_viewport().set_input_as_handled()


## The key as labeled on the player's keyboard (keycode follows the layout), so
## on AZERTY only the key marked M mutes, not the comma where a US M would be.
static func _is(key: InputEventKey, code: Key) -> bool:
	return key.keycode == code


## Opens the Esc menu (also the title's OPTIONS button).
func open_menu() -> void:
	if menu.is_open():
		return
	var screen := _screen_name()
	menu.open(screen != "TitleScreen", screen in ["DeskScreen", "LedgerScreen"])
	Sfx.play("paper")


func close_menu() -> void:
	menu.close()


## Unpauses, then sends the game back to the title.
func quit_to_title() -> void:
	menu.close()
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.has_method("quit_to_title"):
		scene.call("quit_to_title")
	elif scene.has_method("go"):
		scene.call("go", 0)


# --- values -------------------------------------------------------------------

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply_audio()
	# A dragged slider changes every frame: write once it settles.
	if _save_timer != null and _save_timer.is_inside_tree():
		_save_timer.start()
	else:
		save_settings()
	changed.emit()


func set_muted(on: bool) -> void:
	muted = on
	apply_audio()
	save_settings()
	changed.emit()


func toggle_mute() -> void:
	set_muted(not muted)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_window()
	save_settings()
	changed.emit()


## The menu's DISPLAY button and F11 while it is open: flips what Settings
## holds, never a copy that might be stale.
func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)


func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	apply_motion()
	save_settings()
	changed.emit()


func apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, volume_db(volume))
	AudioServer.set_bus_mute(master, muted)


## The shared contract: other code reads Engine.get_meta("reduce_motion", false).
func apply_motion() -> void:
	Engine.set_meta("reduce_motion", reduce_motion)


func apply_window() -> void:
	if window_locked():
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if _is_fullscreen() != fullscreen:
		DisplayServer.window_set_mode(want)


## Slider position to decibels: linear, with silence at 0.
static func volume_db(value: float) -> float:
	return -80.0 if value <= 0.001 else linear_to_db(value)


## The test runner, the screenshot tour and other tools: headless, or started
## with --script. They get default settings, so their output never depends on
## the player's choices.
static func is_tool_run() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var args := OS.get_cmdline_args()
	return args.has("--script") or args.has("-s")


## Window changes are skipped for tools (the tour sets its own resolution) and
## inside the editor's game view.
static func window_locked() -> bool:
	return is_tool_run() or Engine.is_embedded_in_editor()


# --- the file ----------------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if _uses_file() and FileAccess.file_exists(_path()):
		cfg.load(_path())
	volume = clampf(float(cfg.get_value("sound", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
	muted = bool(cfg.get_value("sound", "muted", false))
	# First launch: full screen.
	fullscreen = bool(cfg.get_value("display", "fullscreen", true))
	reduce_motion = bool(cfg.get_value("access", "reduce_motion", false))
	changed.emit()


func save_settings() -> void:
	if _save_timer != null:
		_save_timer.stop()
	if not _uses_file():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("sound", "volume", volume)
	cfg.set_value("sound", "muted", muted)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("access", "reduce_motion", reduce_motion)
	var err := cfg.save(_path())
	if err != OK:
		push_warning("Could not save settings: %s" % error_string(err))


func _path() -> String:
	return path_override if path_override != "" else PATH


func _uses_file() -> bool:
	return path_override != "" or not is_tool_run()


# --- buttons, window and the scale note -------------------------------------------------

## Every Button: the pointing hand, and a clack when pressed unless it carries
## meta "silent" (checked again at press time, for meta set after it was added).
func _on_node_added(node: Node) -> void:
	var b := node as Button
	if b == null:
		return
	if b.mouse_default_cursor_shape == Control.CURSOR_ARROW:
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if b.get_meta("silent", false) or b.has_meta(WIRED):
		return
	b.set_meta(WIRED, true)
	b.pressed.connect(_clack.bind(b))


func _clack(b: Button) -> void:
	if is_instance_valid(b) and not b.get_meta("silent", false):
		Sfx.play("clack")


## F11 lives in main.gd; this notices the window change and remembers it.
func _on_window_resized() -> void:
	if window_locked():
		return
	var now := _is_fullscreen()
	if now != fullscreen:
		fullscreen = now
		save_settings()
		changed.emit()
	_maybe_note_scale()


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func scale_note_text(canvas_scale: float) -> String:
	return "This office is shown at %d%% size. Press F11 for full screen." % roundi(canvas_scale * 100.0)


## The note is for a window drawn below NOTE_BELOW; full screen already fits.
static func wants_scale_note(canvas_scale: float, is_fullscreen: bool) -> bool:
	return not is_fullscreen and canvas_scale < NOTE_BELOW


func _maybe_note_scale() -> void:
	if _note_shown or window_locked():
		return
	var s := get_tree().root.get_final_transform().get_scale().x
	if not wants_scale_note(s, _is_fullscreen()):
		return
	_note_shown = true
	_show_note(scale_note_text(s))


## The text of the note on show, or "" (tests and tools read it).
func note_text() -> String:
	return _note_label.text if is_instance_valid(_note) and is_instance_valid(_note_label) else ""


## A short note on its own layer, over everything (the Esc menu included), that
## fades away. A new note replaces the one on show.
func _show_note(text: String, seconds: float = NOTE_SECONDS) -> void:
	if is_instance_valid(_note):
		_note.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 101
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.build()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(Palette.BG_DARK, 0.92), Palette.AMBER, 2, 20, 10))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_label = UiTheme.label(text, UiTheme.SIZE_BODY, Palette.TEXT_LIGHT)
	box.add_child(_note_label)
	var top := CenterContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 80
	top.offset_bottom = 140
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(box)
	root.add_child(top)
	root.modulate.a = 0.0
	var tween := layer.create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.3)
	tween.tween_interval(seconds)
	tween.tween_property(root, "modulate:a", 0.0, 0.6)
	tween.tween_callback(layer.queue_free)
	_note = layer


func _refresh_menu() -> void:
	if menu != null:
		menu.refresh(volume, muted, fullscreen, reduce_motion)


## The class name of the screen on show: main's current screen, or the last
## screen added straight to the root (the tour and tests do that).
func _screen_name() -> String:
	var screen: Node = null
	var scene := get_tree().current_scene
	if scene != null:
		var current: Variant = scene.get("current")
		if current is ScreenBase:
			screen = current
	if screen == null:
		var kids := get_tree().root.get_children()
		for i in range(kids.size() - 1, -1, -1):
			if kids[i] is ScreenBase:
				screen = kids[i]
				break
	if screen == null or screen.get_script() == null:
		return ""
	return String((screen.get_script() as Script).get_global_name())
