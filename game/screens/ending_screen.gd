class_name EndingScreen
extends ScreenBase
## The last front page, an epilogue, and the week in numbers.

var page: Dictionary = {}
var _back: Button


func _ready() -> void:
	page = Endings.build(GameState.run, GameState.run.ending)
	var bg := UiTheme.rect(Palette.BG_DARK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var column := centered_paper(1400, Palette.NEWSPRINT)
	# Every ending is reported the morning after the last day worked.
	NewspaperScreen.build_masthead(column, DateUtil.fmt_long(DateUtil.game_date(clampi(GameState.run.day, 1, 7)) + 1))
	var paper: Dictionary = page["paper"]
	column.add_child(UiTheme.para(String(paper["headline"]).to_upper(), 1320, UiTheme.SIZE_BIG, Palette.INK))
	column.add_child(UiTheme.para(String(paper["sub"]), 1320, UiTheme.SIZE_BODY, Palette.INK_FADED))
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 48)
	column.add_child(body)
	var story := VBoxContainer.new()
	story.add_theme_constant_override("separation", 12)
	var title := UiTheme.label(page["title"], UiTheme.SIZE_BIG, Palette.RED_DARK if not page["survived"] else Palette.INK)
	story.add_child(title)
	for line: String in page["epilogue"]:
		story.add_child(UiTheme.para(line, 820, UiTheme.SIZE_BODY, Palette.INK))
	body.add_child(story)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 24)
	stats.add_theme_constant_override("v_separation", 6)
	for pair: Array in page["stats"]:
		stats.add_child(UiTheme.label(String(pair[0]).to_upper(), UiTheme.SIZE_SMALL, Palette.INK_FADED))
		stats.add_child(UiTheme.label(String(pair[1]), UiTheme.SIZE_BODY, Palette.INK))
	var stats_box := VBoxContainer.new()
	stats_box.add_child(UiTheme.label("THE WEEK IN NUMBERS", UiTheme.SIZE_BODY, Palette.INK))
	stats_box.add_child(stats)
	body.add_child(stats_box)

	_back = UiTheme.button("RETURN TO TITLE", UiTheme.SIZE_BODY, 320)
	_back.pressed.connect(func() -> void: finish({}))
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.add_child(_back)
	column.add_child(holder)


func on_shown() -> void:
	_back.grab_focus()
