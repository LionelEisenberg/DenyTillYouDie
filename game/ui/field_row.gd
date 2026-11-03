class_name FieldRow
extends PanelContainer
## One clickable line on a document: a small caption and a value. In inspect mode
## it highlights on hover and reports clicks; otherwise clicks fall through to the
## document so the paper can be dragged.

signal clicked(row: FieldRow)

enum Mark { NONE, HOVER, SELECTED, VALID, INVALID }

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


static func create(caption: String, value: String, evidence_key: String, value_color: Color = Palette.INK, value_size: int = UiTheme.SIZE_BODY) -> FieldRow:
	var row := FieldRow.new()
	row.key = evidence_key
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	if caption != "":
		var cap := UiTheme.label(caption, UiTheme.SIZE_SMALL, Palette.INK_FADED)
		cap.custom_minimum_size = Vector2(150, 0)
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(cap)
	var val := UiTheme.label(value, value_size, value_color)
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(val)
	row.add_child(box)
	return row


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
	_refresh()


func set_mark(mark: Mark) -> void:
	_mark = mark
	_refresh()


func get_mark() -> Mark:
	return _mark


func _gui_input(event: InputEvent) -> void:
	if not inspect:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(self)


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
