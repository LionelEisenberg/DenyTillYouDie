extends Control
## Screen flow: title -> agreement -> [paper -> memo -> desk -> ledger] x7 -> ending.
## An enum state machine; each screen emits `done` and this decides what's next.

enum Screen { TITLE, AGREEMENT, PAPER, MEMO, DESK, LEDGER, ENDING }

const FADE_TIME := 0.25

var current: ScreenBase
var current_screen: Screen = Screen.TITLE
## Tests set this to skip fades and pass it on to each screen.
var fast: bool = false
var _fade: ColorRect


func _ready() -> void:
	theme = UiTheme.build()
	# Smooth the pixel font only when the window scales the canvas by a fraction.
	_on_window_resized()
	get_tree().root.size_changed.connect(_on_window_resized)
	var bg := UiTheme.rect(Palette.BG_DARK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_fade = UiTheme.rect(Color(0, 0, 0, 1))
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_block_input(true)
	go(Screen.TITLE)


func go(screen: Screen) -> void:
	# The fade swallows clicks while it's up, and no button holds keyboard focus
	# until on_shown(), once the new screen is fully visible.
	_block_input(true)
	if is_inside_tree():
		get_viewport().gui_release_focus()
	if not fast and is_inside_tree():
		var out := create_tween()
		out.tween_property(_fade, "color:a", 1.0, FADE_TIME)
		await out.finished
	if current:
		current.queue_free()
	current_screen = screen
	current = _make(screen)
	current.fast = fast
	current.done.connect(_on_done.bind(screen), CONNECT_ONE_SHOT)
	add_child(current)
	move_child(_fade, -1)
	var shown := current
	if fast or not is_inside_tree():
		_fade.color.a = 0.0
	else:
		var back := create_tween()
		back.tween_property(_fade, "color:a", 0.0, FADE_TIME)
		await back.finished
	if not is_instance_valid(shown) or shown != current:
		return
	_block_input(false)
	shown.on_shown()


func _make(screen: Screen) -> ScreenBase:
	match screen:
		Screen.AGREEMENT:
			return AgreementScreen.new()
		Screen.PAPER:
			return NewspaperScreen.new()
		Screen.MEMO:
			return MemoScreen.new()
		Screen.DESK:
			return DeskScreen.new()
		Screen.LEDGER:
			return LedgerScreen.new()
		Screen.ENDING:
			return EndingScreen.new()
	return TitleScreen.new()


func _on_done(payload: Dictionary, from: Screen) -> void:
	match from:
		Screen.TITLE:
			if payload.get("action") == "continue" and GameState.load_game():
				_morning()
			else:
				go(Screen.AGREEMENT)
		Screen.AGREEMENT:
			if payload.get("back", false):
				go(Screen.TITLE)
			else:
				GameState.new_run(String(payload.get("name", "")))
				_morning()
		Screen.PAPER:
			go(Screen.MEMO)
		Screen.MEMO:
			go(Screen.DESK)
		Screen.DESK:
			go(Screen.ENDING if GameState.run.ending != "" else Screen.LEDGER)
		Screen.LEDGER:
			if String(payload.get("ending", "")) != "":
				go(Screen.ENDING)
			else:
				_morning()
		Screen.ENDING:
			go(Screen.TITLE)


func _morning() -> void:
	var paper: Dictionary = GameState.run.morning.get("paper", {})
	go(Screen.MEMO if paper.is_empty() else Screen.PAPER)


## The fade rect stops the mouse while it covers the screen, and lets it
## through once it's fully transparent.
func _block_input(on: bool) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _on_window_resized() -> void:
	UiTheme.fit_font_to_window(get_tree().root)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen_toggle"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
