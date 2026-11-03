class_name DiscontentMeter
extends Control
## Public discontent, 0-100%, with tick marks at the event thresholds.

var value: float = 0.0
var _shown: float = 0.0
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(300, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float, animate: bool = true) -> void:
	value = v
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_set_shown, _shown, v, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_set_shown(v)


func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Palette.BG_DARK)
	var fraction := clampf(_shown / 100.0, 0.0, 1.0)
	var fill := Palette.GREEN
	if _shown >= Economy.THRESHOLDS[2]:
		fill = Palette.RED
	elif _shown >= Economy.THRESHOLDS[0]:
		fill = Palette.AMBER
	draw_rect(Rect2(Vector2(2, 2), Vector2((size.x - 4) * fraction, size.y - 4)), fill)
	for threshold in Economy.THRESHOLDS:
		var x := 2.0 + (size.x - 4) * threshold / 100.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), Palette.TEXT_DIM, 2.0)
	draw_rect(r, Palette.TEXT_DIM, false, 2.0)
