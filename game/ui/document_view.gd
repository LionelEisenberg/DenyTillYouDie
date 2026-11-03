class_name DocumentView
extends Control
## A sheet of paper on the desk. Drag it anywhere; it comes to the front when
## grabbed. Rows built with `add_field` are evidence the player can cite.
## Stamps and notes go on `overlay`, which sits on top of the paper.

signal evidence_clicked(key: String, row: FieldRow)
signal grabbed(doc: DocumentView)

var drag_bounds := Rect2()
var rows: Array[FieldRow] = []
var paper: PanelContainer
var body: VBoxContainer
var overlay: Control
var _dragging := false
var _drag_offset := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	paper = PanelContainer.new()
	paper.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(paper)
	body = VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 2)
	paper.add_child(body)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	paper.resized.connect(_fit)


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
	var row := FieldRow.create(caption, value, key, value_color, value_size)
	row.clicked.connect(func(r: FieldRow) -> void: evidence_clicked.emit(r.key, r))
	body.add_child(row)
	rows.append(row)
	return row


## A two-column line ("MRI, BRAIN ... $3,400"), citable like any field.
func add_line_item(left: String, right: String, key: String, left_size: int = UiTheme.SIZE_SMALL, right_size: int = UiTheme.SIZE_SMALL, left_color: Color = Palette.INK) -> FieldRow:
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


## A dated line ("11/2025  Asthma"): fixed-width date, wrapping label.
func add_dated_item(date_text: String, label_text: String, key: String) -> FieldRow:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	var d := UiTheme.label(date_text, UiTheme.SIZE_SMALL, Palette.INK_FADED)
	d.custom_minimum_size = Vector2(80, 0)
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


func clear_marks() -> void:
	for row in rows:
		row.set_mark(FieldRow.Mark.NONE)


func find_row(key: String) -> FieldRow:
	for row in rows:
		if row.key == key:
			return row
	return null


func _fit() -> void:
	size = paper.size
	overlay.size = paper.size
	pivot_offset = paper.size / 2.0


func _gui_input(event: InputEvent) -> void:
	# Event positions arrive in this control's local space, so the grab point
	# stays under the cursor without asking where the OS mouse is.
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_dragging = true
			_drag_offset = mb.position
			move_to_front()
			grabbed.emit(self)
			accept_event()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		position = _clamp(position + mm.position - _drag_offset)
		accept_event()


func _clamp(pos: Vector2) -> Vector2:
	if drag_bounds.size == Vector2.ZERO:
		return pos
	var min_visible := 60.0
	return Vector2(
		clampf(pos.x, drag_bounds.position.x - size.x + min_visible, drag_bounds.end.x - min_visible),
		clampf(pos.y, drag_bounds.position.y, drag_bounds.end.y - min_visible))
