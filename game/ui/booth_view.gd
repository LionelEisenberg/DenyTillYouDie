class_name BoothView
extends Control
## The view through the booth window: a waiting room on the patient's 40x48 grid at
## 10 px blocks, the patient at the glass, and the glass itself. The back window's
## light follows the day by patient count, never the clock, and one dark silhouette
## waits for every patient still to come. It also draws the roll-down shutter and
## the dressing for protest, audit and Compassion days. Purely visual: it ignores
## the mouse, and it clips everything (the 480 px figure too) to the window.
##
## A waiting patient whose head would show right beside the head at the glass (a
## dark lump on their hair, at this size) is left out while it would: the one at
## the glass hides them. One sitting fully behind that head stays.

enum Shape { HAT, LONG_HAIR, CHILD }

const BLOCK := 10
const GRID_W := 40
const GRID_H := 48
## Where block (0, 0) of the room and of the portrait sits inside the window.
const ORIGIN := Vector2(6, 0)
const VIEW_SIZE := Vector2(412, 472)
const MAX_SEATS := 7
## Seat centers, in grid columns, left to right.
const SEATS: Array[int] = [3, 9, 14, 20, 26, 31, 37]
## Which seat each patient takes, the longest wait first: those sit by the walls,
## where they show past whoever is at the glass, and the next to be called sit in
## the middle, right behind the counter (see seat_of()).
const SEAT_ORDER: Array[int] = [0, 6, 1, 5, 2, 4, 3]
## The back window, in grid blocks (frame included).
const BACK_WINDOW := Rect2i(3, 4, 10, 11)
const MORNING := Color("b9c4b0")
## Flat gray daylight, between the morning's green and the dusk's amber: newsprint
## a quarter darker.
const MIDDAY := Palette.NEWSPRINT * Color(0.75, 0.75, 0.75)
const DUSK := Color("c9a26a")
const STAND_TIME := 0.2
## How close (in blocks) a waiting head may sit beside the figure at the glass.
const HEAD_CLEARANCE := 2
## How far the shutter's slats sit apart, in pixels.
const SLAT := 16.0

## The patient at the glass.
var portrait: PortraitView
## Silhouettes still waiting (only MAX_SEATS of them are drawn).
var waiting: int = 0
## 0 at the first patient of the day, 1 at the last.
var progress: float = 0.0
## Alpha of the two streaks of light on the glass.
var sheen: float = 0.06
## False once the day-7 lights stutter: the back window goes dark.
var lights: bool = true
## 1 is rolled all the way down, 0 is up out of sight.
var shutter: float = 1.0
## Patients processed so far; Compassion Day's balloons sag one row each.
var processed: int = 0
var effects: Dictionary = {}

var _kinds: Array[int] = []
var _standing := -1
## The blocks the figure at the glass covers (PortraitView.coverage()), kept
## current as it walks; empty with nobody there.
var _cover := PackedByteArray()
var _time := 0.0
var _march_rng := RandomNumberGenerator.new()
var _march_wait := 0.0
var _march_t := -1.0
var _room: Control
var _front: Control
# Room colors, all from the booth's wall tones.
var _wall := Palette.WALL_LIGHT
var _wall_low := Palette.WALL
var _ceiling := Palette.WALL.darkened(0.2)
var _floor := Palette.WALL.darkened(0.3)
var _chair := Palette.WALL.darkened(0.14)
var _figure := Palette.WALL.darkened(0.32)
var _frame := Palette.DESK_DARK
var _metal := PortraitView.METAL.darkened(0.08)


func _init() -> void:
	size = VIEW_SIZE
	custom_minimum_size = VIEW_SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room = _layer()
	_room.draw.connect(_draw_room)
	portrait = PortraitView.new()
	portrait.block = BLOCK
	portrait.draw_wall = false
	portrait.position = ORIGIN
	portrait.figure_changed.connect(_on_figure_changed)
	add_child(portrait)
	_front = _layer()
	_front.draw.connect(_draw_front)


## The shape of each patient's silhouette, in arrival order (the player excluded).
## `seed_value` seeds the protest's marching.
func setup(kinds: Array[int], seed_value: int = 0) -> void:
	_kinds = kinds.duplicate()
	_march_rng.seed = seed_value
	_march_wait = _march_rng.randf_range(1.0, 3.0)
	_room.queue_redraw()


## How many patients are still waiting. With `animate`, a drop of one stands the
## front silhouette up for STAND_TIME before it goes.
func set_waiting(n: int, animate: bool = false) -> void:
	n = maxi(0, n)
	if animate and n == waiting - 1 and is_inside_tree():
		_standing = _front_patient()
		_room.queue_redraw()
		var gone := n
		# Held with the game while it's paused.
		await get_tree().create_timer(STAND_TIME, false).timeout
		if waiting != gone + 1:
			return
	_standing = -1
	waiting = n
	_room.queue_redraw()


## The back window's light: pale morning at 0, gray midday, amber dusk at 1.
func set_progress(f: float) -> void:
	progress = clampf(f, 0.0, 1.0)
	_room.queue_redraw()


func set_event(day_effects: Dictionary) -> void:
	effects = day_effects.duplicate()
	_room.queue_redraw()


func set_sheen(alpha: float) -> void:
	sheen = alpha
	_front.queue_redraw()


func set_lights(on: bool) -> void:
	lights = on
	_room.queue_redraw()


func set_shutter(f: float) -> void:
	shutter = clampf(f, 0.0, 1.0)
	_front.queue_redraw()


func set_processed(n: int) -> void:
	processed = n
	_room.queue_redraw()


## Stands the front silhouette up for a moment; it disappears with the next drop.
func stand_front() -> void:
	set_waiting(waiting - 1, true)


## The light coming through the back window right now.
func window_light() -> Color:
	if not lights:
		return Palette.BG_DARK
	if progress < 0.5:
		return MORNING.lerp(MIDDAY, progress * 2.0)
	return MIDDAY.lerp(DUSK, (progress - 0.5) * 2.0)


func _process(delta: float) -> void:
	if not (effects.get("protest", false) or effects.get("audit", false)):
		return
	_time += delta
	if effects.get("protest", false):
		if _march_t < 0.0:
			_march_wait -= delta
			if _march_wait <= 0.0:
				_march_t = 0.0
		else:
			_march_t += delta
			if _march_t > 3.0:
				_march_t = -1.0
				_march_wait = _march_rng.randf_range(4.0, 7.0)
	_room.queue_redraw()


func _layer() -> Control:
	var c := Control.new()
	c.size = VIEW_SIZE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


## The first patient still waiting: the next one to be called.
func _front_patient() -> int:
	return _kinds.size() - waiting


## The waiting patients drawn right now, as Vector2i(patient index, seat index).
## Patients k and k + MAX_SEATS share a seat (see seat_of()). A seat emptied by the
## last NEXT! stays empty until the one after it, so nobody seems to sit straight
## back down; and a head that would crowd the one at the glass is hidden behind it.
func seated() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var first := _front_patient()
	var room := MAX_SEATS if first == 0 else MAX_SEATS - 1
	for k in range(first, mini(first + room, _kinds.size())):
		var seat := seat_of(k)
		if k == _standing or not _crowds_the_glass(SEATS[seat], _kinds[k]):
			out.append(Vector2i(k, seat))
	return out


## The seat patient `k` (in calling order) waits in. Of the first MAX_SEATS, the
## last to be called sits by the left wall, the one before by the right, and so
## on inward. A patient past those takes the seat of the one called MAX_SEATS
## before them, which is in the middle, so the walls stay filled.
func seat_of(k: int) -> int:
	return SEAT_ORDER[posmod(mini(_kinds.size(), MAX_SEATS) - 1 - k, MAX_SEATS)]


func _on_figure_changed() -> void:
	_cover = portrait.coverage() if portrait.is_shown() else PackedByteArray()
	_room.queue_redraw()


## Whether the head of a waiting patient seated at column `cx` would show next to
## the figure at the glass: partly behind it, or within HEAD_CLEARANCE blocks of
## it. A head entirely behind the figure doesn't show, and doesn't count.
func _crowds_the_glass(cx: int, kind: int) -> bool:
	if _cover.is_empty():
		return false
	var head := _head_box(cx, kind)
	var cells := 0
	var hidden := 0
	var near := false
	for y in range(head.position.y, head.end.y):
		for x in range(head.position.x - HEAD_CLEARANCE, head.end.x + HEAD_CLEARANCE):
			var covered := x >= 0 and x < GRID_W and y >= 0 and y < GRID_H and _cover[y * GRID_W + x] != 0
			if x >= head.position.x and x < head.end.x:
				cells += 1
				hidden += int(covered)
			elif covered:
				near = true
	if hidden == cells:
		return false
	return hidden > 0 or near


## The blocks a seated silhouette's head (hat, hair and all) takes up.
static func _head_box(cx: int, kind: int) -> Rect2i:
	if kind == Shape.CHILD:
		return Rect2i(cx - 1, 24, 2, 3)
	return Rect2i(cx - 3, 18, 5, 7)


# --- the room ------------------------------------------------------------------

func _draw_room() -> void:
	_room.draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), _wall)
	_rb(-1, 0, GRID_W + 2, 2, _ceiling)
	_rb(-1, 21, GRID_W + 2, 1, _wall.darkened(0.1)) # Chair rail.
	_rb(-1, 22, GRID_W + 2, 13, _wall_low)
	_rb(-1, 35, GRID_W + 2, 1, _floor.darkened(0.2)) # Baseboard.
	_rb(-1, 36, GRID_W + 2, GRID_H - 36, _floor)
	_draw_back_window()
	if effects.get("audit", false):
		_draw_auditor()
	for s in MAX_SEATS:
		_draw_chair(SEATS[s])
	for sat in seated():
		_draw_silhouette(SEATS[sat.y], _kinds[sat.x], sat.x == _standing)
	if effects.get("compassion", false):
		_draw_compassion()
	if effects.get("audit", false):
		_draw_camera()


func _draw_back_window() -> void:
	var w := BACK_WINDOW
	var light := window_light()
	_rb(w.position.x, w.position.y, w.size.x, w.size.y, _frame)
	_rb(w.position.x + 1, w.position.y + 1, w.size.x - 2, w.size.y - 2, light)
	if lights: # A brighter top half, as if the sky were higher up.
		_rb(w.position.x + 1, w.position.y + 1, w.size.x - 2, 3, light.lightened(0.08))
	if effects.get("protest", false) and _march_t >= 0.0:
		_draw_placards()
	_rb(w.position.x + 5, w.position.y + 1, 1, w.size.y - 2, _frame) # Mullions.
	_rb(w.position.x + 1, w.position.y + 5, w.size.x - 2, 1, _frame)
	_rb(w.position.x - 1, w.end.y, w.size.x + 2, 1, _wall.lightened(0.06)) # Sill.
	if lights: # Light falling on the wall below the sill.
		_rb(w.position.x + 1, w.end.y + 1, w.size.x - 2, 5, Color(light, 0.06))


## Blank placards on sticks, bobbing past outside the back window. Never lettered.
func _draw_placards() -> void:
	var inner := Rect2i(BACK_WINDOW.position + Vector2i.ONE, BACK_WINDOW.size - Vector2i(2, 2))
	var travel := float(inner.size.x + 20)
	var lead := inner.end.x + 4 - roundi(_march_t / 3.0 * travel)
	var frame := int(_time * 4.0) % 2
	for i in 3:
		var x := lead + i * 5
		var bob := (frame + i) % 2
		var top := inner.position.y + bob # High in the window, above most heads.
		_rb_clip(Rect2i(x + 1, top + 3, 1, 5), inner, _frame.lightened(0.05)) # Stick.
		_rb_clip(Rect2i(x, top, 4, 3), inner, Palette.PAPER_SHADE.darkened(0.12 * i))


func _draw_chair(cx: int) -> void:
	_rb(cx - 2, 26, 5, 5, _chair) # Back.
	_rb(cx - 2, 26, 5, 1, _chair.lightened(0.06))
	_rb(cx - 2, 31, 5, 1, _chair.darkened(0.15)) # Seat.
	_rb(cx - 2, 32, 1, 3, _chair.darkened(0.2)) # Legs.
	_rb(cx + 2, 32, 1, 3, _chair.darkened(0.2))


## A waiting patient: one flat, dark, low-contrast shape on a chair, narrow enough
## that the chair backs show between neighbors.
func _draw_silhouette(cx: int, kind: int, standing: bool) -> void:
	var lift := -1 if standing else 0
	var c := _figure
	if kind == Shape.CHILD:
		_rb(cx - 1, 24 + lift, 2, 3, c) # Head.
		_rb(cx - 1, 27 + lift, 3, 1, c) # Shoulders...
		_rb(cx - 2, 28 + lift, 4, 4, c) # ...and body, feet off the floor.
		return
	_rb(cx - 2, 20 + lift, 3, 4, c) # Head.
	_rb(cx - 1, 24 + lift, 2, 1, c) # Neck.
	_rb(cx - 2, 25 + lift, 4, 1, c) # Sloping shoulders...
	_rb(cx - 2, 26 + lift, 5, 6, c) # ...and body.
	if kind == Shape.HAT:
		_rb(cx - 3, 20 + lift, 5, 1, c) # Brim...
		_rb(cx - 2, 18 + lift, 3, 2, c) # ...and crown.
	else:
		_rb(cx - 2, 19 + lift, 4, 1, c) # Long hair over the head and down the back.
		_rb(cx + 1, 20 + lift, 1, 6, c)
		_rb(cx - 3, 21 + lift, 1, 4, c)


## Audit day: a gray suit at the back of the room, all shift, holding a white
## clipboard on the side away from the counter (where it can't sit against the
## face at the glass).
func _draw_auditor() -> void:
	var cx := 35
	var suit := Palette.TEXT_DIM.darkened(0.42)
	_rb(cx - 2, 11, 4, 5, _figure) # Head.
	_rb(cx - 1, 16, 2, 1, _figure)
	_rb(cx - 3, 17, 7, 18, suit)
	_rb(cx - 2, 17, 5, 1, suit.lightened(0.08))
	_rb(cx, 17, 1, 4, Palette.PAPER_SHADE.darkened(0.2)) # Shirt and tie.
	_rb(cx + 2, 22, 3, 4, Palette.PAPER) # Clipboard.
	_rb(cx + 3, 21, 1, 1, _metal)
	_rb(cx - 2, 26, 1, 9, suit.darkened(0.2)) # Trouser crease.


## A small camera high on the wall, its red light blinking once a second.
func _draw_camera() -> void:
	_rb(38, 1, 1, 2, _metal.darkened(0.3)) # Bracket.
	_rb(35, 2, 3, 2, _metal)
	_rb(35, 3, 1, 1, _frame) # Lens.
	if fmod(_time, 1.0) < 0.5:
		_rb(37, 2, 1, 1, Palette.RED.lightened(0.25))


## Compassion Day: a paper banner across the top of the window and two balloons
## that sink one row for every patient processed.
func _draw_compassion() -> void:
	var paper := Palette.PAPER
	var edge := Palette.PAPER_SHADE.darkened(0.2)
	for part in 3: # Three panels; the middle one sags a block.
		var x0 := 5 + part * 10
		var y0 := 1 + int(part == 1)
		_rb(x0, y0, 10, 2, paper)
		_rb(x0, y0 + 2, 10, 1, edge)
	_rb(4, 1, 1, 2, edge) # Tied at both ends.
	_rb(35, 1, 1, 2, edge)
	var font := UiTheme.font()
	var text := "COMPASSION DAY"
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
	var at := ORIGIN + Vector2((GRID_W * BLOCK - width) / 2.0, 2.0 * BLOCK + 11.0)
	_room.draw_string(font, at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, Palette.RED_DARK)
	var sag := mini(processed, 12)
	_draw_balloon(2, 4 + sag, Palette.RED.lightened(0.12), 4)
	_draw_balloon(37, 4 + sag, Palette.AMBER.darkened(0.12), 35)


func _draw_balloon(cx: int, top: int, color: Color, tie_x: int) -> void:
	_rb(cx - 1, top, 2, 1, color)
	_rb(cx - 1, top + 1, 3, 2, color)
	_rb(cx - 1, top + 3, 2, 1, color)
	_rb(cx - 1, top + 1, 1, 1, color.lightened(0.3)) # Shine.
	_rb(cx, top + 4, 1, 1, color.darkened(0.3)) # Knot.
	# The string runs back up to the banner's end.
	var y0 := 3
	var y1 := top + 5
	for y in range(mini(y0, y1), maxi(y0, y1)):
		var t := float(y - y0) / maxf(1.0, float(y1 - y0))
		_rb(roundi(lerpf(tie_x, cx, t)), y, 1, 1, Color(Palette.INK_FADED, 0.6))


# --- the glass and the shutter -----------------------------------------------------

func _draw_front() -> void:
	# Two faint diagonal streaks of light on the glass.
	var white := Color(1, 1, 1, sheen)
	_front.draw_colored_polygon(PackedVector2Array([Vector2(250, 0), Vector2(300, 0), Vector2(90, VIEW_SIZE.y), Vector2(40, VIEW_SIZE.y)]), white)
	_front.draw_colored_polygon(PackedVector2Array([Vector2(322, 0), Vector2(338, 0), Vector2(128, VIEW_SIZE.y), Vector2(112, VIEW_SIZE.y)]), Color(white, sheen * 0.7))
	if shutter > 0.0:
		_draw_shutter()


## Horizontal metal slats rolled down to `shutter`, with a CLOSED sign hanging on it.
func _draw_shutter() -> void:
	var bottom := roundf(VIEW_SIZE.y * shutter)
	var y := bottom - SLAT
	while y > -SLAT:
		_front.draw_rect(Rect2(0, y, VIEW_SIZE.x, SLAT), _metal)
		_front.draw_rect(Rect2(0, y, VIEW_SIZE.x, 2), _metal.lightened(0.14))
		_front.draw_rect(Rect2(0, y + SLAT - 3, VIEW_SIZE.x, 3), _metal.darkened(0.22))
		y -= SLAT
	_front.draw_rect(Rect2(0, bottom - 10, VIEW_SIZE.x, 10), _metal.darkened(0.35)) # Bottom bar.
	_front.draw_rect(Rect2(VIEW_SIZE.x / 2.0 - 24, bottom - 7, 48, 4), _metal.darkened(0.55)) # Handle.
	# The sign hangs from two strings a little above the bottom bar.
	var card := Rect2(VIEW_SIZE.x / 2.0 - 70, bottom - 150, 140, 46)
	var ink := Palette.INK_FADED
	_front.draw_line(Vector2(card.position.x + 20, card.position.y - 34), Vector2(card.position.x + 20, card.position.y), ink, 2.0)
	_front.draw_line(Vector2(card.end.x - 20, card.position.y - 34), Vector2(card.end.x - 20, card.position.y), ink, 2.0)
	_front.draw_rect(card, Palette.PAPER)
	_front.draw_rect(card, Palette.PAPER_SHADE.darkened(0.25), false, 2.0)
	var font := UiTheme.font()
	var width := font.get_string_size("CLOSED", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_TITLE).x
	_front.draw_string(font, Vector2(card.get_center().x - width / 2.0, card.position.y + 34).round(), "CLOSED", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_TITLE, Palette.RED_DARK)


# --- grid helpers ----------------------------------------------------------------

## A rect of room blocks.
func _rb(x: int, y: int, w: int, h: int, c: Color) -> void:
	if w > 0 and h > 0:
		_room.draw_rect(Rect2(ORIGIN + Vector2(x, y) * BLOCK, Vector2(w, h) * BLOCK), c)


## A rect of room blocks, cut to `clip` (in blocks).
func _rb_clip(r: Rect2i, clip: Rect2i, c: Color) -> void:
	var cut := r.intersection(clip)
	if cut.has_area():
		_rb(cut.position.x, cut.position.y, cut.size.x, cut.size.y, c)
