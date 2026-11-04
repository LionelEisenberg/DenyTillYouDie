class_name PortraitView
extends Control
## The view through the booth window: a patient drawn from chunky blocks on a 40x48 grid.
## Faces are deterministic per seed; age and sickness change the look, and set_expression()
## changes only the brows, eyes and mouth. (The enum is Mood because Godot already has a
## native class called Expression.)
##
## The defaults draw an 8 px portrait in front of its own wall, holding still. The desk
## uses 10 px blocks, no wall (it draws a waiting room behind), idle motion (blinks,
## glances, sweat), a parent beside a child, and walks the figure with fig_offset.

## The figure appeared, changed, moved or left (see coverage()).
signal figure_changed

enum Mood { NEUTRAL, WORRIED, RELIEVED, DEVASTATED, ANGRY }
enum Hair { BALD, BUZZ, SHORT, PARTED, LONG, BOB, BUN, CURLY, RECEDING }
enum Beard { NONE, STUBBLE, MUSTACHE, GOATEE, FULL }
enum Neckline { CREW, VEE, COLLAR, TIE, TURTLE }

const BLOCK := 8
const GRID_W := 40
const GRID_H := 48
const CX := 20 ## Axis of symmetry: the line between columns 19 and 20.
## Head shapes (oval, square, round, long, tapered): crown share, jaw start, chin width ratio...
const HEAD_CURVES: Array[Vector3] = [
	Vector3(0.34, 0.58, 0.50), Vector3(0.24, 0.74, 0.74), Vector3(0.42, 0.52, 0.58),
	Vector3(0.30, 0.64, 0.52), Vector3(0.30, 0.46, 0.36),
]
## ...and adult half-width and height adjustments, in blocks.
const HEAD_SIZES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, -1), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(0, 0),
]
## Brow block offsets per Mood, from the inner block outwards.
const BROWS: Array = [[0, 0, 0, 0], [-1, -1, 0, 0], [0, -1, -1, 0], [-1, -1, 0, 1], [1, 1, 0, 0]]
const EYE_COLORS: Array[Color] = [Color("2a231f"), Color("3e2f23"), Color("45525b"), Color("4b5341")]
const SCLERA := Color("c2bba8")
const SHIRT := Color("c3bead")
const FRAME := Color("3d342b")
const METAL := Color("8d887c")
const BRUISE := Color("4a3a4a")
const TEAR := Color(0.72, 0.84, 0.9, 0.85)
const SWEAT := Color(0.84, 0.9, 0.9, 0.9)
const LENS := Color(0.86, 0.93, 0.95, 0.16)
const NO_EDGE := Color(0, 0, 0, 0)
## The figure's shadow when there's no wall of its own to darken.
const SOFT_SHADOW := Color(0, 0, 0, 0.22)
const BLINK_TIME := 0.12
const GLANCE_TIME := 0.7
## The first grid column of a child's parent's coat, at the window's right edge.
const PARENT_EDGE := GRID_W - 3

## Pixels per grid block. Setting it resizes the portrait.
var block: int = BLOCK:
	set(value):
		block = maxi(1, value)
		custom_minimum_size = Vector2(GRID_W * block, GRID_H * block)
		size = custom_minimum_size
		queue_redraw()
## Paint the booth wall behind the figure. Without it the figure casts a soft,
## translucent shadow on whatever is drawn behind the portrait.
var draw_wall: bool = true:
	set(value):
		draw_wall = value
		queue_redraw()
## Where the figure stands, in blocks. Only the figure moves (never the wall), so a
## patient walking in or out steps along the pixel grid and is cropped at the edge.
var fig_offset := Vector2i.ZERO:
	set(value):
		if value == fig_offset:
			return
		fig_offset = value
		queue_redraw()
		figure_changed.emit()
## Blinks, glances toward the desk and, on sick patients, a bead of sweat that slides.
## Off by default, so photos and badges hold still.
var idle_motion: bool = false:
	set(value):
		idle_motion = value
		_arm_idle()
## A child's parent standing beside them: a sleeve and a hand on the shoulder at the
## right edge, head out of frame.
var with_parent: bool = false:
	set(value):
		if value == with_parent:
			return
		with_parent = value
		queue_redraw()
		figure_changed.emit()

var _shown := false
var _mood: Mood = Mood.NEUTRAL
var _age := 30
var _sick := false
# Traits rolled from the seed.
var _skin := Color.WHITE
var _hair_col := Color.BLACK
var _brow_col := Color.BLACK
var _hair: Hair = Hair.SHORT
var _shape := 0
var _eye_col := Color.BLACK
var _eye_style := 0 ## 0 whites showing, 1 narrow, 2 hooded.
var _eye_gap := 2
var _brow_thick := false
var _nose := 0
var _mouth := 2 ## Mouth half-width.
var _full_lips := false
var _glasses := false
var _beard: Beard = Beard.NONE
var _cloth := Color.GRAY
var _neckline: Neckline = Neckline.CREW
var _parent_skin := Color.WHITE
var _parent_cloth := Color.GRAY
# Layout in grid rows and columns, set by _layout().
var _top := 9 ## First head row.
var _hh := 22 ## Head height.
var _hw := 8 ## Head half-width.
var _ey := 19 ## Eye row.
var _nb := 23 ## Nose base row.
var _my := 25 ## Mouth row.
var _chin := 31 ## First row below the head.
var _nw := 4 ## Neck half-width.
var _sh := 34 ## Shoulder top row.
var _sw := 16 ## Shoulder half-width.
var _rows := PackedInt32Array() ## Head half-width per head row.
# Idle motion, driven by timers seeded from the face.
var _blinking := false
var _glance := 0 ## Blocks the pupils sit toward the desk (screen right).
var _sweat_drop := 0 ## Blocks the temple bead has slid down.
var _idle_rng := RandomNumberGenerator.new()
var _blink_timer: Timer
var _glance_timer: Timer
## What _b() shifts by: fig_offset while the figure is drawn, zero for the wall.
var _off := Vector2i.ZERO


func _init() -> void:
	custom_minimum_size = Vector2(GRID_W * BLOCK, GRID_H * BLOCK)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A new face with a NEUTRAL expression. Same seed, age and sickness give the same face.
func show_patient(seed_value: int, age: int, sick: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Every roll happens in a fixed order, so age and sickness never reshuffle a face.
	var skin_i := rng.randi_range(0, Palette.SKIN_TONES.size() - 1)
	var hair_i := rng.randi_range(0, Palette.HAIR_COLORS.size() - 1)
	_hair = rng.randi_range(Hair.BALD, Hair.CURLY) as Hair
	_shape = rng.randi_range(0, HEAD_CURVES.size() - 1)
	_eye_col = EYE_COLORS[rng.randi_range(0, EYE_COLORS.size() - 1)]
	_eye_style = rng.randi_range(0, 2)
	_eye_gap = rng.randi_range(1, 2)
	_brow_thick = rng.randf() < 0.35
	_nose = rng.randi_range(0, 3)
	_mouth = 3 if rng.randf() < 0.25 else 2
	_full_lips = rng.randf() < 0.4
	_glasses = rng.randf() < 0.2
	var has_beard := rng.randf() < 0.25
	var beard := rng.randi_range(Beard.STUBBLE, Beard.FULL) as Beard
	_cloth = Palette.CLOTHES[rng.randi_range(0, Palette.CLOTHES.size() - 1)]
	_neckline = rng.randi_range(Neckline.CREW, Neckline.TURTLE) as Neckline
	var gray_roll := rng.randf()
	var bald_roll := rng.randf()
	# Rolled after everything above, so adding it reshuffled no existing face.
	var parent_cloth_i := rng.randi_range(0, Palette.CLOTHES.size() - 1)
	_age = clampi(age, 1, 99)
	_sick = sick
	_skin = Palette.SKIN_TONES[skin_i]
	_parent_skin = _skin
	_parent_cloth = Palette.CLOTHES[parent_cloth_i]
	if _parent_cloth == _cloth: # Never the child's own sweater.
		_parent_cloth = Palette.CLOTHES[(parent_cloth_i + 3) % Palette.CLOTHES.size()]
	if sick: # Sallow, greenish and washed out.
		_skin = _skin.lerp(Color.from_hsv(0.25, 0.2, minf(_skin.v * 0.85 + 0.14, 0.82)), 0.65)
	_hair_col = Palette.HAIR_COLORS[hair_i % 3 if skin_i >= 3 else hair_i]
	# Age cues: children get small plain features; hair grays and thins with age.
	if _age < 12:
		_nose = 0
		_brow_thick = false
		_eye_style = 0
	if _hair == Hair.BALD and _age < 40 and (_age < 16 or bald_roll > 0.3):
		_hair = Hair.SHORT if _age < 16 else Hair.BUZZ
	elif _hair == Hair.LONG and _age >= 60:
		_hair = Hair.BUN
	elif _age >= 60 and bald_roll < 0.2:
		_hair = Hair.BALD
	elif _age >= 45 and bald_roll < 0.4 and _hair in [Hair.SHORT, Hair.PARTED, Hair.BUZZ]:
		_hair = Hair.RECEDING
	if _age >= 75:
		_hair_col = Palette.HAIR_WHITE
	elif _age >= 55 and gray_roll < 0.75:
		_hair_col = Palette.HAIR_GRAY
	elif _age >= 40 and gray_roll < 0.4:
		_hair_col = _hair_col.lerp(Palette.HAIR_GRAY, 0.4)
	_brow_col = _hair_col.darkened(0.3 if _age >= 55 else 0.15)
	_beard = beard if has_beard and _age >= 18 and _hair not in [Hair.BUN, Hair.BOB] else Beard.NONE
	_mood = Mood.NEUTRAL
	_shown = true
	_idle_rng.seed = hash([seed_value, "idle"])
	_layout()
	_arm_idle()
	queue_redraw()
	figure_changed.emit()


## Same face, new expression.
func set_expression(e: Mood) -> void:
	_mood = e
	queue_redraw()


## Empty booth: only the wall is drawn.
func clear() -> void:
	var was_shown := _shown
	_shown = false
	_arm_idle()
	queue_redraw()
	if was_shown:
		figure_changed.emit()


## Whether a patient is at the window.
func is_shown() -> bool:
	return _shown


## The grid blocks the figure covers where it stands now, its outline and a
## parent's coat included: one byte per block, row by row (GRID_W x GRID_H), 1 where
## covered. All zero with nobody at the window. (The soft shadow doesn't count.)
func coverage() -> PackedByteArray:
	var cover := _mask()
	if not _shown:
		return cover
	var figure := _mask()
	for m in _figure_masks():
		for i in m.size():
			if m[i] != 0:
				figure[i] = 1
	var steps: Array[Vector2i] = [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for y in GRID_H:
		for x in GRID_W:
			if figure[y * GRID_W + x] == 0:
				continue
			for step in steps:
				_span(cover, y + step.y + fig_offset.y, x + step.x + fig_offset.x, x + step.x + fig_offset.x + 1)
	if with_parent and _age < 16:
		var strip := PARENT_EDGE + _parent_shift()
		for y in GRID_H:
			_span(cover, y, strip - 1, GRID_W)
	return cover


func _layout() -> void:
	var curve := HEAD_CURVES[_shape]
	var child := _age < 16 # A child at the counter: smaller and lower in the window.
	var t := clampf((_age - 3) / 12.0, 0.0, 1.0)
	_hw = roundi(lerpf(6.0, 7.0, t)) if child else 8 + HEAD_SIZES[_shape].x
	_hh = roundi(lerpf(16.0, 19.0, t)) if child else 22 + HEAD_SIZES[_shape].y
	_top = roundi(lerpf(21.0, 16.0, t)) if child else 9
	_ey = _top + roundi(_hh * (0.5 if child else 0.47))
	_nb = _ey + (3 if child else 4)
	_my = _nb + 2
	_chin = _top + _hh
	_nw = 3 if child or _hw < 8 else 4
	_sh = _chin + (2 if child else 3)
	_sw = roundi(lerpf(10.0, 13.0, t)) if child else 16
	_eye_gap = 1 if _age < 10 else _eye_gap
	var crown := curve.x
	var jaw := curve.y
	_rows.resize(_hh)
	for r in _hh:
		var v := (r + 0.5) / _hh
		var w := float(_hw)
		if v < crown: # A round crown...
			w *= sqrt(1.0 - pow(1.0 - v / crown, 2.0))
		elif v > jaw: # ...and a jaw tapering to the chin.
			w = lerpf(w, w * curve.z, pow((v - jaw) / (1.0 - jaw), 1.6))
		_rows[r] = maxi(2, roundi(w))


func _draw() -> void:
	_off = Vector2i.ZERO
	if draw_wall:
		_b(0, 0, GRID_W, GRID_H, Palette.WALL)
		_b(0, 5, GRID_W, 9, Palette.WALL_LIGHT)
		_b(0, 14, GRID_W, 1, Palette.WALL.darkened(0.12))
	if not _shown:
		return
	_off = fig_offset
	var masks := _figure_masks()
	var back := masks[0]
	var body := masks[1]
	var head := masks[2]
	var cap := masks[3]
	# One shadow for the whole figure, so a translucent one never doubles up.
	var shadow := _mask()
	for m in masks:
		for i in m.size():
			if m[i] != 0:
				shadow[i] = 1
	_runs(shadow, Palette.WALL.darkened(0.2) if draw_wall else SOFT_SHADOW, Vector2i(2, 1))
	_paint(back, _hair_col, _hair_col.darkened(0.55))
	_draw_body(body)
	if with_parent and _age < 16:
		_draw_parent_arm()
	_draw_head(head)
	_draw_eyes()
	_draw_brows()
	_draw_nose()
	_draw_wrinkles()
	_draw_beard()
	_draw_mouth()
	if _sick: # Beads of sweat on the brow, temple and cheek; the temple bead slips now and then.
		var beads: Array[Vector2i] = [Vector2i(3, _ey - 5), Vector2i(2 - _hw, _ey - 2 + _sweat_drop), Vector2i(_hw - 3, _my - 3)]
		for p in beads:
			_b(CX + p.x, p.y, 1, 1, Color.WHITE.lerp(SWEAT, 0.5))
			_b(CX + p.x, p.y + 1, 1, 2, SWEAT.darkened(0.15))
	_draw_hair(cap)
	_off = Vector2i.ZERO


## The figure's shapes at rest: hair behind the head, body, head, and hair over it.
func _figure_masks() -> Array[PackedByteArray]:
	var head := _sym_mask(_top, _chin, func(y: int) -> int: return _rows[y - _top] + int(y >= _ey - 1 and y < _nb))
	var body := _sym_mask(_sh, GRID_H, func(y: int) -> int: return _sw - maxi(0, 6 - 2 * (y - _sh)))
	var back := _back_hair_mask()
	var cap := _cap_mask()
	if _hair == Hair.CURLY:
		_scallop(back)
		_scallop(cap)
	return [back, body, head, cap]


## Hair hanging behind the head.
func _back_hair_mask() -> PackedByteArray:
	var w := _hw + 2
	match _hair:
		Hair.LONG:
			return _sym_mask(_top + 5, _sh + 2, func(y: int) -> int: return w - int(y < _ey) + int(y >= _chin))
		Hair.BOB:
			return _sym_mask(_top + 5, _chin, func(y: int) -> int: return w - int(y == _chin - 1))
		Hair.CURLY:
			return _sym_mask(_top - 1, _chin - 2, func(y: int) -> int: return w + 1 - maxi(0, _top + 1 - y))
		Hair.BUN:
			return _sym_mask(_top - 4, _top, func(y: int) -> int: return 3 - int(y == _top - 4))
	return _mask()


## Hair over the scalp, built column by column from the crown down to each hairline.
func _cap_mask() -> PackedByteArray:
	var m := _mask()
	if _hair == Hair.BALD: # Past 40, a fringe survives above the ears.
		var fringe_end := _ey - 1 if _age >= 40 else _ey - 4
		for y in range(_ey - 4, fringe_end):
			_span(m, y, CX - _hw - 1, CX - _hw + 1)
			_span(m, y, CX + _hw - 1, CX + _hw + 1)
		return m
	var vol := 2 if _hair == Hair.CURLY else (0 if _hair in [Hair.BUZZ, Hair.BUN] else 1)
	for k in _hw + vol:
		var r := 0
		while r < _hh - 1 and _rows[r] + vol <= k:
			r += 1
		for dx: int in [k, -k - 1]:
			for y in range(_top + r - vol, _hairline(dx, k)):
				_span(m, y, CX + dx, CX + dx + 1)
	return m


## The row where the hair in column CX + dx stops; k is the column's distance from the axis.
func _hairline(dx: int, k: int) -> int:
	var a := float(k) / _hw
	var side := k >= _hw - 1
	match _hair:
		Hair.LONG:
			return _sh + 4 if side else _top + 3 + roundi(3.0 * a * a)
		Hair.BOB:
			return _chin - 1 if side else _ey - 3
		Hair.CURLY:
			return _ey if side else _top + 4 + k % 2
		Hair.BUZZ, Hair.BUN:
			return _ey - 1 if side else _top + 3 + roundi(2.0 * a)
		Hair.RECEDING:
			return _ey - 2 if side else _top + (3 if k < 2 else (1 if k < 5 else 4))
	var sweep := 2 if _hair == Hair.PARTED and dx < 0 and k < 5 else 0
	return _ey - 2 if side else _top + 4 + roundi(2.0 * a * a) + sweep


func _draw_body(body: PackedByteArray) -> void:
	var cloth := Palette.GOWN if _sick else _cloth
	var dark := cloth.darkened(0.18)
	_paint(body, cloth, cloth.darkened(0.55))
	_b(CX + _sw - 3, _sh + 3, 3, GRID_H, dark) # Right side in shadow.
	_bm(_sw - 5, _sh + 4, 1, GRID_H, dark) # Where the arms meet the chest.
	var turtle := _neckline == Neckline.TURTLE and not _sick
	var neck := cloth if turtle else _skin.darkened(0.12)
	_paint(_sym_mask(_chin - 2, _sh + 1, func(_y: int) -> int: return _nw), neck, neck.darkened(0.5))
	_b(CX - _nw, _chin, 2 * _nw, 1, neck.darkened(0.2)) # Shadow under the chin.
	if _sick: # Hospital gown: a wide neckline, collarbones and a faded print.
		for i in 3:
			_b(CX - _nw - 3 + i, _sh + i, 2 * (_nw + 3 - i), 1, neck)
			_bm(_nw + 3 - i, _sh + i, 1, 1, dark.darkened(0.1))
		_b(CX - _nw, _sh + 3, 2 * _nw, 1, dark.darkened(0.1))
		_bm(1, _sh + 1, 3, 1, _skin.darkened(0.3))
		for y in range(_sh + 5, GRID_H, 3):
			for x in range(CX - _sw + 2 + (y - _sh) % 2 * 2, CX + _sw - 2, 4):
				_b(x, y, 1, 1, Palette.GOWN.darkened(0.12))
	elif _neckline == Neckline.CREW:
		_b(CX - _nw - 1, _sh, 2 * _nw + 2, 1, dark)
	elif turtle:
		for y in range(_chin + 1, _sh + 1, 2):
			_b(CX - _nw, y, 2 * _nw, 1, dark)
	else: # A V-neck, or an open collar over a shirt, maybe with a tie.
		var shirt := _neckline != Neckline.VEE
		for i in mini(5, _nw + 1):
			_b(CX - _nw + i, _sh + i, 2 * (_nw - i), 1, SHIRT if shirt else neck)
			_bm(_nw - i, _sh + i, 1, 1, dark)
		if shirt:
			_bm(_nw - 2, _sh - 1, 3, 1, SHIRT)
			_bm(_nw - 1, _sh, 2, 1, SHIRT.darkened(0.12))
		if _neckline == Neckline.TIE:
			_b(CX - 1, _sh, 2, 1, _cloth.darkened(0.45))
			_b(CX - 1, _sh + 1, 2, _nw, _cloth.darkened(0.3))


## The parent beside a child: a strip of coat at the window's right edge (their
## head is out of frame) and, once the child stands at the counter, a sleeve
## reaching down to a hand on the child's shoulder. The strip stays put while the
## child walks in, as if the parent had stepped up first, and leaves with them.
func _draw_parent_arm() -> void:
	var coat := _parent_cloth
	var edge := PARENT_EDGE
	if fig_offset.x == 0:
		# The forearm, two blocks thick, stepping down and in toward the shoulder.
		var arm := _mask()
		var hand_x := CX + _sw - 5
		var reach := maxi(1, edge - 1 - hand_x)
		for i in reach:
			var y := _sh - 2 - reach + i
			_span(arm, y, edge - 2 - i, mini(edge, edge + 1 - i))
			_span(arm, y + 1, edge - 2 - i, mini(edge, edge + 1 - i))
		_paint(arm, coat, coat.darkened(0.55))
		_b(hand_x + 1, _sh - 2, 3, 1, coat.darkened(0.3)) # Cuff.
		var hand := _mask()
		_span(hand, _sh - 1, hand_x - 1, hand_x + 3)
		_span(hand, _sh, hand_x - 2, hand_x + 3)
		_span(hand, _sh + 1, hand_x - 2, hand_x + 1)
		_paint(hand, _parent_skin, _parent_skin.darkened(0.55))
		_b(hand_x - 1, _sh + 1, 1, 1, _parent_skin.darkened(0.22)) # Between the fingers.
		_b(hand_x + 1, _sh, 1, 1, _parent_skin.darkened(0.14))
	var walking := _off
	_off = Vector2i(_parent_shift(), 0)
	var side := _mask()
	for y in GRID_H:
		_span(side, y, edge, GRID_W)
	_paint(side, coat, coat.darkened(0.55))
	_b(GRID_W - 1, 0, 1, GRID_H, coat.darkened(0.25)) # The coat turns away from the light.
	_b(edge, 0, 1, GRID_H, coat.darkened(0.12)) # Fold where the arm hangs.
	_off = walking


## How far the parent's coat strip has moved: not at all on the way in, block for
## block with the child on the way out.
func _parent_shift() -> int:
	return maxi(fig_offset.x, 0)


func _draw_head(head: PackedByteArray) -> void:
	var shade := _skin.darkened(0.12)
	_paint(head, _skin, _skin.darkened(0.55))
	for r in _hh: # Lit from the left.
		_b(CX + _rows[r] - 2, _top + r, 2, 1, shade)
	for y in range(_ey - 1, _nb): # Ears.
		_bm(_rows[y - _top], y, 1, 1, shade)
	_bm(_rows[_ey + 1 - _top], _ey + 1, 1, 1, _skin.darkened(0.3))
	_b(CX - _rows[_hh - 1] + 1, _chin - 1, 2 * _rows[_hh - 1] - 2, 1, shade)
	if _sick: # Hollow cheeks.
		_bm(_rows[_my - _top] - 3, _my - 2, 1, 2, _skin.darkened(0.16))


func _draw_eyes() -> void:
	var g := _eye_gap
	var lid := _skin.darkened(0.34)
	var white := SCLERA.lerp(_skin, 0.25) if _skin.v < 0.5 else SCLERA
	if _blinking: # Lids closed: a dark line where the eyes were.
		_bm(g, _ey, 3, 1, _skin.darkened(0.3))
	else:
		_bm(g, _ey, 3, 1, _skin.darkened(0.25) if _eye_style == 1 else white)
		# Pupils, nudged one block toward the desk during a glance.
		_b(CX + g + 1 + _glance, _ey, 1, 1, _eye_col)
		_b(CX - g - 2 + _glance, _ey, 1, 1, _eye_col)
	if _eye_style == 2 or _age >= 55 or _sick: # Heavy lids.
		_bm(g, _ey - 1, 3, 1, _skin.darkened(0.3 if _sick else 0.16))
	if _sick: # Dark, sunken circles.
		_bm(g, _ey + 1, 4, 1, _skin.darkened(0.3).lerp(BRUISE, 0.45))
		_bm(g + 2, _ey + 2, 2, 1, _skin.darkened(0.2).lerp(BRUISE, 0.3))
	elif _age >= 55:
		_bm(g, _ey + 1, 3, 1, _skin.darkened(0.1))
	if _mood == Mood.RELIEVED or _mood == Mood.DEVASTATED:
		_bm(g, _ey - 1, 3, 1, lid)
	if _mood == Mood.DEVASTATED:
		_bm(g + 1, _ey + 1, 1, 3, TEAR)
		_bm(g + 1, _ey + 4, 1, 1, TEAR.lightened(0.3))
	elif _mood == Mood.ANGRY:
		_bm(g, _ey, 1, 1, lid)
	if _glasses: # Round rims and a bridge; the lens catches a little light.
		var f := FRAME if _skin.v > 0.55 else METAL
		_bm(g, _ey - 1, 3, 1, f)
		_bm(g, _ey + 1, 3, 1, f)
		_bm(g - 1, _ey, 1, 1, f)
		_bm(g + 3, _ey, 1, 1, f)
		_bm(0, _ey, g - 1, 1, f)
		_bm(g, _ey, 3, 1, LENS)


func _draw_brows() -> void:
	var offsets: Array = BROWS[_mood]
	for i in 4:
		var o: int = offsets[i]
		var thick := 1 if _brow_thick and i < 2 else 0
		_bm(_eye_gap + i, _ey - 2 + o - thick, 1, 1 + thick, _brow_col)


func _draw_nose() -> void:
	var shade := _skin.darkened(0.14)
	var deep := _skin.darkened(0.34)
	var bridge := _nb - _ey if _nose == 1 else (_nb - _ey - 1 if _nose == 3 else 2)
	_b(CX, _nb - bridge, 1, bridge, shade) # Shadow down the right side.
	match _nose:
		1: # Long.
			_b(CX + 1, _nb, 1, 1, shade)
		2: # Wide, with dark nostrils.
			_bm(1, _nb, 1, 1, deep)
		3: # Prominent.
			_b(CX + 1, _nb - 2, 1, 2, shade)
	_b(CX - 1, _nb, 2 + int(_nose == 3), 1, shade if _nose == 2 else deep)


func _draw_mouth() -> void:
	var line := _skin.darkened(0.55)
	var w := _mouth
	var narrow := _mood == Mood.WORRIED or _mood == Mood.RELIEVED or _mood == Mood.DEVASTATED
	_bm(0, _my, w - int(narrow), 1, line.darkened(0.3) if _mood == Mood.ANGRY else line)
	match _mood:
		Mood.WORRIED: # Small and slightly open.
			_bm(0, _my + 1, 1, 1, line.darkened(0.3))
		Mood.RELIEVED: # Corners lift into a soft smile.
			_bm(w - 1, _my - 1, 1, 1, line)
		Mood.DEVASTATED: # Corners drop and the mouth falls open.
			_bm(w - 1, _my + 1, 1, 1, line)
			_bm(0, _my + 1, w - 2, 1, line.darkened(0.4))
		Mood.ANGRY: # Pressed tight.
			_bm(0, _my + 1, w - 1, 1, _skin.darkened(0.2))
	if _full_lips and (_mood == Mood.NEUTRAL or _mood == Mood.RELIEVED):
		var lip := _skin.darkened(0.08) if _sick else _skin.darkened(0.12).lerp(Color("8f5249"), 0.1)
		_bm(0, _my + 1, w - int(_mood == Mood.RELIEVED), 1, lip)


func _draw_wrinkles() -> void:
	if _age < 55:
		return
	var line := _skin.darkened(0.26)
	_bm(_eye_gap + 3, _ey + 1, 1, 1, line) # Crow's feet.
	_bm(3, _nb, 1, 1, line) # Folds beside the nose.
	_b(CX - 3, _ey - 4, 6, 1, line) # Forehead.
	if _age >= 75:
		_b(CX - 4, _ey - 6, 8, 1, line)
		_bm(_eye_gap + 4, _ey, 1, 1, line)
		_bm(_mouth, _my + 1, 1, 2, line)
		_bm(_rows[_hh - 3] - 2, _chin - 4, 1, 2, line)


func _draw_beard() -> void:
	var c := _hair_col.darkened(0.1).lerp(_skin, 0.25)
	if _beard == Beard.STUBBLE:
		for y in range(_nb + 1, _chin):
			_bm(0, y, _rows[y - _top] - 1, 1, Color(c, 0.3))
	elif _beard != Beard.NONE:
		_bm(0, _my - 1, _mouth + 1, 1, c) # Every beard comes with a mustache.
		if _beard == Beard.GOATEE:
			_bm(0, _my + 1, 1, _chin - _my - 1, c)
			_bm(0, _chin - 1, 1, 1, c.darkened(0.3))
		elif _beard == Beard.FULL:
			for y in range(_nb, _chin + 1):
				var w := _rows[mini(y - _top, _hh - 1)] - int(y == _chin)
				var hole := w - 2 if y < _my - 1 else 0 # Only the cheeks above the mustache.
				_bm(hole, y, w - hole, 1, c)
			_bm(0, _chin, 2, 1, c.darkened(0.3))


func _draw_hair(cap: PackedByteArray) -> void:
	if _hair == Hair.BALD:
		_b(CX - 5, _top + 1, 2, 1, _skin.lightened(0.15)) # Shine on the scalp.
	var buzz := _hair == Hair.BUZZ
	var col := _hair_col.lerp(_skin, 0.4) if buzz else _hair_col
	_paint(cap, col, NO_EDGE if buzz else col.darkened(0.5))
	for x in range(CX - 6, CX - 2): # Highlight on the lit side.
		var y := _top_of(cap, x)
		if y >= 0:
			_b(x, y + 1, 1, 1, col.lightened(0.12))
	if _sick and not buzz and _hair != Hair.BALD: # Unwashed, flyaway strands.
		for x: int in [CX - 3, CX + 2]:
			_b(x, _top_of(cap, x) - 2, 1, 1, col.darkened(0.5))


# --- Idle motion ---------------------------------------------------------------

## Starts or stops the blink and glance timers to match idle_motion and whether a
## patient is shown. The timers are internal children, made on first use.
func _arm_idle() -> void:
	var on := idle_motion and _shown
	if on and _blink_timer == null:
		_blink_timer = Timer.new()
		_blink_timer.one_shot = true
		_blink_timer.timeout.connect(_on_blink_timer)
		add_child(_blink_timer, false, Node.INTERNAL_MODE_FRONT)
		_glance_timer = Timer.new()
		_glance_timer.one_shot = true
		_glance_timer.timeout.connect(_on_glance_timer)
		add_child(_glance_timer, false, Node.INTERNAL_MODE_FRONT)
	_blinking = false
	_glance = 0
	_sweat_drop = 0
	if _blink_timer == null:
		return
	if on:
		_blink_timer.start(_idle_rng.randf_range(2.5, 5.5))
		_glance_timer.start(_idle_rng.randf_range(3.0, 7.0))
	else:
		_blink_timer.stop()
		_glance_timer.stop()


## The lids close for BLINK_TIME, then stay open for 2.5 to 5.5 seconds.
func _on_blink_timer() -> void:
	_blinking = not _blinking
	_blink_timer.start(BLINK_TIME if _blinking else _idle_rng.randf_range(2.5, 5.5))
	queue_redraw()


## Now and then the eyes slide one block toward the desk and back. A sick patient's
## temple bead slips down a block instead, about a third of the time.
func _on_glance_timer() -> void:
	if _glance != 0 or _sweat_drop != 0:
		_glance = 0
		_sweat_drop = 0
		_glance_timer.start(_idle_rng.randf_range(3.0, 7.0))
	elif _sick and _idle_rng.randf() < 0.35:
		_sweat_drop = 1
		_glance_timer.start(_idle_rng.randf_range(1.5, 3.0))
	else:
		_glance = 1
		_glance_timer.start(GLANCE_TIME)
	queue_redraw()


# --- Block-grid helpers -------------------------------------------------------

## One rect of blocks, clipped to the grid. While the figure is drawn the rect is
## shifted by fig_offset first, so a patient walking in is cropped at the edge.
func _b(x: int, y: int, w: int, h: int, c: Color) -> void:
	var r := Rect2i(x + _off.x, y + _off.y, maxi(w, 0), maxi(h, 0)).intersection(Rect2i(0, 0, GRID_W, GRID_H))
	if r.has_area():
		draw_rect(Rect2(Vector2(r.position * block), Vector2(r.size * block)), c)


## A run of blocks dx right of the axis, plus its mirror image on the left.
func _bm(dx: int, y: int, w: int, h: int, c: Color) -> void:
	_b(CX + dx, y, w, h, c)
	_b(CX - dx - w, y, w, h, c)


func _mask() -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(GRID_W * GRID_H)
	m.fill(0)
	return m


## A mask symmetric about the axis over rows y0 to y1, half_width(y) blocks each side.
func _sym_mask(y0: int, y1: int, half_width: Callable) -> PackedByteArray:
	var m := _mask()
	for y in range(y0, y1):
		var w: int = half_width.call(y)
		_span(m, y, CX - w, CX + w)
	return m


func _span(m: PackedByteArray, y: int, x0: int, x1: int) -> void:
	if y >= 0 and y < GRID_H:
		for x in range(maxi(x0, 0), mini(x1, GRID_W)):
			m[y * GRID_W + x] = 1


func _at(m: PackedByteArray, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < GRID_W and y < GRID_H and m[y * GRID_W + x] != 0


## First row of column x that the mask covers, or -1.
func _top_of(m: PackedByteArray, x: int) -> int:
	for y in GRID_H:
		if _at(m, x, y):
			return y
	return -1


## Nibbles every third edge block, giving curly hair a lumpy outline.
func _scallop(m: PackedByteArray) -> void:
	var nibbled := PackedInt32Array()
	for y in GRID_H:
		for x in GRID_W:
			var inner := _at(m, x - 1, y) and _at(m, x + 1, y) and _at(m, x, y - 1) and _at(m, x, y + 1)
			if _at(m, x, y) and not inner and (x + 2 * y) % 3 == 0:
				nibbled.append(y * GRID_W + x)
	for i in nibbled:
		m[i] = 0


## Fills a mask, with a one-block outline around it unless edge is transparent.
func _paint(m: PackedByteArray, fill: Color, edge: Color) -> void:
	if edge.a > 0.0:
		var outline := _mask()
		for i in m.size():
			if m[i] == 0:
				continue
			var x := i % GRID_W
			for j: int in [i - GRID_W, i + GRID_W, i - int(x > 0), i + int(x < GRID_W - 1)]:
				if j >= 0 and j < m.size() and m[j] == 0:
					outline[j] = 1
		_runs(outline, edge)
	_runs(m, fill)


## Draws a mask as horizontal runs of blocks, optionally shifted.
func _runs(m: PackedByteArray, c: Color, shift := Vector2i.ZERO) -> void:
	for y in GRID_H:
		var x := 0
		while x < GRID_W:
			var x0 := x
			while x < GRID_W and m[y * GRID_W + x] != 0:
				x += 1
			if x > x0:
				_b(x0 + shift.x, y + shift.y, x - x0, 1, c)
			else:
				x += 1
