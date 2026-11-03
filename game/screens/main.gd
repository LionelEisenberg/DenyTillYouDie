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
var _busy := false


func _ready() -> void:
	theme = UiTheme.build()
	var bg := UiTheme.rect(Palette.BG_DARK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_fade = UiTheme.rect(Color(0, 0, 0, 1))
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	go(Screen.TITLE)


func go(screen: Screen) -> void:
	_busy = true
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
	if fast or not is_inside_tree():
		_fade.color.a = 0.0
	else:
		var back := create_tween()
		back.tween_property(_fade, "color:a", 0.0, FADE_TIME)
		await back.finished
	_busy = false


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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen_toggle"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
