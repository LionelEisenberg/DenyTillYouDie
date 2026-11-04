class_name DayCardScreen
extends ScreenBase
## The morning's title card: the day, the date typed out, and the time clock
## punching you in at 08:00 on a beige card. It starts once it is on screen
## (on_shown) and holds a moment; a click or a key skips it from then on. Keys
## with other jobs (Esc, M, F11), modifiers and shortcuts held with them don't.

const FADE_IN := 0.5
const TYPE_STEP := 0.045
const CARD_SLIDE_TIME := 0.35
const HOLD := 1.2
## The title block centers in the screen's top TITLE_AREA px; the time card
## rests at CARD_TOP, a short gap below it.
const TITLE_AREA := 640.0
const CARD_TOP := 540.0
const SEVEN_DAYS := "Benevolence Mutual operates seven days a week."
## Keys that never skip the card: the menu and mute keys (fullscreen is an
## action, checked separately), and keys pressed on their own as part of
## something else (Alt+Tab, a screenshot).
const KEEP_KEYS: Array[Key] = [
	KEY_ESCAPE, KEY_M, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META,
	KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK, KEY_PRINT,
]
## Mouse buttons that skip the card (not the wheel or the middle button).
const SKIP_BUTTONS: Array[MouseButton] = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]

## The day to announce; 0 means the run's current day.
var day: int = 0
var day_label: Label
var date_label: Label
## Day 7 only.
var note_label: Label
var card: TimeCard
var _card_rest := Vector2.ZERO
var _playing := false
var _finished := false
## The fades, the slide and the jolt, killed by a skip so none of them pulls the
## finished card back into motion.
var _tweens: Array[Tween] = []


func _ready() -> void:
	if day <= 0:
		day = GameState.run.day
	var bg := UiTheme.rect(Color.BLACK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var top := CenterContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.offset_bottom = TITLE_AREA - SHEET_CANVAS.y
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(column)
	day_label = _centered(UiTheme.label("DAY %d" % day, UiTheme.SIZE_HUGE, Palette.PAPER))
	column.add_child(day_label)
	var date := DateUtil.game_date(day)
	date_label = _centered(UiTheme.label("%s %s" % [DateUtil.weekday(date).to_upper(), DateUtil.fmt(date)], UiTheme.SIZE_TITLE, Palette.TEXT_LIGHT))
	column.add_child(date_label)
	if day == 7:
		note_label = _centered(UiTheme.label(SEVEN_DAYS, UiTheme.SIZE_SMALL, Palette.TEXT_DIM))
		column.add_child(note_label)
	card = TimeCard.new(day)
	_card_rest = Vector2((SHEET_CANVAS.x - TimeCard.W) / 2.0, CARD_TOP)
	add_child(card)
	if fast:
		_show_all()
	else:
		day_label.modulate.a = 0.0
		date_label.visible_characters = 0
		if note_label:
			note_label.modulate.a = 0.0
		card.position = Vector2(_card_rest.x, SHEET_CANVAS.y + 10.0)


func on_shown() -> void:
	if fast:
		# Main never shows a card in fast mode; anyone who does gets it whole.
		_playing = true
		_show_all()
		_finish()
		return
	_play()


## Ends the card now, if it has started and not already ended. Everything still
## moving stops where the finished card has it.
func skip() -> void:
	if not _playing or _finished:
		return
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_show_all()
	_finish()


func _play() -> void:
	if _playing:
		return
	_playing = true
	_fade_in(day_label, FADE_IN)
	await wait(0.35)
	for i in date_label.text.length():
		if _finished:
			return
		date_label.visible_characters = i + 1
		if date_label.text[i] != " ":
			Sfx.play("typewriter")
		await wait(TYPE_STEP)
	if _finished:
		return
	if note_label:
		_fade_in(note_label, 0.4)
	_slide_card_in()
	await wait(CARD_SLIDE_TIME + 0.15)
	if _finished:
		return
	_punch()
	await wait(HOLD)
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	finish({})


func _show_all() -> void:
	day_label.modulate.a = 1.0
	date_label.visible_characters = -1
	if note_label:
		note_label.modulate.a = 1.0
	card.position = _card_rest
	card.punched = true
	card.queue_redraw()


func _fade_in(node: CanvasItem, seconds: float) -> void:
	if fast:
		node.modulate.a = 1.0
		return
	_tween().tween_property(node, "modulate:a", 1.0, seconds)


func _slide_card_in() -> void:
	if fast or Engine.get_meta("reduce_motion", false):
		card.position = _card_rest
		return
	_tween().tween_property(card, "position", _card_rest, CARD_SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The time clock bites: today's row gets IN 08:00 in red, and the card jolts.
func _punch() -> void:
	card.punch()
	Sfx.play("chunk")
	if fast or Engine.get_meta("reduce_motion", false):
		return
	var jolt := _tween()
	jolt.tween_property(card, "position:y", _card_rest.y - 6.0, 0.04)
	jolt.tween_property(card, "position:y", _card_rest.y, 0.08)


## A tween on this screen that a skip can stop.
func _tween() -> Tween:
	var tween := create_tween()
	_tweens.append(tween)
	return tween


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index in SKIP_BUTTONS:
		accept_event()
		skip()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not _playing or _finished:
		return
	if not skips(key):
		return
	get_viewport().set_input_as_handled()
	skip()


## Whether `key` skips the card. Fullscreen, the menu and mute keep their own
## jobs; a modifier alone, or a key held with Alt, Ctrl or Meta, is meant for
## something else.
static func skips(key: InputEventKey) -> bool:
	if key.is_action("fullscreen_toggle"):
		return false
	if key.keycode in KEEP_KEYS or key.physical_keycode in KEEP_KEYS:
		return false
	return not (key.alt_pressed or key.ctrl_pressed or key.meta_pressed)


## The week's time card: printed rows for each day, earlier days already
## punched in faded red, and today's row once the clock bites.
class TimeCard extends Control:
	const W := 560.0
	const H := 300.0
	const ROW_TOP := 100.0
	const ROW_H := 26.0
	const COL_DAY := 24.0
	const COL_IN := 150.0
	const COL_OUT := 330.0
	const SHIFT_START := 8 * 60
	## Matches the desk's END SHIFT punch: 08:00 plus 70 minutes per patient.
	const MINUTES_PER_PATIENT := 70

	var day := 1
	var punched := false

	func _init(for_day: int = 1) -> void:
		day = for_day
		custom_minimum_size = Vector2(W, H)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func punch() -> void:
		punched = true
		queue_redraw()

	## "IN  08:00" when today's row is punched, else "".
	func todays_punch() -> String:
		return "IN  08:00" if punched else ""

	static func out_time(for_day: int) -> String:
		var minutes := SHIFT_START + MINUTES_PER_PATIENT * ClaimGenerator.PATIENTS_PER_DAY[clampi(for_day, 1, 7) - 1]
		return "%02d:%02d" % [minutes / 60, minutes % 60]

	func _draw() -> void:
		var font := UiTheme.font()
		var faded := Color(Palette.RED, 0.55)
		draw_rect(Rect2(Vector2.ZERO, size), Palette.PAPER)
		draw_rect(Rect2(Vector2.ZERO, size), Palette.PAPER_SHADE, false, 2.0)
		# The clipped corner every punch card has.
		draw_colored_polygon(PackedVector2Array([Vector2(W - 30, 0), Vector2(W, 0), Vector2(W, 30)]), Color.BLACK)
		_text(font, "BENEVOLENCE MUTUAL  -  TIME CARD", Vector2(COL_DAY, 34), UiTheme.SIZE_BODY, Palette.INK)
		_text(font, "ADJUSTER #4471   DESK 11   WEEK OF %s" % DateUtil.fmt(DateUtil.game_date(1)), Vector2(COL_DAY, 58), UiTheme.SIZE_SMALL, Palette.INK_FADED)
		for header: Array in [["DAY", COL_DAY], ["IN", COL_IN], ["OUT", COL_OUT]]:
			_text(font, header[0], Vector2(header[1], 88), UiTheme.SIZE_SMALL, Palette.INK_FADED)
		draw_line(Vector2(16, ROW_TOP - 4), Vector2(W - 16, ROW_TOP - 4), Palette.INK_FADED, 2.0)
		for d in range(1, 8):
			var y := ROW_TOP + (d - 1) * ROW_H
			draw_line(Vector2(16, y + ROW_H - 2), Vector2(W - 16, y + ROW_H - 2), Palette.PAPER_SHADE, 1.0)
			_text(font, DateUtil.weekday(DateUtil.game_date(d)).left(3).to_upper(), Vector2(COL_DAY, y + 19), UiTheme.SIZE_SMALL, Palette.INK)
			if d < day:
				_text(font, "IN  08:00", Vector2(COL_IN, y + 19), UiTheme.SIZE_SMALL, faded)
				_text(font, "OUT %s" % out_time(d), Vector2(COL_OUT, y + 19), UiTheme.SIZE_SMALL, faded)
			elif d == day and punched:
				# A fresh punch: full red ink, a little crooked.
				draw_set_transform(Vector2(COL_IN - 6, y + 22), deg_to_rad(-2.5), Vector2.ONE)
				_text(font, todays_punch(), Vector2.ZERO, UiTheme.SIZE_BODY, Palette.RED)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _text(font: Font, text: String, at: Vector2, font_size: int, color: Color) -> void:
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
