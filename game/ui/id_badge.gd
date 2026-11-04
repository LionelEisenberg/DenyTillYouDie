class_name IdBadge
extends Control
## A Benevolence Mutual staff badge: the photo from the pre-employment physical
## (the same face as the player's own claim on day 7), the name as signed and
## the desk. create() makes the full badge clipped on at the agreement;
## create_mini() the small one that sits in the booth all week.

const FULL := 0.5
const MINI := 0.25
const HEADER := "BENEVOLENCE MUTUAL - STAFF"
const TITLE := "CLAIMS ADJUSTER #4471 - DESK 11"
## Head and shoulders, in portrait blocks.
const CROP := Rect2i(4, 3, 32, 40)
const CLIP := Palette.TEXT_DIM

var player_name: String = ""
var portrait_seed: int = 0
var age: int = 0
## FULL (8 px blocks drawn at 4 px) or MINI (at 2 px), so blocks stay whole pixels.
var scale_factor: float = FULL
var portrait: PortraitView
var photo_rect := Rect2()


## A badge for `signed_name` (cleaned the way GameState cleans it) at FULL or
## MINI; any other factor snaps to the nearer of the two.
static func create(signed_name: String, factor: float) -> IdBadge:
	var b := IdBadge.new()
	b.player_name = signed_name
	b.scale_factor = MINI if factor < (FULL + MINI) / 2.0 else FULL
	# The same seed and age as ClaimGenerator.make_player_claim.
	b.portrait_seed = hash(signed_name)
	b.age = int(Scripted.PLAYER["age"])
	b._build()
	return b


static func create_mini(signed_name: String) -> IdBadge:
	return create(signed_name, MINI)


## The clinic's photo wall: a cool gray-blue that sits behind any face.
static func backdrop() -> Color:
	return Palette.CARD.lerp(Palette.INK_BLUE, 0.25)


## Every line of text on the badge, top to bottom.
func texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for child in get_children():
		_collect_text(child, out)
	return out


func _collect_text(node: Node, out: PackedStringArray) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_collect_text(child, out)


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var full := scale_factor == FULL
	size = Vector2(432, 252) if full else Vector2(280, 96)
	custom_minimum_size = size
	portrait = PortraitView.new()
	portrait.show_patient(portrait_seed, age, false)
	# Screen pixels per portrait block, from the portrait's own size (8 px
	# blocks by default): 4 on the full badge, 2 on the mini.
	var px := roundi(portrait.size.x / PortraitView.GRID_W * scale_factor)
	photo_rect = Rect2(Vector2(16, 72) if full else Vector2(8, 8), Vector2(CROP.size * px))

	# The photo: a plain clipping holder, the backdrop, and the face.
	var holder := Control.new()
	holder.position = photo_rect.position
	holder.size = photo_rect.size
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var wall := UiTheme.rect(backdrop())
	wall.size = photo_rect.size
	holder.add_child(wall)
	portrait.position = -Vector2(CROP.position * px)
	portrait.scale = Vector2(scale_factor, scale_factor)
	# A photo: no booth wall behind it (where PortraitView offers that), and
	# nothing that moves.
	if "draw_wall" in portrait:
		portrait.set("draw_wall", false)
	portrait.process_mode = Node.PROCESS_MODE_DISABLED
	holder.add_child(portrait)

	if full:
		add_child(_centered(HEADER, UiTheme.SIZE_BODY, Palette.CARD, Rect2(0, 26, size.x, 28)))
		var column := VBoxContainer.new()
		column.position = Vector2(160, 70)
		column.custom_minimum_size = Vector2(256, 0)
		column.add_theme_constant_override("separation", 4)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		column.add_child(_para(player_name, UiTheme.SIZE_BODY, Palette.INK))
		column.add_child(_text(TITLE, UiTheme.SIZE_SMALL, Palette.INK))
		column.add_child(UiTheme.rect(Color(0, 0, 0, 0), Vector2(0, 6)))
		var exam := DateUtil.fmt(DateUtil.game_date(1) - 10)
		column.add_child(_para("Photo and vitals taken at pre-employment physical, %s. BP 158/102. Noted." % exam, UiTheme.SIZE_SMALL, Palette.INK_FADED))
	else:
		add_child(_centered(HEADER, UiTheme.SIZE_SMALL, Palette.CARD, Rect2(80, 10, 192, 18)))
		var who := _text(player_name, UiTheme.SIZE_SMALL, Palette.INK)
		who.position = Vector2(84, 32)
		who.size = Vector2(190, 18)
		who.clip_text = true
		add_child(who)
		var title := _text(TITLE, UiTheme.SIZE_SMALL, Palette.INK_FADED)
		title.position = Vector2(84, 52)
		add_child(title)


## A left-aligned label placed so its text is centered across `band`. Measured
## with the pixel font directly: a Label sizes itself with the default font
## until it joins a themed tree, so its own width can't be trusted here.
static func _centered(text: String, font_size: int, color: Color, band: Rect2) -> Label:
	var l := _text(text, font_size, color)
	var w := UiTheme.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	l.position = Vector2(band.position.x + roundf((band.size.x - w) / 2.0), band.position.y)
	return l


## A label in the pixel font whatever tree it ends up in.
static func _text(text: String, font_size: int, color: Color) -> Label:
	var l := UiTheme.label(text, font_size, color)
	l.add_theme_font_override("font", UiTheme.font())
	return l


static func _para(text: String, font_size: int, color: Color) -> Label:
	var l := UiTheme.para(text, 256, font_size, color)
	l.add_theme_font_override("font", UiTheme.font())
	return l


func _draw() -> void:
	var full := scale_factor == FULL
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Palette.CARD)
	if full:
		draw_rect(Rect2(2, 24, size.x - 4, 32), Palette.CARD_BAND)
		# The slot, and the clip through it as if just clipped on.
		draw_rect(Rect2(size.x / 2.0 - 28, 8, 56, 8), Palette.CARD_BAND.darkened(0.45))
		var clip := Rect2(size.x / 2.0 - 20, -22, 40, 34)
		draw_rect(clip, CLIP)
		draw_rect(clip, CLIP.darkened(0.5), false, 2.0)
		draw_rect(Rect2(clip.position.x + 8, clip.position.y + 6, 24, 4), CLIP.lightened(0.25))
		draw_rect(Rect2(clip.position.x + 8, clip.end.y - 10, 24, 4), CLIP.darkened(0.35))
	else:
		draw_rect(Rect2(80, 8, 192, 20), Palette.CARD_BAND)
	draw_rect(r, Palette.CARD_BAND, false, 2.0)
	draw_rect(photo_rect.grow(2), Palette.INK)
	# A barcode nobody will ever scan, the same for the same name.
	var rng := RandomNumberGenerator.new()
	rng.seed = portrait_seed
	var x := 300.0 if full else 84.0
	var y := 212.0 if full else 74.0
	var stop := size.x - 18.0 if full else 200.0
	while x < stop:
		var w := float(rng.randi_range(1, 3))
		draw_rect(Rect2(x, y, w, 22 if full else 14), Palette.INK)
		x += w + float(rng.randi_range(1, 3))
