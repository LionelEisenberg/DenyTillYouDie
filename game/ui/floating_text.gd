class_name FloatingText
extends Label
## A short-lived "+$15" / "+3%" that drifts (down by default) and fades.


static func spawn(parent: Control, text: String, color: Color, at: Vector2, delay: float = 0.0, drift: float = 40.0) -> void:
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
	var tween := ft.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(ft, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(ft, "position:y", at.y + drift, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ft, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ft.queue_free)
