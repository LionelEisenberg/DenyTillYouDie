class_name MemoScreen
extends ScreenBase
## The morning memo from R. Hargrove, followed by any letters.

var _pages: Array[Control] = []
var _page: int = 0
var _button: Button


func _ready() -> void:
	var bg := UiTheme.rect(Palette.DESK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var morning: Dictionary = GameState.run.morning
	_pages.append(_memo_page(morning.get("memo", {})))
	for letter: Dictionary in morning.get("letters", []):
		_pages.append(_letter_page(letter))
	for p in _pages:
		add_child(p)
	_button = UiTheme.button("", UiTheme.SIZE_BODY, 320)
	_button.position = Vector2(1920 - 380, 1080 - 96)
	_button.pressed.connect(_advance)
	add_child(_button)
	_show(0)


func _advance() -> void:
	if _page < _pages.size() - 1:
		Sfx.play("paper")
		_show(_page + 1)
	else:
		finish({})


func _show(page: int) -> void:
	_page = page
	for i in _pages.size():
		_pages[i].visible = i == page
	_button.text = "READ LETTER" if page < _pages.size() - 1 else "BEGIN SHIFT  (DAY %d)" % GameState.run.day
	_button.call_deferred("grab_focus")


func _memo_page(memo: Dictionary) -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(center)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiTheme.paper_box(Palette.MEMO, Palette.PAPER_SHADE, 40))
	sheet.custom_minimum_size = Vector2(1240, 0)
	center.add_child(sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	sheet.add_child(column)
	column.add_child(UiTheme.label("BENEVOLENCE MUTUAL  -  INTERNAL MEMORANDUM", UiTheme.SIZE_TITLE, Palette.INK))
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))
	for pair in [["TO", memo.get("to", "")], ["FROM", memo.get("from", "")], ["DATE", memo.get("date", "")], ["RE", memo.get("subject", "")]]:
		var row := HBoxContainer.new()
		var cap := UiTheme.label(pair[0], UiTheme.SIZE_SMALL, Palette.INK_FADED)
		cap.custom_minimum_size = Vector2(90, 0)
		row.add_child(cap)
		row.add_child(UiTheme.label(String(pair[1]), UiTheme.SIZE_BODY, Palette.INK))
		column.add_child(row)
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))
	for paragraph: String in memo.get("paragraphs", []):
		column.add_child(UiTheme.para(paragraph, 1160, UiTheme.SIZE_BODY, Palette.INK))
	column.add_child(UiTheme.label("R. Hargrove", UiTheme.SIZE_TITLE, Palette.INK_BLUE))
	return page


func _letter_page(letter: Dictionary) -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(center)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiTheme.paper_box(Palette.PAPER_ALT, Palette.PAPER_SHADE, 48))
	sheet.custom_minimum_size = Vector2(900, 0)
	sheet.rotation_degrees = -1.0
	center.add_child(sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	sheet.add_child(column)
	column.add_child(UiTheme.label("MAIL ROOM: FORWARDED TO DESK 11", UiTheme.SIZE_SMALL, Palette.INK_FADED))
	for paragraph: String in letter.get("paragraphs", []):
		column.add_child(UiTheme.para(paragraph, 800, UiTheme.SIZE_BODY, Palette.INK_BLUE))
	return page
