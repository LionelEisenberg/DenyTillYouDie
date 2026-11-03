class_name ScreenBase
extends Control
## A full-window screen. Main listens for `done` and decides what comes next.

signal done(payload: Dictionary)

## Tests set this to skip waits and animations.
var fast: bool = false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func finish(payload: Dictionary = {}) -> void:
	done.emit(payload)


## Called by Main once the screen has fully faded in (at once in fast mode).
## Screens grab keyboard focus here, not in _ready: a key pressed during the
## fade must not press a default button the player hasn't seen yet.
func on_shown() -> void:
	pass


## Waits `seconds`, or not at all in fast mode.
func wait(seconds: float) -> void:
	if fast or not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout


## A sheet of paper centered on screen, returned with its content column.
func centered_paper(width: float, color: Color = Palette.PAPER) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiTheme.paper_box(color, Palette.PAPER_SHADE, 36))
	sheet.custom_minimum_size = Vector2(width, 0)
	center.add_child(sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	sheet.add_child(column)
	return column


func centered_row(children: Array[Control]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	for c in children:
		row.add_child(c)
	return row
