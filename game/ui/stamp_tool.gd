class_name StampTool
extends Control
## A rubber stamp drawn in code, seen from the side: a wooden knob, neck and block
## in desk tones, an inked rubber pad, and the word on a paper label on the block.
## It lives inside its tray Button, which still takes the clicks: hovering the
## button lifts the stamp, a disabled button leaves it sitting low and gray. A paper
## tag on the handle names the rule cited; a FREE tag hangs on it on Compassion Day.
## A copy of it flies to the paper when the button is pressed.

const TOOL_SIZE := Vector2(280, 62)
const BLOCK := Vector2(208, 28)
const PAD_H := 7.0
const NECK := Vector2(26, 9)
const KNOB := Vector2(92, 17)
const HOVER_LIFT := 6.0
const SINK := 3.0

var word: String = "APPROVED"
var ink: Color = Palette.GREEN
## The paper tag on the handle ("R-01", "FREE"), or "" for none.
var tag: String = "":
	set(value):
		tag = value
		queue_redraw()
## Follow the parent Button's hover and disabled state. Off for a flying copy.
var follow_button: bool = true
var _lift := 0.0
var _hovered := false
var _disabled := false
var _wood := Palette.DESK_LIGHT.lightened(0.24)
var _outline := Palette.DESK_DARK.darkened(0.5)


static func create(approved: bool) -> StampTool:
	var t := StampTool.new()
	t.word = "APPROVED" if approved else "DENIED"
	t.ink = Palette.GREEN if approved else Palette.RED
	return t


func _init() -> void:
	size = TOOL_SIZE
	custom_minimum_size = TOOL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A copy for the flight to the paper: the same stamp, held in the hand.
func copy() -> StampTool:
	var t := StampTool.new()
	t.word = word
	t.ink = ink
	t.tag = tag
	t.follow_button = false
	return t


## Where the middle of the rubber pad is, in this control's coordinates (resting).
func pad_center() -> Vector2:
	return Vector2(size.x / 2.0, _base_y() - PAD_H / 2.0)


func _process(delta: float) -> void:
	if not follow_button:
		return
	var button := get_parent() as Button
	if button == null:
		return
	var hovered := button.is_hovered() and not button.disabled
	var target := SINK if button.disabled else (-HOVER_LIFT if hovered else 0.0)
	var lift := move_toward(_lift, target, delta * 60.0)
	if lift != _lift or hovered != _hovered or button.disabled != _disabled:
		_lift = lift
		_hovered = hovered
		_disabled = button.disabled
		queue_redraw()


## The line the pad rests on.
func _base_y() -> float:
	return size.y - 4.0


func _draw() -> void:
	var cx := size.x / 2.0
	var base := _base_y()
	var y := base + _lift
	if follow_button:
		# The shadow on the tray: wider and fainter the higher the stamp is held.
		var height := clampf(base - y, 0.0, 12.0)
		var shadow_w := BLOCK.x * (0.9 + height * 0.02)
		draw_rect(Rect2(cx - shadow_w / 2.0, base - 1.0, shadow_w, 5.0), Color(0, 0, 0, 0.35 - height * 0.015))
	var gray := 0.45 if _disabled else 0.0
	var wood := _tone(_wood, gray)
	var line := _tone(_outline, gray)
	# The inked rubber pad.
	var pad := Rect2(cx - BLOCK.x / 2.0 + 8.0, y - PAD_H, BLOCK.x - 16.0, PAD_H)
	draw_rect(pad, _tone(ink.darkened(0.1), gray))
	draw_rect(Rect2(pad.position.x, pad.end.y - 2.0, pad.size.x, 2.0), _tone(ink.darkened(0.45), gray))
	draw_rect(pad, line, false, 2.0)
	# The wooden block, with a paper label lettered with the word.
	var block := Rect2(cx - BLOCK.x / 2.0, pad.position.y - BLOCK.y, BLOCK.x, BLOCK.y)
	draw_rect(block, wood)
	draw_rect(Rect2(block.position, Vector2(block.size.x, 3.0)), wood.lightened(0.16))
	draw_rect(Rect2(block.position.x, block.end.y - 4.0, block.size.x, 4.0), wood.darkened(0.25))
	draw_rect(block, line, false, 2.0)
	var label := block.grow_individual(-38.0, -5.0, -38.0, -6.0)
	draw_rect(label, _tone(Palette.PAPER_ALT, gray))
	var font := UiTheme.font()
	var word_w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BODY).x
	draw_string(font, Vector2(cx - word_w / 2.0, label.end.y - 2.0).round(), word, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BODY, _tone(ink.darkened(0.15), gray))
	# The neck, and the knob the hand holds.
	var neck := Rect2(cx - NECK.x / 2.0, block.position.y - NECK.y, NECK.x, NECK.y)
	draw_rect(neck, wood.darkened(0.18))
	draw_rect(neck, line, false, 2.0)
	var k := Rect2(cx - KNOB.x / 2.0, neck.position.y - KNOB.y, KNOB.x, KNOB.y)
	var knob := PackedVector2Array([
		Vector2(k.position.x + 5, k.position.y), Vector2(k.end.x - 5, k.position.y),
		Vector2(k.end.x, k.position.y + 5), Vector2(k.end.x, k.end.y - 3),
		Vector2(k.end.x - 3, k.end.y), Vector2(k.position.x + 3, k.end.y),
		Vector2(k.position.x, k.end.y - 3), Vector2(k.position.x, k.position.y + 5),
	])
	draw_colored_polygon(knob, wood.lightened(0.05))
	draw_rect(Rect2(k.position.x + 10.0, k.position.y + 3.0, KNOB.x - 30.0, 3.0), wood.lightened(0.28))
	draw_rect(Rect2(k.position.x + 3.0, k.end.y - 5.0, KNOB.x - 6.0, 3.0), wood.darkened(0.22))
	knob.append(knob[0])
	draw_polyline(knob, line, 2.0)
	if tag != "":
		_draw_tag(neck, gray)


## A small paper tag tied to the neck, hanging to the right of the knob.
func _draw_tag(neck: Rect2, gray: float) -> void:
	var font := UiTheme.font()
	var text_w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
	var box := Rect2(neck.end.x + 40.0, neck.position.y - 14.0, text_w + 14.0, 19.0)
	draw_line(Vector2(neck.end.x, neck.get_center().y), Vector2(box.position.x + 4.0, box.position.y + 6.0), _tone(Palette.PAPER_SHADE, gray), 1.0)
	draw_rect(box, _tone(Palette.PAPER, gray))
	draw_rect(box, _tone(Palette.PAPER_SHADE.darkened(0.35), gray), false, 1.0)
	draw_circle(Vector2(box.position.x + 4.0, box.position.y + 6.0), 1.5, _tone(Palette.INK_FADED, gray))
	var color := Palette.GREEN_DARK if tag == "FREE" else Palette.RED_DARK
	draw_string(font, Vector2(box.position.x + 8.0, box.end.y - 5.0).round(), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, _tone(color, gray))


## `c` washed toward gray by `amount` (a disabled stamp).
func _tone(c: Color, amount: float) -> Color:
	if amount <= 0.0:
		return c
	var v := c.get_luminance()
	return c.lerp(Color(v, v, v, c.a), amount).darkened(0.12 * amount)
