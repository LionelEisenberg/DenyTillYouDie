class_name DocumentView
extends Control
## A sheet of paper on the desk. Drag it anywhere; it comes to the front when
## grabbed. Rows built with `add_field` are evidence the player can cite.
## Stamps and notes go on `overlay`, which sits on top of the paper.
##
## Held, the sheet lifts: the paper child (never this node, so the drag math
## doesn't see it) grows a little and casts a longer shadow, then settles with a
## small bounce when let go. A missed citation shakes the whole sheet: the paper
## and its overlay jog sideways together, and this node's own position, which
## drags and the desk's slide-in tweens own, is never touched.
##
## The pointer is an open hand over the sheet and a closed one while it is held.
## A sheet set to MOUSE_FILTER_IGNORE before it enters the tree (one shown only
## to be read, like the ending's) shows a plain arrow instead.

signal evidence_clicked(key: String, row: FieldRow)

## Held paper grows to this scale and its shadow reaches LIFT_SHADOW further.
const LIFT_SCALE := 1.03
const LIFT_SHADOW := Vector2(6, 6)
## Let go, the paper dips to SETTLE_DIP and back to 1 over this long.
const SETTLE_TIME := 0.12
const SETTLE_DIP := 0.99
## Pick-up and put-down sounds play at most once per this many milliseconds.
const SOUND_GAP_MSEC := 80
## The miss shake: sideways offsets in pixels, spread evenly over SHAKE_TIME.
const SHAKE_TIME := 0.2
const SHAKE_STEPS: Array[int] = [6, -6, 5, -4, 3, -2, 1, 0]

static var _last_sound_msec: int = -SOUND_GAP_MSEC

var drag_bounds := Rect2()
var rows: Array[FieldRow] = []
var paper: PanelContainer
var body: VBoxContainer
var overlay: Control
## A member card ticks instead of rustling when picked up.
var is_card: bool = false
var _dragging := false
var _drag_offset := Vector2.ZERO
var _lifted := false
var _rest_shadow := Vector2.ZERO
var _settle: Tween
var _shake_tween: Tween
var _shaking := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	paper = PanelContainer.new()
	paper.mouse_filter = Control.MOUSE_FILTER_PASS
	paper.mouse_default_cursor_shape = Control.CURSOR_MOVE
	add_child(paper)
	body = VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 2)
	paper.add_child(body)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	paper.resized.connect(_fit)


func _ready() -> void:
	# The rows are ready by now; a sheet that ignores the mouse shows no hand.
	_refresh_cursors()


func set_paper(color: Color, width: float, border: Color = Palette.PAPER_SHADE) -> void:
	paper.add_theme_stylebox_override("panel", UiTheme.paper_box(color, border))
	paper.custom_minimum_size = Vector2(width, 0)


func add_title(text: String, size: int = UiTheme.SIZE_TITLE, color: Color = Palette.INK) -> Label:
	var l := UiTheme.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(l)
	return l


func add_text(text: String, size: int = UiTheme.SIZE_SMALL, color: Color = Palette.INK_FADED) -> Label:
	var l := UiTheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(l)
	return l


func add_rule(color: Color = Palette.PAPER_SHADE, height: float = 2.0) -> void:
	body.add_child(UiTheme.rect(color, Vector2(0, height)))


func add_space(height: float) -> void:
	body.add_child(UiTheme.rect(Color(0, 0, 0, 0), Vector2(0, height)))


func add_field(caption: String, value: String, key: String, value_color: Color = Palette.INK, value_size: int = UiTheme.SIZE_BODY) -> FieldRow:
	return add_field_in(body, caption, value, key, value_color, value_size)


## add_field into any container on the sheet (a column beside a photo, say).
func add_field_in(parent: Control, caption: String, value: String, key: String, value_color: Color = Palette.INK, value_size: int = UiTheme.SIZE_BODY, caption_width: float = FieldRow.CAPTION_WIDTH) -> FieldRow:
	var row := FieldRow.create(caption, value, key, value_color, value_size, caption_width)
	row.clicked.connect(func(r: FieldRow) -> void: evidence_clicked.emit(r.key, r))
	parent.add_child(row)
	rows.append(row)
	return row


## A two-column line ("MRI, BRAIN ... $3,400"), citable like any field.
func add_line_item(left: String, right: String, key: String, left_size: int = UiTheme.SIZE_BODY, right_size: int = UiTheme.SIZE_BODY, left_color: Color = Palette.INK) -> FieldRow:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	var l := UiTheme.label(left, left_size, left_color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)
	var r := UiTheme.label(right, right_size, Palette.INK)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(r)
	var row := FieldRow.wrap(box, key)
	row.clicked.connect(func(fr: FieldRow) -> void: evidence_clicked.emit(fr.key, fr))
	body.add_child(row)
	rows.append(row)
	return row


## A dated line ("11/03/2025  Asthma"): fixed-width date, wrapping label.
func add_dated_item(date_text: String, label_text: String, key: String) -> FieldRow:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	var d := UiTheme.label(date_text, UiTheme.SIZE_BODY, Palette.INK_FADED)
	d.custom_minimum_size = Vector2(110, 0)
	d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(d)
	var l := UiTheme.label(label_text, UiTheme.SIZE_BODY, Palette.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	var row := FieldRow.wrap(box, key)
	row.clicked.connect(func(fr: FieldRow) -> void: evidence_clicked.emit(fr.key, fr))
	body.add_child(row)
	rows.append(row)
	return row


func set_inspect(on: bool) -> void:
	for row in rows:
		row.set_inspect(on)
	_refresh_cursors()


func clear_marks() -> void:
	for row in rows:
		row.set_mark(FieldRow.Mark.NONE)


func find_row(key: String) -> FieldRow:
	for row in rows:
		if row.key == key:
			return row
	return null


func is_dragging() -> bool:
	return _dragging


## A short sideways shake, for a citation that found nothing. The paper and its
## overlay jog inside the sheet and end square on it again, so wherever a drag or
## a tween takes the sheet meanwhile, that is where it stays. Skipped when
## reduce_motion is set.
func shake() -> void:
	if Engine.get_meta("reduce_motion", false) or not is_inside_tree():
		return
	_stop_shake()
	_shaking = true
	_shake_step(0.0)
	_shake_tween = create_tween()
	_shake_tween.tween_method(_shake_step, 0.0, 1.0, SHAKE_TIME)
	_shake_tween.tween_callback(_stop_shake)


func is_shaking() -> bool:
	return _shaking


func _fit() -> void:
	size = paper.size
	overlay.size = paper.size
	pivot_offset = paper.size / 2.0
	paper.pivot_offset = paper.size / 2.0
	overlay.pivot_offset = paper.size / 2.0


func _gui_input(event: InputEvent) -> void:
	# Event positions arrive in this control's local space, so the grab point
	# stays under the cursor without asking where the OS mouse is.
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			# A sheet picked up mid-shake stops shaking in the hand.
			_stop_shake()
			_dragging = true
			_drag_offset = mb.position
			move_to_front()
			_lift(true)
			accept_event()
		elif _dragging:
			_dragging = false
			_lift(false)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		if not (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			# The release happened somewhere we never heard about.
			_dragging = false
			_lift(false)
			return
		position = _clamp(position + mm.position - _drag_offset)
		accept_event()


func _clamp(pos: Vector2) -> Vector2:
	if drag_bounds.size == Vector2.ZERO:
		return pos
	var min_visible := 60.0
	return Vector2(
		clampf(pos.x, drag_bounds.position.x - size.x + min_visible, drag_bounds.end.x - min_visible),
		clampf(pos.y, drag_bounds.position.y, drag_bounds.end.y - min_visible))


## Picks the paper up (bigger, longer shadow, closed hand) or puts it down.
func _lift(on: bool) -> void:
	if on == _lifted:
		return
	_lifted = on
	_handling_sound(on)
	_refresh_cursors()
	if _settle:
		_settle.kill()
		_settle = null
	var box := _paper_box()
	if on:
		if box:
			_rest_shadow = box.shadow_offset
			box.shadow_offset = _rest_shadow + LIFT_SHADOW
		_set_paper_scale(LIFT_SCALE)
	else:
		if box:
			box.shadow_offset = _rest_shadow
		if Engine.get_meta("reduce_motion", false) or not is_inside_tree():
			_set_paper_scale(1.0)
		else:
			_settle = create_tween()
			_settle.tween_method(_set_paper_scale, LIFT_SCALE, SETTLE_DIP, SETTLE_TIME / 2.0)
			_settle.tween_method(_set_paper_scale, SETTLE_DIP, 1.0, SETTLE_TIME / 2.0)
	paper.queue_redraw()


func _set_paper_scale(s: float) -> void:
	paper.scale = Vector2(s, s)
	overlay.scale = paper.scale


## The sheet's own stylebox (set_paper makes one per document), never the theme's.
func _paper_box() -> StyleBoxFlat:
	if not paper.has_theme_stylebox_override("panel"):
		return null
	return paper.get_theme_stylebox("panel") as StyleBoxFlat


## The pointer over the sheet and its rows: an open hand, a closed one while
## held (rows show a crosshair in inspect mode), or a plain arrow everywhere on a
## sheet that ignores the mouse, since it can't be picked up.
func _refresh_cursors() -> void:
	var still := mouse_filter == Control.MOUSE_FILTER_IGNORE
	var shape := Control.CURSOR_DRAG if _lifted else Control.CURSOR_MOVE
	if still:
		shape = Control.CURSOR_ARROW
	mouse_default_cursor_shape = shape
	paper.mouse_default_cursor_shape = shape
	for row in rows:
		if still:
			row.mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			row.set_cursor_for(_lifted)


func _handling_sound(pick: bool) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_sound_msec < SOUND_GAP_MSEC:
		return
	_last_sound_msec = now
	if pick:
		Sfx.play("card_tick" if is_card else "paper_pick")
	else:
		Sfx.play("paper_drop")


func _shake_step(t: float) -> void:
	var i := mini(int(t * SHAKE_STEPS.size()), SHAKE_STEPS.size() - 1)
	_set_shake_offset(Vector2(SHAKE_STEPS[i], 0))


## Where the paper and its overlay sit inside the sheet: zero except mid-shake.
func _set_shake_offset(offset: Vector2) -> void:
	paper.position = offset
	overlay.position = offset


func _stop_shake() -> void:
	if _shake_tween:
		_shake_tween.kill()
		_shake_tween = null
	if not _shaking:
		return
	_shaking = false
	_set_shake_offset(Vector2.ZERO)
