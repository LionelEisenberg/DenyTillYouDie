class_name FloatingText
extends Label
## A short-lived "+$15" / "+3%": either drifts (down by default) and fades, or
## flies along an arc into the HUD readout it changes.

const ARC_HEIGHT := 90.0


static func spawn(parent: Control, text: String, color: Color, at: Vector2, delay: float = 0.0, drift: float = 40.0) -> void:
	var ft := _make(parent, text, color, at)
	var tween := ft.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(ft, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(ft, "position:y", at.y + drift, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ft, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ft.queue_free)


## Pops up at `from`, holds a moment, then flies along an arc to `to` in `duration`
## seconds, shrinking as it goes. `on_arrive` runs when it lands (the readout then
## updates), and the text vanishes. Freed with its parent, callback and all.
static func fly(parent: Control, text: String, color: Color, from: Vector2, to: Vector2, delay: float = 0.0, on_arrive: Callable = Callable(), duration: float = 0.45) -> FloatingText:
	var ft := _make(parent, text, color, from)
	ft.pivot_offset = ft.get_combined_minimum_size() / 2.0
	var tween := ft.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(ft, "modulate:a", 1.0, 0.08)
	tween.tween_property(ft, "position:y", from.y - 16.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var start := from - Vector2(0, 16)
	tween.tween_method(ft._arc.bind(start, to), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if on_arrive.is_valid():
		tween.tween_callback(on_arrive)
	tween.tween_property(ft, "modulate:a", 0.0, 0.08)
	tween.tween_callback(ft.queue_free)
	return ft


static func _make(parent: Control, text: String, color: Color, at: Vector2) -> FloatingText:
	var ft := FloatingText.new()
	ft.text = text
	ft.add_theme_font_size_override("font_size", UiTheme.SIZE_TITLE)
	ft.add_theme_color_override("font_color", color)
	ft.add_theme_color_override("font_outline_color", Palette.BG_DARK)
	ft.add_theme_constant_override("outline_size", 6)
	ft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ft.position = at
	ft.modulate.a = 0.0
	parent.add_child(ft)
	return ft


## One point on the flight: a straight line from `from` to `to`, bowed upward.
func _arc(t: float, from: Vector2, to: Vector2) -> void:
	position = from.lerp(to, t) + Vector2(0, -sin(PI * t) * ARC_HEIGHT)
	scale = Vector2.ONE * lerpf(1.0, 0.6, t)
