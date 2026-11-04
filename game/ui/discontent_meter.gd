class_name DiscontentMeter
extends Control
## Public discontent, 0-100%, with tick marks at the event thresholds. Hovering it
## explains what it does. On a rise the new segment blinks twice; crossing a
## threshold blinks that tick amber three times; from BORDER_BLINK_AT up the
## border beats between thin and thick, a shape cue as well as a color one.
## Under reduce_motion nothing flashes: the new segment and a crossed tick stay
## lit for as long as they would have blinked, and the border stays thick.

## The border starts beating here (and a buzzer sounds once on the way up).
const BORDER_BLINK_AT := 90.0
const BORDER_HZ := 1.5
## One blink: on for half of BLINK_PERIOD, off for the other half.
const BLINK_PERIOD := 0.3
const SEGMENT_BLINKS := 2
const TICK_BLINKS := 3

var value: float = 0.0
## True while discontent is at or above BORDER_BLINK_AT.
var blinking: bool = false
var _shown: float = 0.0
var _tween: Tween
var _time := 0.0
var _segment_from := 0.0
var _segment_start := -1.0
## Threshold -> the time its tick started blinking.
var _tick_start: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(300, 28)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = describe(value)


func set_value(v: float, animate: bool = true) -> void:
	var old := value
	var was_blinking := blinking
	value = v
	blinking = v >= BORDER_BLINK_AT
	tooltip_text = describe(v)
	if animate and v > old:
		_segment_from = old
		_segment_start = _time
		var crossed := false
		for threshold in Economy.THRESHOLDS:
			if old < threshold and v >= threshold:
				_tick_start[threshold] = _time
				crossed = true
		if crossed:
			Sfx.play("rumble")
		if blinking and not was_blinking:
			Sfx.play("buzz")
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_set_shown, _shown, v, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_set_shown(v)


func is_tick_blinking(threshold: int) -> bool:
	return _tick_start.has(threshold) and _time - float(_tick_start[threshold]) < TICK_BLINKS * BLINK_PERIOD


func is_segment_blinking() -> bool:
	return _segment_start >= 0.0 and _time - _segment_start < SEGMENT_BLINKS * BLINK_PERIOD


## Whether the newly added segment is drawn lit (lightened) right now.
func is_segment_lit() -> bool:
	return is_segment_blinking() and _lit(_segment_start)


## How wide a threshold's tick is drawn right now: 4 px (and amber) in the lit
## half of its blink, 2 px otherwise.
func tick_width(threshold: int) -> float:
	var lit := is_tick_blinking(threshold) and _lit(float(_tick_start[threshold]))
	return 4.0 if lit else 2.0


## How wide the border is drawn right now: 2 px, or from BORDER_BLINK_AT up a beat
## between 2 and 4 px at BORDER_HZ (a steady 4 under reduce_motion).
func border_width() -> float:
	if not blinking:
		return 2.0
	if Engine.get_meta("reduce_motion", false):
		return 4.0
	return 4.0 if sin(_time * TAU * BORDER_HZ) >= 0.0 else 2.0


## The tooltip: today's reading and what each threshold does, every number read
## from Economy.
static func describe(v: float) -> String:
	var t := Economy.THRESHOLDS
	var lines := PackedStringArray([
		"PUBLIC DISCONTENT %d%%" % roundi(v),
		"Denials raise it. Approvals lower it. -%s%% each night." % _num(Economy.NIGHT_DECAY),
		"%d%%  PROTEST: each denial adds %s%% more, for one day" % [t[0], _num(Economy.PROTEST_EXTRA)],
		"%d%%  AUDIT: uncited denials of clean claims are overturned, for one day" % t[1],
		"%d%%  HEARING: Compassion Day, approvals cost nothing" % t[2],
		"%s%%  You are let go." % _num(Economy.SCAPEGOAT_AT),
	])
	return "\n".join(lines)


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var active := blinking or is_segment_blinking()
	for threshold: int in _tick_start.keys():
		if is_tick_blinking(threshold):
			active = true
		else:
			_tick_start.erase(threshold)
			active = true
	if _segment_start >= 0.0 and not is_segment_blinking():
		_segment_start = -1.0
		active = true
	if active:
		queue_redraw()


## Whether a blink that started at `start` is in its lit half right now (always,
## under reduce_motion: lit and steady instead of flashing).
func _lit(start: float) -> bool:
	if Engine.get_meta("reduce_motion", false):
		return true
	return fmod(_time - start, BLINK_PERIOD) < BLINK_PERIOD / 2.0


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var inner := size.x - 4.0
	draw_rect(r, Palette.BG_DARK)
	var fraction := clampf(_shown / 100.0, 0.0, 1.0)
	var fill := Palette.GREEN
	if _shown >= Economy.THRESHOLDS[2]:
		fill = Palette.RED
	elif _shown >= Economy.THRESHOLDS[0]:
		fill = Palette.AMBER
	draw_rect(Rect2(Vector2(2, 2), Vector2(inner * fraction, size.y - 4)), fill)
	if is_segment_blinking():
		var from := clampf(_segment_from / 100.0, 0.0, 1.0)
		if fraction > from:
			var segment := Rect2(Vector2(2.0 + inner * from, 2), Vector2(inner * (fraction - from), size.y - 4))
			draw_rect(segment, fill.lightened(0.35) if is_segment_lit() else Palette.BG_DARK)
	for threshold in Economy.THRESHOLDS:
		var x := 2.0 + inner * threshold / 100.0
		var width := tick_width(threshold)
		draw_line(Vector2(x, 0), Vector2(x, size.y), Palette.AMBER if width > 2.0 else Palette.TEXT_DIM, width)
	draw_rect(r, Palette.RED if blinking else Palette.TEXT_DIM, false, border_width())
