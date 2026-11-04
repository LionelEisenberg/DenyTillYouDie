extends Control
## Screen flow: title -> agreement -> [day card -> paper -> memo -> desk -> ledger] x7 -> ending.
## An enum state machine; each screen emits `done` and this decides what's next.

enum Screen { TITLE, AGREEMENT, PAPER, MEMO, DESK, LEDGER, ENDING, DAY_CARD }

const FADE_TIME := 0.25
## Black between the stamp on your own claim and the last front page.
const CUT_HOLD := 2.0

var current: ScreenBase
var current_screen: Screen = Screen.TITLE
## Tests set this to skip fades and day cards, and pass it on to each screen.
var fast: bool = false
var _fade: ColorRect
var _fade_tween: Tween
## Bumped by every go(). A transition still waiting on a fade or the cut's hold
## gives up when a newer one has started.
var _nav: int = 0


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


## Fades to `screen`. With `cut`, the old screen drops to black at once and
## the black holds CUT_HOLD seconds before the new screen fades in.
func go(screen: Screen, cut: bool = false) -> void:
	_nav += 1
	var nav := _nav
	# The fade swallows clicks while it's up, and no button holds keyboard focus
	# until on_shown(), once the new screen is fully visible.
	_block_input(true)
	_kill_fade()
	_release_own_focus()
	# The screen on its way out (a day card still counting down, say) can no
	# longer move the flow on.
	if is_instance_valid(current):
		_detach(current)
	if cut:
		_fade.color.a = 1.0
		if current:
			current.queue_free()
			current = null
		if not fast and is_inside_tree():
			await get_tree().create_timer(CUT_HOLD, false).timeout
			if nav != _nav:
				return
	elif not fast and is_inside_tree():
		_fade_tween = create_tween()
		_fade_tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
		await _fade_tween.finished
		if nav != _nav:
			return
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
		_fade_tween = create_tween()
		_fade_tween.tween_property(_fade, "color:a", 0.0, FADE_TIME)
		await _fade_tween.finished
	if nav != _nav or not is_instance_valid(shown) or shown != current:
		return
	_block_input(false)
	shown.on_shown()


## For the Esc menu's QUIT TO TITLE: drops whatever fade is under way, unpauses
## and goes to the title. The save is left alone, so Continue resumes the
## morning it was written.
func quit_to_title() -> void:
	_kill_fade()
	if is_inside_tree():
		get_tree().paused = false
	go(Screen.TITLE)


func _make(screen: Screen) -> ScreenBase:
	match screen:
		Screen.AGREEMENT:
			return AgreementScreen.new()
		Screen.DAY_CARD:
			return DayCardScreen.new()
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
		Screen.DAY_CARD:
			_paper_or_memo()
		Screen.PAPER:
			go(Screen.MEMO)
		Screen.MEMO:
			go(Screen.DESK)
		Screen.DESK:
			var over := GameState.run.ending != ""
			# The stamp on your own claim cuts straight to black.
			go(Screen.ENDING if over else Screen.LEDGER, over and bool(payload.get("cut", false)))
		Screen.LEDGER:
			if String(payload.get("ending", "")) != "":
				go(Screen.ENDING)
			else:
				_morning()
		Screen.ENDING:
			if String(payload.get("action", "")) == "retry" and GameState.load_retry(int(payload.get("day", GameState.retry_day()))):
				_morning()
			else:
				go(Screen.TITLE)


## Every morning (a new week, Continue, the night, a retry) opens on its day
## card, then the paper (from day 2) and the memo. Fast mode skips the card.
func _morning() -> void:
	if fast:
		_paper_or_memo()
	else:
		go(Screen.DAY_CARD)


func _paper_or_memo() -> void:
	var paper: Dictionary = GameState.run.morning.get("paper", {})
	go(Screen.MEMO if paper.is_empty() else Screen.PAPER)


func _kill_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


## Stops listening to `screen`'s done signal.
func _detach(screen: ScreenBase) -> void:
	for connection: Dictionary in screen.done.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == self:
			screen.done.disconnect(callable)


## Takes keyboard focus off the screens this flow shows. Focus held outside it
## (the Esc menu, on its own layer) stays where it is.
func _release_own_focus() -> void:
	if not is_inside_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()


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
