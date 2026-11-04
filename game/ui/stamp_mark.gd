class_name StampMark
extends Control
## An inked rubber-stamp impression: APPROVED or DENIED, with a reason code.
## The ink is uneven the way real stamps are: a faint second strike a couple of
## pixels off, gaps along the border, and a seeded speckle of tiny dry spots (a
## small shader that drops pixels, so the paper underneath shows through).
##
## The reason code stays legible: only the main strike prints it, and the speckle
## leaves its band alone. At 16 px its strokes are one pixel wide, so a ghost or a
## dry spot turns one letter into another.

const STRIKE_OFFSET := Vector2(2, 1)
const STRIKE_ALPHA := 0.25
## Dry specks are SPECK_CELL pixels square. One in SPECK_RATE drops, and DRY_RATE
## more inside a few seeded dry patches: small and rare enough that a 48 px
## letter (three-pixel strokes) is never cut through.
const SPECK_CELL := 2.0
const SPECK_RATE := 0.02
const DRY_RATE := 0.06
## Where the reason code's baseline sits, from the top.
const CODE_BASELINE := 90.0
const STARVED_INK := """
shader_type canvas_item;
uniform float seed = 0.0;
uniform float cell = 2.0;
uniform float rate = 0.02;
uniform float dry_rate = 0.06;
// A band the speckle leaves whole, in the mark's own pixels: x, y, width, height.
uniform vec4 keep_band = vec4(0.0);
varying vec2 local_pos;

float noise(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233)) + seed * 0.618) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = local_pos;
	bool kept = p.x >= keep_band.x && p.y >= keep_band.y && p.x < keep_band.x + keep_band.z && p.y < keep_band.y + keep_band.w;
	if (!kept) {
		// Fine dry specks everywhere, a few more in seeded patches.
		float patch = noise(floor(p / 22.0) + vec2(seed, 7.0));
		float speck = noise(floor(p / cell));
		if (speck < rate + dry_rate * step(0.8, patch)) {
			COLOR.a = 0.0;
		}
	}
}
"""

static var _shader: Shader

var word: String = ""
var code: String = ""
var ink: Color = Palette.RED
## Picks where the ink runs dry. Any int; the desk rolls one per stamp.
var ink_seed: int = 0:
	set(value):
		ink_seed = value
		_set_ink("seed", float(posmod(value, 997)))
		queue_redraw()


static func create(approved: bool, reason_code: String) -> StampMark:
	var s := StampMark.new()
	s.word = "APPROVED" if approved else "DENIED"
	s.code = reason_code
	s.ink = Palette.GREEN if approved else Palette.RED
	s.size = Vector2(300, 112 if reason_code != "" else 88)
	s.pivot_offset = s.size / 2.0
	s.custom_minimum_size = s.size
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.ink_seed = hash([s.word, reason_code])
	return s


func _init() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = STARVED_INK
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("cell", SPECK_CELL)
	mat.set_shader_parameter("rate", SPECK_RATE)
	mat.set_shader_parameter("dry_rate", DRY_RATE)
	material = mat


## The band the reason code prints in, inside the inner border; the speckle
## leaves it whole. Empty without a code.
func code_band() -> Rect2:
	if code == "":
		return Rect2()
	return Rect2(12, CODE_BASELINE - 18.0, size.x - 24.0, 26.0)


func _draw() -> void:
	var band := code_band()
	_set_ink("keep_band", Vector4(band.position.x, band.position.y, band.size.x, band.size.y))
	_strike(STRIKE_OFFSET, STRIKE_ALPHA * 0.85, false)
	_strike(Vector2.ZERO, 0.85, true)


## One impression of the stamp at `offset`. The ghost strike leaves out the code.
func _strike(offset: Vector2, alpha: float, with_code: bool) -> void:
	var color := Color(ink, alpha)
	var rng := RandomNumberGenerator.new()
	rng.seed = ink_seed
	_frame(Rect2(offset, size), 6.0, color, rng)
	_frame(Rect2(offset, size).grow(-10), 2.0, color, rng)
	var font := UiTheme.font()
	var word_width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BIG).x
	_letter(word, offset + Vector2((size.x - word_width) / 2.0, 60), UiTheme.SIZE_BIG, color)
	if with_code and code != "":
		var code_width := font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
		_letter(code, offset + Vector2((size.x - code_width) / 2.0, CODE_BASELINE), UiTheme.SIZE_SMALL, color)


## Prints `text` with its baseline starting at `at`.
func _letter(text: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(UiTheme.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## A rectangular border `width` thick with a few short seeded gaps where the ink
## ran dry. Both strikes share the gaps (same seed), as one rubber would.
func _frame(r: Rect2, width: float, color: Color, rng: RandomNumberGenerator) -> void:
	var sides: Array[Rect2] = [
		Rect2(r.position, Vector2(r.size.x, width)),
		Rect2(Vector2(r.position.x, r.end.y - width), Vector2(r.size.x, width)),
		Rect2(r.position, Vector2(width, r.size.y)),
		Rect2(Vector2(r.end.x - width, r.position.y), Vector2(width, r.size.y)),
	]
	for side in sides:
		var horizontal := side.size.x > side.size.y
		var length := side.size.x if horizontal else side.size.y
		var gap_at := rng.randf_range(0.15, 0.85) * length
		var gap := rng.randf_range(4.0, 12.0) if rng.randf() < 0.7 else 0.0
		var pieces: Array[Vector2] = [Vector2(0.0, gap_at), Vector2(gap_at + gap, length)]
		for piece in pieces:
			if piece.y <= piece.x:
				continue
			if horizontal:
				draw_rect(Rect2(side.position + Vector2(piece.x, 0), Vector2(piece.y - piece.x, side.size.y)), color)
			else:
				draw_rect(Rect2(side.position + Vector2(0, piece.x), Vector2(side.size.x, piece.y - piece.x)), color)


func _set_ink(param: String, value: Variant) -> void:
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(param, value)
