class_name UiTheme
## Builds the shared Theme (set once on Main) and small widget helpers.
## MatchupPro renders crisp at multiples of 8 px, so only those sizes are used.

const FONT_PATH := "res://assets/fonts/MatchupPro.ttf"
const SIZE_SMALL := 16
const SIZE_BODY := 24
const SIZE_TITLE := 32
const SIZE_BIG := 48
const SIZE_HUGE := 96

static var _font: FontFile
static var _theme: Theme


## The pixel font, with gray antialiasing (also set in its .import). The
## 1920x1080 canvas is drawn scaled to fit the window (0.833 in the default
## 1600x900 one), and unsmoothed pixel glyphs at fractional scales clump into
## blobs. See fit_font_to_scale() for the whole-number case.
static func font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH)
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font


## Smooths the font only where it helps. At a whole-number scale (a 1920x1080 or
## 3840x2160 window) the glyphs land on whole pixels and plain rendering is
## sharpest: antialiasing there would only grey the half-pixel edges of 24 px
## text. At any other scale the font keeps its gray antialiasing.
static func fit_font_to_scale(scale: float) -> void:
	var whole := scale >= 1.0 and is_equal_approx(scale, roundf(scale))
	var mode := TextServer.FONT_ANTIALIASING_NONE if whole else TextServer.FONT_ANTIALIASING_GRAY
	if font().antialiasing != mode:
		font().antialiasing = mode


## fit_font_to_scale() for the scale `window` draws the canvas at.
static func fit_font_to_window(window: Window) -> void:
	fit_font_to_scale(window.get_final_transform().get_scale().x)


static func build() -> Theme:
	if _theme != null:
		return _theme
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		fit_font_to_window(tree.root)
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = SIZE_BODY

	t.set_color("font_color", "Label", Palette.TEXT_LIGHT)

	t.set_stylebox("normal", "Button", flat_box(Palette.WALL_LIGHT, Palette.INK, 2, 16, 8))
	t.set_stylebox("hover", "Button", flat_box(Palette.WALL_LIGHT.lightened(0.12), Palette.INK, 2, 16, 8))
	t.set_stylebox("pressed", "Button", flat_box(Palette.WALL.darkened(0.2), Palette.INK, 2, 16, 8))
	t.set_stylebox("disabled", "Button", flat_box(Palette.WALL.darkened(0.1), Palette.WALL, 2, 16, 8))
	var focus := flat_box(Color(0, 0, 0, 0), Palette.AMBER, 2, 16, 8)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Palette.TEXT_LIGHT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Palette.TEXT_LIGHT)
	t.set_color("font_focus_color", "Button", Palette.TEXT_LIGHT)
	t.set_color("font_disabled_color", "Button", Palette.TEXT_DIM.darkened(0.3))

	t.set_stylebox("normal", "LineEdit", flat_box(Palette.PAPER_ALT, Palette.INK, 2, 12, 8))
	t.set_stylebox("focus", "LineEdit", flat_box(Palette.PAPER_ALT, Palette.INK_BLUE, 2, 12, 8))
	t.set_color("font_color", "LineEdit", Palette.INK_BLUE)
	t.set_color("caret_color", "LineEdit", Palette.INK_BLUE)
	t.set_color("selection_color", "LineEdit", Color(Palette.AMBER, 0.4))
	t.set_color("font_placeholder_color", "LineEdit", Palette.INK_FADED)

	t.set_stylebox("panel", "PanelContainer", paper_box())
	t.set_stylebox("panel", "TooltipPanel", flat_box(Palette.PAPER, Palette.INK, 2, 8, 4))
	t.set_color("font_color", "TooltipLabel", Palette.INK)

	var grabber := flat_box(Palette.PAPER_SHADE, Palette.PAPER_SHADE, 0, 0, 0)
	t.set_stylebox("scroll", "VScrollBar", flat_box(Color(0, 0, 0, 0.1), Color(0, 0, 0, 0), 0, 4, 0))
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	_theme = t
	return t


static func flat_box(bg: Color, border: Color, border_width: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


## A sheet of paper with a hard drop shadow.
static func paper_box(color: Color = Palette.PAPER, border: Color = Palette.PAPER_SHADE, pad: int = 18) -> StyleBoxFlat:
	var box := flat_box(color, border, 2, pad, pad)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 1
	box.shadow_offset = Vector2(6, 6)
	return box


static func label(text: String, size: int = SIZE_BODY, color: Color = Palette.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A label that wraps at `width` pixels.
static func para(text: String, width: float, size: int = SIZE_BODY, color: Color = Palette.INK) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func button(text: String, size: int = SIZE_BODY, min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(min_width, 0)
	b.focus_mode = Control.FOCUS_ALL
	return b


## A filled rectangle that ignores the mouse.
static func rect(color: Color, size: Vector2 = Vector2.ZERO) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## "$1,234" / "-$56".
static func money(amount: int) -> String:
	return Fmt.money(amount)


## "+$15" / "-$6" for deltas.
static func signed_money(amount: int) -> String:
	return Fmt.signed_money(amount)


static func margin(child: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(child)
	return m
