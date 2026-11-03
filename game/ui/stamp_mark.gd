class_name StampMark
extends Control
## An inked rubber-stamp impression: APPROVED or DENIED, with a reason code.

var word: String = ""
var code: String = ""
var ink: Color = Palette.RED


static func create(approved: bool, reason_code: String) -> StampMark:
	var s := StampMark.new()
	s.word = "APPROVED" if approved else "DENIED"
	s.code = reason_code
	s.ink = Palette.GREEN if approved else Palette.RED
	s.size = Vector2(300, 112 if reason_code != "" else 88)
	s.pivot_offset = s.size / 2.0
	s.custom_minimum_size = s.size
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _draw() -> void:
	var color := Color(ink, 0.85)
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, color, false, 6.0)
	draw_rect(r.grow(-10), color, false, 2.0)
	var font := UiTheme.font()
	var word_size := UiTheme.SIZE_BIG
	var word_width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, word_size).x
	draw_string(font, Vector2((size.x - word_width) / 2.0, 60), word, HORIZONTAL_ALIGNMENT_LEFT, -1, word_size, color)
	if code != "":
		var code_width := font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
		draw_string(font, Vector2((size.x - code_width) / 2.0, 90), code, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, color)
