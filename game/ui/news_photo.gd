class_name NewsPhoto
extends PortraitView
## A face as the paper prints it: the portrait's own block grid drawn small (2 px
## blocks for 80x96, 3 px for 120x144) in four newsprint tones, with a checker
## dither between neighboring tones. The wall and the figure's shadow on it drop
## out to bare paper, whether or not PortraitView draws a wall.
##
## Tones are set the way a photo desk sets levels, anchored on the face: the skin
## prints in the middle of the range (a darker skin a little darker), the face's
## own shading just below it, and anything clearly darker than the skin (brows,
## lids, the mouth, the eyes, hair) at least a full tone below. Each stretch is
## normalized to this portrait's own darkest and lightest colors, so dark skin
## keeps its features and light skin never prints as blank paper.
##
## A family photo, not the face at the counter: healthy and smiling unless told
## otherwise. Static: the portrait is printed once per change and never blinks.

## Newsprint tones, darkest first. The last one is the paper itself.
const PRINT_TONES: Array[Color] = [Palette.INK, Palette.INK_FADED, Palette.PAPER_SHADE, Palette.NEWSPRINT]
const PRINT_PAPER_TONE := 3
## A 2x2 ordered dither: at half way between two tones it is a checkerboard.
const PRINT_DITHER: Array[float] = [0.125, 0.625, 0.875, 0.375]
## Where the skin prints, on the 0 (ink) to 3 (paper) scale: the darkest skin
## tone here, the lightest there, the rest in between by luminance. The dither
## only prints quarter steps; this range puts each of the six skin tones on a
## step of its own (1.0, 1.25 ... 2.25), so no two of them print alike.
const PRINT_SKIN_DARK := 1.0
const PRINT_SKIN_LIGHT := 2.25
## A color at least this much darker than the skin (by luminance) is a feature
## and prints a full tone below the skin. Up to this much darker is the face's
## own shading, which stays within PRINT_SHADING_DROP of it.
const PRINT_FEATURE_KNEE := 0.2
const PRINT_SHADING_DROP := 0.45
## A dark suit for a headshot (the tie is drawn darker still).
const PRINT_SUIT := Palette.INK_BLUE
## How close a color must be to a darkened wall to count as one.
const PRINT_WALL_MATCH := 0.012
## Never larger than the counter view's own 8 px blocks.
const PRINT_MAX_BLOCK := 8

var _np_block: int = 2
## The portrait as PortraitView painted it, one composited color per grid cell...
var _np_cells := PackedColorArray()
## ...whether the figure (not the wall) covers each cell...
var _np_figure := PackedByteArray()
## ...and the newsprint tone each cell prints in.
var _np_tones := PackedByteArray()
var _np_recording := false
var _np_dirty := true
var _np_texture: ImageTexture


func _init(block_size: int = 2) -> void:
	super()
	_np_block = clampi(block_size, 1, PRINT_MAX_BLOCK)
	custom_minimum_size = Vector2(GRID_W * _np_block, GRID_H * _np_block)
	size = custom_minimum_size


## PortraitView's constructor sizes the control for 8 px blocks, and out of the
## tree a Control keeps clamping to that stale minimum. In the tree the minimum
## is current, so the print takes its own size there.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		update_minimum_size()
		size = custom_minimum_size


## `photo` in a frame: `border` px of `edge` around `pad` px of `matte`.
static func in_frame(photo: NewsPhoto, matte: Color, edge: Color, border: int, pad: int) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.flat_box(matte, edge, border, border + pad, border + pad))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_child(photo)
	return frame


## A printed photo of the face `seed_value` gives at `age`.
static func halftone(seed_value: int, age: int, block_size: int = 2, sick: bool = false) -> NewsPhoto:
	var photo := NewsPhoto.new(block_size)
	photo.show_patient(seed_value, age, sick)
	return photo


## The face, smiling for the camera. A sick face (a hospital gown) keeps a
## straight one.
func show_patient(seed_value: int, age: int, sick: bool) -> void:
	super.show_patient(seed_value, age, sick)
	_mood = Mood.NEUTRAL if sick else Mood.RELIEVED
	_np_reprint()


func set_expression(e: Mood) -> void:
	super.set_expression(e)
	_np_reprint()


func clear() -> void:
	super.clear()
	_np_reprint()


## A dark suit and tie, for a headshot. Call after show_patient().
func dress_suit() -> void:
	_cloth = PRINT_SUIT
	_neckline = Neckline.TIE
	_np_reprint()


## The tones the figure printed in (the bare paper around it not counted).
## Empty until the photo has been drawn once.
func tones_used() -> Array[Color]:
	var used: Array[Color] = []
	for i in _np_tones.size():
		if _np_figure[i] == 0:
			continue
		var tone := PRINT_TONES[_np_tones[i]]
		if not used.has(tone):
			used.append(tone)
	return used


func _np_reprint() -> void:
	_np_dirty = true
	queue_redraw()


func _draw() -> void:
	if _np_dirty:
		_np_print()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _np_texture != null:
		draw_texture(_np_texture, Vector2.ZERO)


## Lets PortraitView paint into the cell grid (through _b), then maps the cells
## to tones and bakes them into a texture. Runs inside _draw, where PortraitView
## expects to be.
func _np_print() -> void:
	_np_dirty = false
	var n := GRID_W * GRID_H
	_np_cells.resize(n)
	_np_cells.fill(Color(0, 0, 0, 0))
	_np_figure.resize(n)
	_np_figure.fill(0)
	_np_recording = true
	super._draw()
	_np_recording = false
	_np_map_tones()
	_np_texture = _np_bake() if _np_figure.has(1) else null


## Every PortraitView block lands here. While printing, it records the color in
## the cells it covers instead of drawing.
func _b(x: int, y: int, w: int, h: int, c: Color) -> void:
	if not _np_recording:
		return
	var r := Rect2i(x, y, maxi(w, 0), maxi(h, 0)).intersection(Rect2i(0, 0, GRID_W, GRID_H))
	if not r.has_area():
		return
	var backdrop := _np_is_wall(c)
	for yy in range(r.position.y, r.end.y):
		for xx in range(r.position.x, r.end.x):
			var i := yy * GRID_W + xx
			if backdrop:
				_np_figure[i] = 0
			elif c.a >= 0.999:
				_np_cells[i] = c
				_np_figure[i] = 1
			elif _np_figure[i] == 1:
				# Glasses, stubble and tears tint the face beneath them. A
				# translucent shadow on bare paper stays bare paper.
				_np_cells[i] = _np_cells[i].blend(c)


## The wall, its stripes and the figure's shadow on it are all the wall colors
## darkened by some amount.
func _np_is_wall(c: Color) -> bool:
	if c.a < 0.999:
		return false
	for wall: Color in [Palette.WALL, Palette.WALL_LIGHT]:
		var k := c.r / wall.r
		if k > 0.3 and k <= 1.0 + PRINT_WALL_MATCH and absf(c.g - wall.g * k) < PRINT_WALL_MATCH and absf(c.b - wall.b * k) < PRINT_WALL_MATCH:
			return true
	return false


func _np_map_tones() -> void:
	var n := _np_cells.size()
	var lum := PackedFloat32Array()
	lum.resize(n)
	var lo := INF
	var hi := -INF
	for i in n:
		if _np_figure[i] == 0:
			continue
		lum[i] = _np_cells[i].get_luminance()
		lo = minf(lo, lum[i])
		hi = maxf(hi, lum[i])
	var skin := _skin.get_luminance()
	var skin_level := print_skin_level(skin)
	var top := PRINT_TONES.size() - 1
	_np_tones.resize(n)
	for i in n:
		if _np_figure[i] == 0:
			_np_tones[i] = PRINT_PAPER_TONE
			continue
		var v := print_level(lum[i], lo, hi, skin, skin_level)
		var base := mini(floori(v), top - 1)
		var threshold := PRINT_DITHER[(i / GRID_W) % 2 * 2 + (i % GRID_W) % 2]
		_np_tones[i] = base + int(v - base > threshold)


## Where a skin of luminance `skin` prints, from PRINT_SKIN_DARK for the darkest
## skin tone in the palette to PRINT_SKIN_LIGHT for the lightest.
static func print_skin_level(skin: float) -> float:
	var darkest := INF
	var lightest := -INF
	for tone: Color in Palette.SKIN_TONES:
		darkest = minf(darkest, tone.get_luminance())
		lightest = maxf(lightest, tone.get_luminance())
	var t := clampf((skin - darkest) / maxf(lightest - darkest, 0.001), 0.0, 1.0)
	return lerpf(PRINT_SKIN_DARK, PRINT_SKIN_LIGHT, t)


## Where a cell of luminance `l` prints, from 0 (ink) to 3 (paper), in a
## portrait whose cells run from `lo` to `hi` and whose skin (luminance `skin`)
## prints at `skin_level`. Lighter than the skin climbs to paper; the face's
## shading sits just below the skin; features run from ink up to a full tone
## below the skin.
static func print_level(l: float, lo: float, hi: float, skin: float, skin_level: float) -> float:
	if l >= skin:
		return lerpf(skin_level, 3.0, clampf((l - skin) / maxf(hi - skin, 0.001), 0.0, 1.0))
	var knee := skin * (1.0 - PRINT_FEATURE_KNEE)
	if l >= knee:
		return skin_level - PRINT_SHADING_DROP * (skin - l) / maxf(skin - knee, 0.001)
	return maxf(skin_level - 1.0, 0.0) * clampf((l - lo) / maxf(knee - lo, 0.001), 0.0, 1.0)


func _np_bake() -> ImageTexture:
	var b := _np_block
	var image := Image.create(GRID_W * b, GRID_H * b, false, Image.FORMAT_RGBA8)
	for i in _np_tones.size():
		image.fill_rect(Rect2i((i % GRID_W) * b, (i / GRID_W) * b, b, b), PRINT_TONES[_np_tones[i]])
	return ImageTexture.create_from_image(image)
