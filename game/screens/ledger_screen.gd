class_name LedgerScreen
extends ScreenBase
## The night: today's pay, the bills, and the family. Rent is mandatory; food,
## heat and medicine are choices.

var ledger: Dictionary = {}
var _toggles: Dictionary = {}
var _remaining_label: Label
var _sleep: Button


func _ready() -> void:
	ledger = GameState.close_shift()
	var bg := UiTheme.rect(Palette.BG_DARK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var column := centered_paper(1400)
	var date := DateUtil.game_date(int(ledger["day"]))
	column.add_child(UiTheme.label("HOUSEHOLD LEDGER", UiTheme.SIZE_BIG, Palette.INK))
	column.add_child(UiTheme.label("Night of %s %s" % [DateUtil.weekday(date), DateUtil.fmt(date)], UiTheme.SIZE_BODY, Palette.INK_FADED))
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 60)
	column.add_child(columns)
	columns.add_child(_income_column())
	columns.add_child(_expense_column())

	for note: String in ledger["notes"]:
		column.add_child(UiTheme.para(note, 1320, UiTheme.SIZE_BODY, Palette.RED_DARK))
	if ledger["evicted"]:
		column.add_child(UiTheme.label("YOU CANNOT MAKE RENT.", UiTheme.SIZE_BIG, Palette.RED_DARK))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_sleep = UiTheme.button("CONTINUE" if ledger["evicted"] else "SLEEP", UiTheme.SIZE_BODY, 280)
	_sleep.pressed.connect(_on_sleep)
	row.add_child(_sleep)
	column.add_child(row)
	_update_remaining()
	_sleep.call_deferred("grab_focus")


func paid_choices() -> Dictionary:
	var paid := {"food": false, "heat": false, "medicine": {}}
	for id: String in _toggles:
		var on: bool = (_toggles[id] as Button).button_pressed
		if id == "food" or id == "heat":
			paid[id] = on
		elif id.begins_with("medicine:"):
			paid["medicine"][id.get_slice(":", 1)] = on
	return paid


func _on_sleep() -> void:
	_sleep.disabled = true
	var ending := GameState.apply_ledger(paid_choices())
	finish({"ending": ending})


func _income_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiTheme.label("INCOME", UiTheme.SIZE_TITLE, Palette.INK))
	col.add_child(_money_row("Savings", int(ledger["savings_before"]), Palette.INK))
	for line: Dictionary in ledger["income"]:
		var amount: int = line["amount"]
		col.add_child(_money_row(line["label"], amount, Palette.INK if amount >= 0 else Palette.RED_DARK))
	col.add_child(UiTheme.rect(Palette.INK_FADED, Vector2(0, 2)))
	col.add_child(_money_row("Available", int(ledger["available"]), Palette.INK, UiTheme.SIZE_TITLE))
	for rec: Dictionary in ledger["overturned"]:
		col.add_child(UiTheme.para("Appeal lost: %s's claim was paid after review." % rec["name"], 600, UiTheme.SIZE_SMALL, Palette.INK_FADED))
	return col


func _expense_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiTheme.label("EXPENSES", UiTheme.SIZE_TITLE, Palette.INK))
	for bill: Dictionary in ledger["bills"]:
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.button_pressed = bill["default_on"]
		toggle.disabled = bill["mandatory"] or ledger["evicted"]
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		toggle.add_theme_font_size_override("font_size", UiTheme.SIZE_BODY)
		for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			toggle.add_theme_stylebox_override(state, UiTheme.flat_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 2))
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
			toggle.add_theme_color_override(color_name, Palette.INK)
		toggle.set_meta("bill", bill)
		toggle.toggled.connect(_on_toggled.bind(toggle))
		_label_toggle(toggle)
		_toggles[bill["id"]] = toggle
		col.add_child(toggle)
	col.add_child(UiTheme.rect(Palette.INK_FADED, Vector2(0, 2)))
	_remaining_label = UiTheme.label("", UiTheme.SIZE_TITLE, Palette.INK)
	col.add_child(_remaining_label)
	col.add_child(UiTheme.rect(Color(0, 0, 0, 0), Vector2(0, 12)))
	col.add_child(UiTheme.label("FAMILY", UiTheme.SIZE_TITLE, Palette.INK))
	for m: Dictionary in ledger["family"]:
		var status: String = m["status"]
		var color := Palette.GREEN_DARK
		if status == "Dead":
			color = Palette.INK_FADED
		elif status == "Sick":
			color = Palette.RED_DARK
		elif status != "Healthy":
			color = Color("8a5a1c")
		var row := HBoxContainer.new()
		var who := UiTheme.label("%s (%s)" % [m["name"], m["role"]], UiTheme.SIZE_BODY, Palette.INK)
		who.custom_minimum_size = Vector2(320, 0)
		row.add_child(who)
		row.add_child(UiTheme.label(status.to_upper(), UiTheme.SIZE_BODY, color))
		col.add_child(row)
	return col


func _on_toggled(on: bool, toggle: Button) -> void:
	if on and _remaining() < 0:
		toggle.set_pressed_no_signal(false)
		Sfx.play("buzz")
	else:
		Sfx.play("click")
	_label_toggle(toggle)
	_update_remaining()


func _label_toggle(toggle: Button) -> void:
	var bill: Dictionary = toggle.get_meta("bill")
	toggle.text = "[%s]  %s  %s" % ["X" if toggle.button_pressed else " ", bill["label"], UiTheme.money(int(bill["amount"]))]


func _remaining() -> int:
	var left: int = ledger["available"]
	for id: String in _toggles:
		var toggle: Button = _toggles[id]
		if toggle.button_pressed:
			left -= int((toggle.get_meta("bill") as Dictionary)["amount"])
	return left


func _update_remaining() -> void:
	var left := _remaining()
	_remaining_label.text = "Savings after bills: %s" % UiTheme.money(left)
	_remaining_label.add_theme_color_override("font_color", Palette.INK if left >= 0 else Palette.RED_DARK)


func _money_row(text: String, amount: int, color: Color, size: int = UiTheme.SIZE_BODY) -> Control:
	var row := HBoxContainer.new()
	var l := UiTheme.label(text, size, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var r := UiTheme.label(UiTheme.money(amount), size, color)
	row.add_child(r)
	return row
