class_name ServingBoard
extends Control
## The red NOW SERVING counter on the booth wall: four seven-segment digits drawn
## with rectangles, no font. Tickets run in the double digits, so the leftmost
## digit sits dark all week.

const DIGITS := 4
const DIGIT_SIZE := Vector2(26, 46)
const SEGMENT := 5.0
const GAP := 8.0
const PAD := Vector2(12, 8)
const CAPTION_H := 18.0
const BOARD_SIZE := Vector2(PAD.x * 2 + DIGITS * 26 + (DIGITS - 1) * 8, PAD.y * 2 + CAPTION_H + 46)
const ROLL_STEP := 0.06
## Lit segments per digit, bits a b c d e f g = 1 2 4 8 16 32 64
## (a top, b upper right, c lower right, d bottom, e lower left, f upper left, g middle).
const SEGMENTS: Array[int] = [63, 6, 91, 79, 102, 109, 125, 7, 127, 111]

## The ticket the board settles on. Set at once, even while the digits roll.
var value: int = -1
var _shown: int = -1
var _roll_serial := 0
var _rng := RandomNumberGenerator.new()
var _housing := Palette.BG_DARK.darkened(0.35)
var _lit := Palette.RED.lightened(0.38)
var _glow := Color(Palette.RED.lightened(0.2), 0.22)
var _dim := Color(Palette.RED_DARK, 0.22)


func _init() -> void:
	size = BOARD_SIZE
	custom_minimum_size = BOARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows ticket `n`. Animated, the digits roll through two or three other numbers
## with a relay click each, then settle with a chime (unless `chime` is false).
func show_ticket(n: int, animate: bool, chime: bool = true) -> void:
	value = n
	_roll_serial += 1
	var serial := _roll_serial
	if not animate or not is_inside_tree():
		_shown = n
		queue_redraw()
		return
	_rng.seed = hash([n, "roll"])
	for i in _rng.randi_range(2, 3):
		_shown = _rng.randi_range(0, 999)
		queue_redraw()
		Sfx.play("relay")
		await get_tree().create_timer(ROLL_STEP).timeout
		if serial != _roll_serial:
			return
	_shown = n
	queue_redraw()
	if chime:
		Sfx.play("chime")


## The number on the board right now (rolling or settled), -1 when blank.
func shown() -> int:
	return _shown


## Whether the leftmost digit is lit. Only a four-digit ticket lights it.
func fourth_lit() -> bool:
	return _shown >= 1000


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _housing)
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BG_DARK.darkened(0.6), false, 2.0)
	var font := UiTheme.font()
	var caption := "NOW SERVING"
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
	draw_string(font, Vector2((size.x - width) / 2.0, PAD.y + 12).round(), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, Palette.TEXT_DIM)
	for i in DIGITS:
		var place := DIGITS - 1 - i # 3 for the leftmost digit.
		var origin := Vector2(PAD.x + i * (DIGIT_SIZE.x + GAP), PAD.y + CAPTION_H)
		var mask := 0
		if _shown >= 0 and (place < 3 or _shown >= 1000):
			mask = SEGMENTS[(_shown / int(pow(10, place))) % 10]
		_draw_digit(origin, mask)


func _draw_digit(origin: Vector2, mask: int) -> void:
	var w := DIGIT_SIZE.x
	var h := DIGIT_SIZE.y
	var t := SEGMENT
	var half := h / 2.0
	var rects: Array[Rect2] = [
		Rect2(t, 0, w - 2 * t, t), # a
		Rect2(w - t, t, t, half - 1.5 * t), # b
		Rect2(w - t, half + t / 2.0, t, half - 1.5 * t), # c
		Rect2(t, h - t, w - 2 * t, t), # d
		Rect2(0, half + t / 2.0, t, half - 1.5 * t), # e
		Rect2(0, t, t, half - 1.5 * t), # f
		Rect2(t, half - t / 2.0, w - 2 * t, t), # g
	]
	for s in rects.size():
		var r := Rect2(origin + rects[s].position, rects[s].size)
		if mask & (1 << s):
			draw_rect(r.grow(2.0), _glow)
			draw_rect(r, _lit)
		else:
			draw_rect(r, _dim)
