class_name ScreenBase
extends Control
## A full-window screen. Main listens for `done` and decides what comes next.
##
## Sheets of paper sit on a dark table under a pool of lamplight and arrive with
## an entrance: "slide" rises into place, "drop" lands like a thrown newspaper.

signal done(payload: Dictionary)

const SHEET_CANVAS := Vector2(1920, 1080)
const SHEET_SLIDE_RISE := 40.0
const SHEET_SLIDE_TIME := 0.25
const SHEET_DROP_HEIGHT := 60.0
const SHEET_DROP_TURN := 3.0
const SHEET_DROP_TIME := 0.28
const SHEET_SETTLE_TIME := 0.5
const LAMP_POOL_ALPHA := 0.25

## Tests set this to skip waits and animations.
var fast: bool = false
var _lamp_pool: TextureRect


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


## Waits `seconds`, or not at all in fast mode. The clock stops while the game
## is paused (the Esc menu), so nothing plays out behind the menu.
func wait(seconds: float) -> void:
	if fast or not is_inside_tree():
		return
	await get_tree().create_timer(seconds, false).timeout


## A sheet of paper centered on screen, returned with its content column. The
## sheet arrives with `entrance` ("slide" or "drop") over the lamp pool.
func centered_paper(width: float, color: Color = Palette.PAPER, entrance: String = "slide") -> VBoxContainer:
	add_lamp_pool()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := sheet_in(center, width, color)
	sheet_entrance(center, entrance)
	return column


## A sheet of paper inside `holder` (usually a CenterContainer), returned with
## its content column.
func sheet_in(holder: Control, width: float, color: Color = Palette.PAPER) -> VBoxContainer:
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiTheme.paper_box(color, Palette.PAPER_SHADE, 36))
	sheet.custom_minimum_size = Vector2(width, 0)
	holder.add_child(sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	sheet.add_child(column)
	return column


## A soft pool of warm lamplight on the dark table, under every sheet. Added
## once per screen, after its background.
func add_lamp_pool() -> void:
	if _lamp_pool != null:
		return
	var warm := Palette.PAPER.lerp(Palette.HIGHLIGHT, 0.3)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(warm, LAMP_POOL_ALPHA), Color(warm, LAMP_POOL_ALPHA * 0.4), Color(warm, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	_lamp_pool = TextureRect.new()
	_lamp_pool.name = "LampPool"
	_lamp_pool.texture = texture
	_lamp_pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lamp_pool.stretch_mode = TextureRect.STRETCH_SCALE
	_lamp_pool.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_lamp_pool.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lamp_pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lamp_pool)


## Plays an entrance on `node`, a full-window Control outside any container so
## it can move and turn (pivot at the screen's center). "slide" rises 40 px and
## fades in; "drop" falls 60 px with a 3-degree turn that settles, and lands
## with a thwap. Instant in fast mode and with reduce motion.
func sheet_entrance(node: Control, entrance: String = "slide") -> void:
	node.pivot_offset = SHEET_CANVAS / 2.0
	if fast or not is_inside_tree() or Engine.get_meta("reduce_motion", false):
		node.position = Vector2.ZERO
		node.rotation = 0.0
		node.modulate.a = 1.0
		return
	var tween := node.create_tween().set_parallel(true)
	if entrance == "drop":
		node.position = Vector2(0, -SHEET_DROP_HEIGHT)
		node.rotation_degrees = SHEET_DROP_TURN
		node.modulate.a = 0.0
		tween.tween_property(node, "modulate:a", 1.0, 0.1)
		tween.tween_property(node, "position:y", 0.0, SHEET_DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(node, "rotation_degrees", 0.0, SHEET_SETTLE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(Sfx.play.bind("thwap")).set_delay(SHEET_DROP_TIME)
	else:
		node.position = Vector2(0, SHEET_SLIDE_RISE)
		node.rotation = 0.0
		node.modulate.a = 0.0
		tween.tween_property(node, "position:y", 0.0, SHEET_SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "modulate:a", 1.0, SHEET_SLIDE_TIME)


func centered_row(children: Array[Control]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	for c in children:
		row.add_child(c)
	return row
