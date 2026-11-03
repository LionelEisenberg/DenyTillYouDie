class_name NewspaperScreen
extends ScreenBase
## The morning paper: one lead story and a row of smaller items.

const WIDTH := 1500.0

## Set by the caller; defaults to this morning's paper.
var paper: Dictionary = {}
var continue_text: String = "GO TO WORK"


func _ready() -> void:
	if paper.is_empty():
		paper = GameState.run.morning.get("paper", {})
	var bg := UiTheme.rect(Palette.BG_DARK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var column := centered_paper(WIDTH, Palette.NEWSPRINT)
	build_masthead(column, String(paper.get("date", "")))
	var lead: Dictionary = paper.get("lead", {})
	column.add_child(UiTheme.para(String(lead.get("headline", "")).to_upper(), WIDTH - 80, UiTheme.SIZE_BIG, Palette.INK))
	column.add_child(UiTheme.para(String(lead.get("sub", "")), WIDTH - 80, UiTheme.SIZE_BODY, Palette.INK_FADED))
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))

	var items: Array = paper.get("items", [])
	var grid := GridContainer.new()
	grid.columns = clampi(items.size(), 1, 4)
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 16)
	var item_width := (WIDTH - 80 - (grid.columns - 1) * 32) / grid.columns
	for item: Dictionary in items:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.add_child(UiTheme.para(String(item.get("headline", "")).to_upper(), item_width, UiTheme.SIZE_BODY, Palette.INK))
		box.add_child(UiTheme.para(String(item.get("body", "")), item_width, UiTheme.SIZE_SMALL, Palette.INK))
		grid.add_child(box)
	column.add_child(grid)

	var go := UiTheme.button(continue_text, UiTheme.SIZE_BODY, 300)
	go.pressed.connect(func() -> void: finish({}))
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.add_child(go)
	column.add_child(holder)
	go.call_deferred("grab_focus")


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
