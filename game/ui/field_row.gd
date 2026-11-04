class_name FieldRow
extends PanelContainer
## One clickable line on a document: a small caption and a value. In inspect mode
## it highlights on hover and reports clicks; otherwise clicks fall through to the
## document so the paper can be dragged.
##
## The pointer says which: a move hand over paper, a crosshair over a row you can
## cite. A miss (Mark.INVALID) shakes the whole document, never just the row.

signal clicked(row: FieldRow)

enum Mark { NONE, HOVER, SELECTED, VALID, INVALID }

const CAPTION_WIDTH := 150.0

var key: String = ""
var inspect: bool = false
var _hovered := false
var _mark: Mark = Mark.NONE


## A row around arbitrary content (used for multi-line rulebook entries).
static func wrap(content: Control, evidence_key: String) -> FieldRow:
	var row := FieldRow.new()
	row.key = evidence_key
	row.add_child(content)
	return row


static func create(caption: String, value: String, evidence_key: String, value_color: Color = Palette.INK, value_size: int = UiTheme.SIZE_BODY, caption_width: float = CAPTION_WIDTH) -> FieldRow:
	var row := FieldRow.new()
	row.key = evidence_key
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	if caption != "":
		var cap := UiTheme.label(caption, UiTheme.SIZE_SMALL, Palette.INK_FADED)
		cap.custom_minimum_size = Vector2(caption_width, 0)
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(cap)
	var val := UiTheme.label(value, value_size, value_color)
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(val)
	row.add_child(box)
	return row


func _init() -> void:
	mouse_default_cursor_shape = Control.CURSOR_MOVE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(func() -> void:
		_hovered = true
		_refresh())
	mouse_exited.connect(func() -> void:
		_hovered = false
		_refresh())
	_refresh()


func set_inspect(on: bool) -> void:
	inspect = on
	if not on and _mark == Mark.SELECTED:
		_mark = Mark.NONE
	set_cursor_for(false)
	_refresh()


## The pointer over this row: a crosshair while inspecting, the paper's move hand
## otherwise, and a closed hand while its paper is being dragged.
func set_cursor_for(dragging: bool) -> void:
	if dragging:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	else:
		mouse_default_cursor_shape = Control.CURSOR_CROSS if inspect else Control.CURSOR_MOVE


func set_mark(mark: Mark) -> void:
	_mark = mark
	_refresh()
	if mark == Mark.INVALID:
		var doc := _document()
		if doc:
			doc.shake()


func get_mark() -> Mark:
	return _mark


func _gui_input(event: InputEvent) -> void:
	if not inspect:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(self)


## The sheet this row is printed on.
func _document() -> DocumentView:
	var node := get_parent()
	while node != null and not (node is DocumentView):
		node = node.get_parent()
	return node as DocumentView


func _refresh() -> void:
	var color := Color(0, 0, 0, 0)
	var fill := Color(0, 0, 0, 0)
	match _mark:
		Mark.SELECTED:
			color = Palette.AMBER
			fill = Color(Palette.HIGHLIGHT, 0.35)
		Mark.VALID:
			color = Palette.RED
			fill = Color(Palette.RED, 0.15)
		Mark.INVALID:
			color = Palette.INK_FADED
			fill = Color(Palette.INK_FADED, 0.15)
		_:
			if inspect and _hovered:
				color = Palette.AMBER
				fill = Color(Palette.HIGHLIGHT, 0.2)
			elif inspect:
				color = Color(Palette.AMBER, 0.35)
	var box := UiTheme.flat_box(fill, color, 2, 6, 2)
	add_theme_stylebox_override("panel", box)
