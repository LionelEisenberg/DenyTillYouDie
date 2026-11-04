class_name MemoScreen
extends ScreenBase
## The morning memo from R. Hargrove, followed by any letters. A letter that
## came with a photo (`photo_seed`, `photo_age`) has it paper-clipped on top.

const FILED_NOTE := "A copy has been filed in your manual."
const SNAPSHOT_BLOCK := 2

var _pages: Array[Control] = []
var _page: int = 0
var _button: Button
## Shown with the memo: the paper workstream's manual keeps today's memo.
var _filed: Label
## The snapshot clipped to each letter page that has one.
var snapshots: Array[NewsPhoto] = []


func _ready() -> void:
	var bg := UiTheme.rect(Palette.DESK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_lamp_pool()
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
	_filed = UiTheme.label(FILED_NOTE, UiTheme.SIZE_SMALL, Palette.TEXT_LIGHT)
	_filed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_filed.size = Vector2(480, 24)
	_filed.position = Vector2(1920 - 60 - 480, 1080 - 96 - 32)
	add_child(_filed)
	_show(0)


func on_shown() -> void:
	_button.grab_focus()


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
	sheet_entrance(_pages[page], "slide")
	_filed.visible = page == 0
	_button.text = "READ LETTER" if page < _pages.size() - 1 else "BEGIN SHIFT  (DAY %d)" % GameState.run.day


func _page_control() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return page


func _memo_page(memo: Dictionary) -> Control:
	var page := _page_control()
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
	var page := _page_control()
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
	var header := HBoxContainer.new()
	var from := UiTheme.label("MAIL ROOM: FORWARDED TO DESK 11", UiTheme.SIZE_SMALL, Palette.INK_FADED)
	from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	from.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(from)
	if letter.has("photo_seed"):
		header.add_child(_snapshot(int(letter["photo_seed"]), int(letter.get("photo_age", 40))))
	column.add_child(header)
	for paragraph: String in letter.get("paragraphs", []):
		column.add_child(UiTheme.para(paragraph, 800, UiTheme.SIZE_BODY, Palette.INK_BLUE))
	return page


## A small print with a white border, turned a little and paper-clipped over
## the top edge of the letter. Containers reset rotation, so it sits in a
## plain holder that reserves its room in the header row.
func _snapshot(seed_value: int, age: int) -> Control:
	var photo := NewsPhoto.halftone(seed_value, age, SNAPSHOT_BLOCK)
	snapshots.append(photo)
	var print_frame := NewsPhoto.in_frame(photo, Palette.PAPER, Palette.PAPER_SHADE, 1, 8)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := PortraitView.GRID_W * SNAPSHOT_BLOCK + 18.0
	var h := PortraitView.GRID_H * SNAPSHOT_BLOCK + 18.0
	holder.custom_minimum_size = Vector2(w + 16, h - 56)
	print_frame.position = Vector2(8, -64)
	print_frame.pivot_offset = Vector2(w, h) / 2.0
	print_frame.rotation_degrees = 4.0
	holder.add_child(print_frame)
	var clip := PaperClip.new()
	clip.position = Vector2(w / 2.0, -76)
	clip.rotation_degrees = 4.0
	holder.add_child(clip)
	return holder


## A bent-wire paper clip, drawn in two tones of metal.
class PaperClip extends Control:
	const WIRE := Palette.TEXT_DIM
	const SHADOW := Palette.INK_FADED
	const PATH: Array[Vector2] = [
		Vector2(2, 40), Vector2(2, 6), Vector2(5, 2), Vector2(11, 2), Vector2(14, 6), Vector2(14, 34),
		Vector2(12, 38), Vector2(8, 38), Vector2(6, 34), Vector2(6, 10), Vector2(8, 8), Vector2(10, 10), Vector2(10, 30),
	]

	func _init() -> void:
		custom_minimum_size = Vector2(16, 42)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var points := PackedVector2Array(PATH)
		draw_polyline(points, SHADOW, 3.0)
		draw_polyline(points, WIRE, 1.5)
