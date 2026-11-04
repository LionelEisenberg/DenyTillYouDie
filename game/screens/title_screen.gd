class_name TitleScreen
extends ScreenBase
## Title: continue a saved week, start a new one, options, or quit. The DENIED
## stamp slams down first and the menu fades in under it; any key or click skips
## ahead, and the menu takes clicks as soon as the stamp has landed.

## When the stamp lands, counted from the screen opening.
const LAND_AT := 0.4
const FALL_TIME := 0.12
const REVEAL_TIME := 0.3
const FOOTER := "We care.*            *Terms, conditions and exclusions apply."
const HOLD_LINE := "Your call is important to us."
const HOLD_LINE_SECONDS := 4.0
const CONTROLS := "F11 fullscreen  -  M mute  -  Esc menu"

## CONTINUE when there's a save, otherwise NEW GAME. Focused by on_shown().
var first_button: Button
var options_button: Button
var stamp: StampMark
var footer: Label
var controls_label: Label
## From the moment the stamp lands, clicks reach the menu.
var stamp_landed: bool = false
## The stamp is down and the menu fully shown.
var intro_done: bool = false

var _center: CenterContainer
var _reveal: Array[Control] = []
var _intro: Tween
var _hold_tween: Tween


func _ready() -> void:
	add_child(_fill(Palette.BG_DARK))
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.add_child(column)

	# Containers reset rotation, so the tilted stamp sits in a plain holder.
	stamp = StampMark.create(false, "")
	stamp.rotation_degrees = -8.0
	var holder := Control.new()
	holder.custom_minimum_size = stamp.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(stamp)
	var stamp_row := CenterContainer.new()
	stamp_row.custom_minimum_size = Vector2(0, 120)
	stamp_row.add_child(holder)
	column.add_child(stamp_row)

	var title := UiTheme.label("DENY 'TIL YOU DIE", UiTheme.SIZE_HUGE, Palette.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := UiTheme.label("A BENEVOLENCE MUTUAL EMPLOYEE EXPERIENCE", UiTheme.SIZE_BODY, Palette.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(UiTheme.rect(Color(0, 0, 0, 0), Vector2(0, 40)))
	_reveal.append_array([title, subtitle] as Array[Control])

	if GameState.has_save():
		var resume := _menu_button("CONTINUE  (DAY %d)" % GameState.saved_day(), column)
		resume.pressed.connect(func() -> void: finish({"action": "continue"}))
		first_button = resume
	var start := _menu_button("NEW GAME", column)
	start.pressed.connect(func() -> void: finish({"action": "new"}))
	if first_button == null:
		first_button = start
	options_button = _menu_button("OPTIONS", column)
	options_button.pressed.connect(_open_options)
	options_button.disabled = _settings() == null
	var quit := _menu_button("QUIT", column)
	quit.pressed.connect(func() -> void: get_tree().quit())

	footer = UiTheme.label(FOOTER, UiTheme.SIZE_SMALL, Palette.TEXT_DIM)
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.position.y -= 48
	footer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)
	controls_label = UiTheme.label(CONTROLS, UiTheme.SIZE_SMALL, Palette.TEXT_DIM)
	controls_label.position = Vector2(24, 1080 - 40)
	add_child(controls_label)
	_reveal.append_array([footer, controls_label] as Array[Control])

	var ambience := get_node_or_null("/root/Ambience")
	if ambience != null and ambience.has_signal("hold_chime"):
		ambience.connect("hold_chime", show_hold_message)
	if fast:
		intro_done = true
		stamp_landed = true
	else:
		_play_intro()


func on_shown() -> void:
	first_button.grab_focus()


## Jumps to the end of the intro: stamp down, menu shown.
func skip_intro() -> void:
	if intro_done:
		return
	if _intro:
		_intro.kill()
	if not stamp_landed:
		stamp_landed = true
		Sfx.play("stamp")
	stamp.modulate.a = 1.0
	stamp.scale = Vector2.ONE
	for item in _reveal:
		item.modulate.a = 1.0
	intro_done = true


## The hold music's chime: the footer reads the line for a few seconds.
func show_hold_message() -> void:
	footer.text = HOLD_LINE
	if _hold_tween:
		_hold_tween.kill()
	_hold_tween = create_tween()
	_hold_tween.tween_interval(HOLD_LINE_SECONDS)
	_hold_tween.tween_callback(func() -> void: footer.text = FOOTER)


# A key during the intro skips it and never reaches the (still unseen) focused
# button; F11, M and Esc still do their jobs. A click skips it too, and from the
# moment the stamp lands it also goes through to the menu.
func _input(event: InputEvent) -> void:
	if intro_done:
		return
	var mouse := event as InputEventMouseButton
	var key := event as InputEventKey
	if mouse != null and mouse.pressed:
		var landed := stamp_landed
		skip_intro()
		if not landed:
			get_viewport().set_input_as_handled()
	elif key != null and key.pressed and not key.echo:
		skip_intro()
		if not _passes_through(key):
			get_viewport().set_input_as_handled()


## By keycode, the key as labeled in the player's layout (as Settings reads M).
static func _passes_through(key: InputEventKey) -> bool:
	return key.keycode in [KEY_F11, KEY_M, KEY_ESCAPE] or key.is_action_pressed("fullscreen_toggle")


func _play_intro() -> void:
	stamp.modulate.a = 0.0
	for item in _reveal:
		item.modulate.a = 0.0
	var motion: bool = not Engine.get_meta("reduce_motion", false)
	_intro = create_tween()
	_intro.tween_interval(LAND_AT - FALL_TIME)
	_intro.tween_callback(func() -> void:
		stamp.modulate.a = 1.0
		stamp.scale = Vector2(1.6, 1.6) if motion else Vector2.ONE)
	if motion:
		_intro.tween_property(stamp, "scale", Vector2.ONE, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		_intro.tween_interval(FALL_TIME)
	_intro.tween_callback(_land)
	for i in _reveal.size():
		var track := _intro.parallel() if i > 0 else _intro
		track.tween_property(_reveal[i], "modulate:a", 1.0, REVEAL_TIME)
	_intro.tween_callback(func() -> void: intro_done = true)


func _land() -> void:
	stamp_landed = true
	Sfx.play("stamp")
	if Engine.get_meta("reduce_motion", false):
		return
	var shake := create_tween()
	for offset: Vector2 in [Vector2(-6, 3), Vector2(5, -3), Vector2(-3, 2), Vector2(2, -1)]:
		shake.tween_property(_center, "position", offset, 0.03)
	shake.tween_property(_center, "position", Vector2.ZERO, 0.04)


func _open_options() -> void:
	var settings := _settings()
	if settings != null and settings.has_method("open_menu"):
		settings.call("open_menu")


func _settings() -> Node:
	return get_node_or_null("/root/Settings")


func _menu_button(text: String, parent: Control) -> Button:
	var holder := CenterContainer.new()
	var b := UiTheme.button(text, UiTheme.SIZE_TITLE, 420)
	b.custom_minimum_size = Vector2(420, 64)
	holder.add_child(b)
	parent.add_child(holder)
	_reveal.append(holder)
	return b


func _fill(color: Color) -> ColorRect:
	var r := UiTheme.rect(color)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r
