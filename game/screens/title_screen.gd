class_name TitleScreen
extends ScreenBase
## Title: continue a saved week, start a new one, or quit.


func _ready() -> void:
	add_child(_fill(Palette.BG_DARK))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	var stamp := StampMark.create(false, "")
	stamp.rotation_degrees = -8.0
	var stamp_holder := CenterContainer.new()
	stamp_holder.custom_minimum_size = Vector2(0, 110)
	stamp_holder.add_child(stamp)
	column.add_child(stamp_holder)

	var title := UiTheme.label("DENY 'TIL YOU DIE", UiTheme.SIZE_HUGE, Palette.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := UiTheme.label("A BENEVOLENCE MUTUAL EMPLOYEE EXPERIENCE", UiTheme.SIZE_BODY, Palette.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(UiTheme.rect(Color(0, 0, 0, 0), Vector2(0, 40)))

	var first: Button
	if GameState.has_save():
		var resume := _menu_button("CONTINUE  (DAY %d)" % GameState.saved_day(), column)
		resume.pressed.connect(func() -> void: finish({"action": "continue"}))
		first = resume
	var start := _menu_button("NEW GAME", column)
	start.pressed.connect(func() -> void: finish({"action": "new"}))
	if first == null:
		first = start
	var quit := _menu_button("QUIT", column)
	quit.pressed.connect(func() -> void: get_tree().quit())
	first.call_deferred("grab_focus")

	var footer := UiTheme.label("We care.*            *Terms, conditions and exclusions apply.", UiTheme.SIZE_SMALL, Palette.TEXT_DIM)
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.position.y -= 48
	footer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)
	var controls := UiTheme.label("F11 toggles fullscreen", UiTheme.SIZE_SMALL, Palette.WALL_LIGHT)
	controls.position = Vector2(24, 1080 - 40)
	add_child(controls)


func _menu_button(text: String, parent: Control) -> Button:
	var holder := CenterContainer.new()
	var b := UiTheme.button(text, UiTheme.SIZE_TITLE, 420)
	b.custom_minimum_size = Vector2(420, 64)
	holder.add_child(b)
	parent.add_child(holder)
	return b


func _fill(color: Color) -> ColorRect:
	var r := UiTheme.rect(color)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r
