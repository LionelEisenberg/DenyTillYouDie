class_name AgreementScreen
extends ScreenBase
## The employment agreement. The name signed here is the one on your own claim
## on day 7.

var name_edit: LineEdit


func _ready() -> void:
	var bg := UiTheme.rect(Palette.DESK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var column := centered_paper(1180)
	var title := UiTheme.label("BENEVOLENCE MUTUAL", UiTheme.SIZE_BIG, Palette.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var sub := UiTheme.label("EMPLOYMENT AGREEMENT  -  CLAIMS ADJUSTER #4471, DESK 11", UiTheme.SIZE_BODY, Palette.INK_FADED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	column.add_child(UiTheme.rect(Palette.PAPER_SHADE, Vector2(0, 2)))
	for paragraph in NewsPool.AGREEMENT:
		column.add_child(UiTheme.para(paragraph, 1100, UiTheme.SIZE_SMALL, Palette.INK))
	column.add_child(UiTheme.rect(Palette.PAPER_SHADE, Vector2(0, 2)))

	var sign_row := HBoxContainer.new()
	sign_row.add_theme_constant_override("separation", 16)
	sign_row.add_child(UiTheme.label("EMPLOYEE NAME", UiTheme.SIZE_BODY, Palette.INK))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Sign here"
	name_edit.max_length = 22
	name_edit.custom_minimum_size = Vector2(460, 0)
	name_edit.add_theme_font_size_override("font_size", UiTheme.SIZE_TITLE)
	name_edit.text_submitted.connect(func(_t: String) -> void: _sign())
	sign_row.add_child(name_edit)
	var date := UiTheme.label("DATE  %s" % DateUtil.fmt(DateUtil.game_date(1)), UiTheme.SIZE_BODY, Palette.INK_FADED)
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sign_row.add_child(date)
	column.add_child(sign_row)

	var sign := UiTheme.button("SIGN AND START WORK", UiTheme.SIZE_BODY, 360)
	sign.pressed.connect(_sign)
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.add_child(sign)
	column.add_child(holder)
	column.add_child(UiTheme.label("*Terms, conditions and exclusions apply.", UiTheme.SIZE_SMALL, Palette.INK_FADED))
	name_edit.call_deferred("grab_focus")


func _sign() -> void:
	Sfx.play("stamp")
	finish({"name": name_edit.text})
