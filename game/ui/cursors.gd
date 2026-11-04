class_name Cursors
## Pixel-art mouse cursors in ink and paper, built pixel by pixel at startup:
## an arrow, a pointing finger for buttons, an open hand over papers, a closed
## hand while dragging, and a magnifier over inspect-mode targets. Each is drawn
## on a 16x16 grid and doubled to 32x32, so it matches the game's chunky pixels.

const SIZE := 32
const SHAPES: Array[int] = [
	Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_MOVE,
	Input.CURSOR_DRAG, Input.CURSOR_CROSS,
]
## X ink outline, o paper, s paper in shadow, . clear.
const ART := {
	Input.CURSOR_ARROW: [
		"X...............",
		"XX..............",
		"XoX.............",
		"XooX............",
		"XoooX...........",
		"XooooX..........",
		"XoooooX.........",
		"XooooooX........",
		"XoooooooX.......",
		"XooooXXXXX......",
		"XooXooX.........",
		"XoX.XooX........",
		"XX..XooX........",
		"X....XooX.......",
		".....XooX.......",
		"......XX........",
	],
	Input.CURSOR_POINTING_HAND: [
		".....XX.........",
		"....XooX........",
		"....XooX........",
		"....XooX........",
		"....XooXXX......",
		"....XooXooXXX...",
		"....XooXooXooX..",
		".XX.XooXooXooX..",
		"XooXXoosoosooX..",
		"XoooXoooooooooX.",
		".XoooooooooooX..",
		"..XooooooooooX..",
		"..XoooooooooX...",
		"...XooooooooX...",
		"....XoooooooX...",
		"....XXXXXXXXX...",
	],
	Input.CURSOR_MOVE: [
		"......XX........",
		"..XX.XooX.XX....",
		".XooXXooXXooX...",
		".XooXXooXXooX...",
		".XooXXooXXooXXX.",
		".XooXXooXXooXooX",
		".XooXXooXXooXooX",
		".XoooooooooosooX",
		"XXoooooooooooooX",
		"XooXooooooooooX.",
		"XoooXoooooooooX.",
		".XoooooooooooX..",
		"..XooooooooooX..",
		"...XooooooooX...",
		"....XooooooX....",
		"....XXXXXXXX....",
	],
	Input.CURSOR_DRAG: [
		"................",
		"................",
		"................",
		"....XX.XX.XX....",
		"...XooXooXooXX..",
		"..XXsoXsoXsoXoX.",
		".XooooooooooXoX.",
		".XooooooooooosoX",
		"XXoooooooooooooX",
		"XooXooooooooooX.",
		"XoooXoooooooooX.",
		".XoooooooooooX..",
		"..XooooooooooX..",
		"...XooooooooX...",
		"....XooooooX....",
		"....XXXXXXXX....",
	],
	Input.CURSOR_CROSS: [
		"...XXXXXX.......",
		"..XooooooX......",
		".XoXXXXXXoX.....",
		"XoX......XoX....",
		"XoX......XoX....",
		"XoX......XoX....",
		"XoX......XoX....",
		"XoX......XoX....",
		"XoX......XoX....",
		".XoXXXXXXoX.....",
		"..XooooooXoX....",
		"...XXXXXXXooX...",
		"..........XooX..",
		"...........XooX.",
		"............XooX",
		".............XX.",
	],
}
## Where each cursor clicks, in 32 px image space.
const HOTSPOTS := {
	Input.CURSOR_ARROW: Vector2(1, 1),
	Input.CURSOR_POINTING_HAND: Vector2(11, 1),
	Input.CURSOR_MOVE: Vector2(15, 17),
	Input.CURSOR_DRAG: Vector2(15, 19),
	Input.CURSOR_CROSS: Vector2(11, 11),
}


## The 32x32 image for an Input.CURSOR_* shape, or null for one not drawn here.
static func build(shape: int) -> Image:
	if not ART.has(shape):
		return null
	var rows: Array = ART[shape]
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := _color(row[x])
			if c.a > 0.0:
				img.fill_rect(Rect2i(x * 2, y * 2, 2, 2), c)
	return img


static func hotspot(shape: int) -> Vector2:
	return HOTSPOTS.get(shape, Vector2.ZERO)


## Installs every cursor. Settings calls this at startup (never headless).
static func install() -> void:
	for shape in SHAPES:
		Input.set_custom_mouse_cursor(build(shape), shape as Input.CursorShape, hotspot(shape))


static func _color(ch: String) -> Color:
	match ch:
		"X":
			return Palette.INK
		"o":
			return Palette.PAPER
		"s":
			return Palette.PAPER_SHADE
	return Color(0, 0, 0, 0)
