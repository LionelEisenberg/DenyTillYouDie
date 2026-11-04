class_name DeskProps
extends Control
## The things on the desk that remember the week, in the strip along its lower
## edge where no paper lands: a tear-off calendar showing today, with the torn-off
## days piled beside it; a framed family photo that never changes, except for a
## black ribbon across the corner of the picture of each family member who has
## died; and one more faint coffee ring for every day already worked. Nothing
## here says anything the ledger hasn't. It ignores the mouse throughout, so
## papers on top of it drag as usual.

const SIZE := Vector2(1360, 864)
## Every prop stays below this line, clear of where papers spawn.
const STRIP_TOP := 760.0
const CALENDAR_RECT := Rect2(436, 768, 90, 90)
## The photo: three faces side by side behind a mat in a dark wooden frame,
## tilted just enough to stay inside the strip at every corner.
const PHOTO_POS := Vector2(1072, 763)
const PHOTO_TILT := -1.2
const FRAME_BORDER := 5.0
const MAT := 3.0
const FACE_SIZE := Vector2(80, 82)
const FACE_GAP := 3.0
## Faces are PortraitViews at this scale (whole 2 px blocks), cropped top and bottom.
const FACE_SCALE := 0.25
const FACE_CROP_TOP := 6.0
## [name the face is seeded from, age], left to right.
const FAMILY_PHOTO: Array = [["Sam", 38], ["Riley", 9], ["Mom", 68]]
## Whose face each one is: RunState.FAMILY_TEMPLATE ids, in FAMILY_PHOTO's order.
const FAMILY_IDS: Array[String] = ["partner", "child", "mother"]
## A mourning ribbon across the bottom right corner of one face's picture: the
## lower corners stay in view when a letter spawned above the photo (the desk's
## extra papers land at y 520) overlaps its top edge.
const RIBBON_CORNER := 3
const RIBBON_REACH := 24.0
const RIBBON_BAND := 8.0
const RING_RADIUS := 16.0

var day: int = 1
## Where each coffee ring sits, oldest first: one per day already worked.
var rings: Array[Vector2] = []
## Black ribbons on the photo: one on the picture of each family member who has died.
var ribbons: int = 0
var _calendar: Calendar


static func create(run: RunState) -> DeskProps:
	var props := DeskProps.new()
	props._build(run)
	return props


static func photo_size() -> Vector2:
	var faces := FAMILY_PHOTO.size()
	return Vector2(faces * FACE_SIZE.x + (faces - 1) * FACE_GAP, FACE_SIZE.y) + Vector2.ONE * 2.0 * (FRAME_BORDER + MAT)


## The first `count` coffee ring spots for a run. Each ring keeps its spot as more
## are added, clear of the calendar, the photo and the other rings.
static func ring_spots(run_seed: int, count: int) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "coffee"])
	var keep_out: Array[Rect2] = [CALENDAR_RECT.grow(RING_RADIUS + 8.0), Rect2(PHOTO_POS, photo_size()).grow(RING_RADIUS + 8.0)]
	var spots: Array[Vector2] = []
	while spots.size() < count:
		var spot := Vector2.ZERO
		for attempt in 60:
			spot = Vector2(rng.randf_range(40.0, SIZE.x - 40.0), rng.randf_range(STRIP_TOP + RING_RADIUS + 6.0, SIZE.y - RING_RADIUS - 6.0))
			var clear := true
			for area in keep_out:
				clear = clear and not area.has_point(spot)
			for other in spots:
				clear = clear and spot.distance_to(other) > RING_RADIUS * 2.5
			if clear:
				break
		spots.append(spot)
	return spots


## "SUN 8": what the calendar shows today.
func calendar_text() -> String:
	return "%s %d" % [_calendar.weekday, _calendar.day_of_month]


func _init() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build(run: RunState) -> void:
	day = run.day
	var worked := maxi(0, day - 1)
	rings = ring_spots(run.run_seed, worked)
	var ring_layer := CoffeeRings.new(rings, SIZE, run.run_seed)
	ring_layer.name = "CoffeeRings"
	add_child(ring_layer)
	_calendar = Calendar.new(DateUtil.game_date(day), worked, run.run_seed)
	_calendar.name = "Calendar"
	_calendar.position = CALENDAR_RECT.position
	add_child(_calendar)
	add_child(_photo(run))


func _photo(run: RunState) -> Control:
	var frame := PhotoFrame.new()
	frame.name = "FamilyPhoto"
	frame.position = PHOTO_POS
	frame.size = photo_size()
	frame.pivot_offset = frame.size / 2.0
	frame.rotation_degrees = PHOTO_TILT
	for i in FAMILY_PHOTO.size():
		var who: Array = FAMILY_PHOTO[i]
		# Containers reset scale, so each face sits in a plain holder that crops it.
		var holder := Control.new()
		holder.name = "Face_%s" % FAMILY_IDS[i]
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.clip_contents = true
		holder.position = Vector2.ONE * (FRAME_BORDER + MAT) + Vector2(i * (FACE_SIZE.x + FACE_GAP), 0)
		holder.size = FACE_SIZE
		var face := PortraitView.new()
		face.scale = Vector2(FACE_SCALE, FACE_SCALE)
		face.position = Vector2(0, -FACE_CROP_TOP)
		face.show_patient(hash(String(who[0])), int(who[1]), false)
		face.set_expression(PortraitView.Mood.RELIEVED)
		holder.add_child(face)
		# The ribbon goes on that person's own picture; the holder clips it there.
		if not bool(run.member(FAMILY_IDS[i]).get("alive", true)):
			var ribbon := Ribbon.new(RIBBON_CORNER, RIBBON_REACH, RIBBON_BAND)
			ribbon.name = "Ribbon_%s" % FAMILY_IDS[i]
			ribbon.size = FACE_SIZE
			holder.add_child(ribbon)
			ribbons += 1
		frame.add_child(holder)
	return frame


## Faint rings left by a coffee mug, one per day already worked: each two or
## three broken arcs of slightly different radius and width, and one short darker
## arc on the side where the mug sat.
class CoffeeRings extends Control:
	const RADIUS := 16.0
	const FAINT_ALPHA := Vector2(0.24, 0.3)
	const DARK_ALPHA := 0.42
	var _spots: Array[Vector2] = []
	var _seed := 0


	func _init(spots: Array[Vector2], area: Vector2, run_seed: int) -> void:
		_spots = spots
		_seed = run_seed
		size = area
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	## The arcs ring `i` is drawn with, darkest last: {radius, from, to, alpha,
	## width}, angles in radians. Seeded by the ring's place in the week, so each
	## ring keeps its look from day to day.
	func ring_arcs(i: int) -> Array[Dictionary]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([_seed, "ring", i])
		var arcs: Array[Dictionary] = []
		var count := rng.randi_range(2, 3)
		var turn := rng.randf() * TAU
		var span := TAU / count
		for k in count:
			arcs.append({
				"radius": RADIUS + rng.randf_range(-1.5, 1.0),
				"from": turn + k * span + rng.randf_range(0.0, 0.2),
				"to": turn + (k + 1) * span - rng.randf_range(0.25, 0.6),
				"alpha": rng.randf_range(FAINT_ALPHA.x, FAINT_ALPHA.y),
				"width": rng.randf_range(1.5, 2.5),
			})
		var sat := turn + rng.randf() * TAU
		arcs.append({"radius": RADIUS - 0.5, "from": sat, "to": sat + rng.randf_range(0.7, 1.2), "alpha": DARK_ALPHA, "width": 2.5})
		return arcs


	func _draw() -> void:
		var stain := Palette.DESK_DARK.darkened(0.45)
		for i in _spots.size():
			for arc: Dictionary in ring_arcs(i):
				draw_arc(_spots[i], arc["radius"], arc["from"], arc["to"], 20, Color(stain, arc["alpha"]), arc["width"])


## A tear-off day calendar on its own little stand, with the days already torn
## off scattered beside it.
class Calendar extends Control:
	const PAD := Vector2(90, 84)
	var weekday := ""
	var day_of_month := 0
	var month := ""
	## One [position, angle] per torn-off day.
	var _stubs: Array = []


	func _init(date: int, torn: int, run_seed: int) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(PAD.x, PAD.y + 6.0)
		weekday = DateUtil.weekday(date).left(3).to_upper()
		day_of_month = DateUtil.to_ymd(date).z
		# "Sunday, March 8, 2026" -> "MARCH"
		month = DateUtil.fmt_long(date).get_slice(", ", 1).get_slice(" ", 0).to_upper()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([run_seed, "calendar"])
		for i in torn:
			_stubs.append([Vector2(rng.randf_range(93.0, 118.0), rng.randf_range(36.0, 84.0)), rng.randf_range(-0.9, 0.9)])


	func _draw() -> void:
		var font := UiTheme.font()
		for stub: Array in _stubs:
			_draw_stub(stub[0], stub[1])
		var pad := Rect2(Vector2(0, 6), PAD)
		draw_rect(Rect2(pad.position + Vector2(4, 4), pad.size), Color(0, 0, 0, 0.35))
		draw_rect(pad, Palette.PAPER)
		var band := Rect2(pad.position, Vector2(PAD.x, 22))
		draw_rect(band, Palette.RED_DARK)
		for x: float in [22.0, 62.0]:
			draw_rect(Rect2(x, 0, 6, 12), Palette.INK_FADED)
		draw_string(font, Vector2(0, band.position.y + 16), month, HORIZONTAL_ALIGNMENT_CENTER, PAD.x, UiTheme.SIZE_SMALL, Palette.PAPER)
		draw_string(font, Vector2(0, pad.position.y + 64), str(day_of_month), HORIZONTAL_ALIGNMENT_CENTER, PAD.x, UiTheme.SIZE_BIG, Palette.INK)
		draw_string(font, Vector2(0, pad.end.y - 6), weekday, HORIZONTAL_ALIGNMENT_CENTER, PAD.x, UiTheme.SIZE_SMALL, Palette.INK_FADED)
		draw_rect(pad, Palette.PAPER_SHADE, false, 2.0)


	## A torn-off page: a scrap of paper with the red band still on top.
	func _draw_stub(at: Vector2, angle: float) -> void:
		var corners := PackedVector2Array([Vector2(-9, -6), Vector2(9, -6), Vector2(9, 3), Vector2(4, 6), Vector2(0, 3), Vector2(-5, 6), Vector2(-9, 4)])
		var band := PackedVector2Array([Vector2(-9, -6), Vector2(9, -6), Vector2(9, -3), Vector2(-9, -3)])
		var turn := Transform2D(angle, at)
		draw_colored_polygon(turn * corners, Palette.PAPER_ALT)
		draw_colored_polygon(turn * band, Palette.RED_DARK)


## The photo's dark wooden frame and paper mat, drawn under the faces.
class PhotoFrame extends Control:
	const BORDER := 5.0


	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(4, 4), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Palette.DESK_DARK)
		draw_rect(r.grow(-1.0), Palette.DESK_LIGHT, false, 2.0)
		draw_rect(r.grow(-BORDER), Palette.PAPER)


## A black mourning ribbon across one corner of a picture (0 top left, 1 top
## right, 2 bottom left, 3 bottom right): a band `width` wide, starting `reach`
## in from the corner along both edges.
class Ribbon extends Control:
	var corner := 0
	var reach := 28.0
	var width := 9.0


	func _init(which: int, reach_px: float = 28.0, width_px: float = 9.0) -> void:
		corner = which
		reach = reach_px
		width = width_px
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	func _draw() -> void:
		var band := PackedVector2Array([Vector2(-2, reach), Vector2(reach, -2), Vector2(reach + width, -2), Vector2(-2, reach + width)])
		for i in band.size():
			var p := band[i]
			if corner % 2 == 1:
				p.x = size.x - p.x
			if corner >= 2:
				p.y = size.y - p.y
			band[i] = p
		draw_colored_polygon(band, Palette.BG_DARK)
