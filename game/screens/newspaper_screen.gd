class_name NewspaperScreen
extends ScreenBase
## The morning paper: one lead story and a row of smaller items. A story about
## someone who has a face on file (`portrait_seed`, `age`) runs their photo:
## 120x144 beside the lead, 80x96 beside an item.

const WIDTH := 1500.0
const PHOTO_BLOCK := 2
const LEAD_PHOTO_BLOCK := 3
const GAP := 32
const PHOTO_GAP := 12

## Set by the caller; defaults to this morning's paper.
var paper: Dictionary = {}
var continue_text: String = "GO TO WORK"
## The halftone photos this edition printed.
var photos: Array[NewsPhoto] = []
var _go: Button


func _ready() -> void:
	if paper.is_empty():
		paper = GameState.run.morning.get("paper", {})
	var bg := UiTheme.rect(Palette.BG_DARK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var column := centered_paper(WIDTH, Palette.NEWSPRINT, "drop")
	build_masthead(column, String(paper.get("date", "")))
	var text_width := WIDTH - 80
	var lead: Dictionary = paper.get("lead", {})
	var lead_text := column
	if lead.has("portrait_seed"):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		row.add_child(_photo(lead, LEAD_PHOTO_BLOCK))
		lead_text = VBoxContainer.new()
		lead_text.add_theme_constant_override("separation", 12)
		row.add_child(lead_text)
		column.add_child(row)
		text_width -= PortraitView.GRID_W * LEAD_PHOTO_BLOCK + 4 + 24
	lead_text.add_child(UiTheme.para(String(lead.get("headline", "")).to_upper(), text_width, UiTheme.SIZE_BIG, Palette.INK))
	lead_text.add_child(UiTheme.para(String(lead.get("sub", "")), text_width, UiTheme.SIZE_BODY, Palette.INK_FADED))
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))

	var items: Array = paper.get("items", [])
	var with_photos := false
	for item: Dictionary in items:
		with_photos = with_photos or item.has("portrait_seed")
	var grid := GridContainer.new()
	grid.columns = 3 if with_photos else clampi(items.size(), 1, 4)
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", 16)
	var item_width := (WIDTH - 80 - (grid.columns - 1) * GAP) / grid.columns
	for item: Dictionary in items:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		var width := item_width
		var cell: Control = box
		if item.has("portrait_seed"):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", PHOTO_GAP)
			row.add_child(_photo(item, PHOTO_BLOCK))
			row.add_child(box)
			width -= PortraitView.GRID_W * PHOTO_BLOCK + 4 + PHOTO_GAP
			cell = row
		box.add_child(UiTheme.para(String(item.get("headline", "")).to_upper(), width, UiTheme.SIZE_BODY, Palette.INK))
		box.add_child(UiTheme.para(String(item.get("body", "")), width, UiTheme.SIZE_SMALL, Palette.INK))
		grid.add_child(cell)
	column.add_child(grid)

	_go = UiTheme.button(continue_text, UiTheme.SIZE_BODY, 300)
	_go.pressed.connect(func() -> void: finish({}))
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.add_child(_go)
	column.add_child(holder)


func on_shown() -> void:
	_go.grab_focus()


## A printed photo in a thin rule, for a story with a face on file.
func _photo(story: Dictionary, block: int) -> Control:
	var photo := NewsPhoto.halftone(int(story["portrait_seed"]), int(story.get("age", 40)), block)
	photos.append(photo)
	return NewsPhoto.in_frame(photo, Palette.NEWSPRINT, Palette.INK_FADED, 2, 0)


static func build_masthead(column: VBoxContainer, date_text: String) -> void:
	var name_label := UiTheme.label("THE DAILY LEDGER", UiTheme.SIZE_HUGE, Palette.INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 4)))
	var strip := HBoxContainer.new()
	var left := UiTheme.label(date_text.to_upper(), UiTheme.SIZE_SMALL, Palette.INK)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(left)
	strip.add_child(UiTheme.label("ALL THE NEWS THAT'S FIT TO SETTLE", UiTheme.SIZE_SMALL, Palette.INK))
	var right := UiTheme.label("75 CENTS", UiTheme.SIZE_SMALL, Palette.INK)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	strip.add_child(right)
	column.add_child(strip)
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))
