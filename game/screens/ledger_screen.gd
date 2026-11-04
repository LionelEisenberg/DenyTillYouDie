class_name LedgerScreen
extends ScreenBase
## The night: today's pay, the bills, and the family. Rent is mandatory; food,
## heat, medicine, prescriptions and the night's household event are choices.
## Shows whatever bills close_shift() returns, and each family row says what
## tonight's choices will do to them (NightLogic.forecast), live as boxes toggle.
##
## Outside fast mode (and reduce motion) the sheet prints like an adding machine
## from the moment it enters the tree; a click or key finishes the printout at
## once. Fullscreen, mute and the menu keys keep their own jobs meanwhile.

const WIDTH := 1400.0
const COLUMN_W := 620.0
const NAME_W := 200.0
const ADDRESS := "HOUSEHOLD LEDGER - UNIT 4B, 1120 CALLOWAY ST."
const RENT_REMINDER := "Rent is due again tomorrow night."
## Seconds between printed lines, and for the Available total to roll up.
const LINE_TIME := 0.12
const CARBON_TIME := 0.05
const FAMILY_TIME := 0.25
const NOTE_TIME := 0.3
const COUNT_TIME := 0.45

## Hungry, cold or missing a prescription: between amber and red ink.
static var warn_ink: Color = Palette.AMBER.lerp(Palette.RED_DARK, 0.5).darkened(0.15)
## Fine print (bill notes, the rent reminder): fainter than the bills, but dark
## enough to read at 16 px when the window scales the sheet down.
static var note_ink: Color = Palette.INK_FADED.lerp(Palette.INK, 0.5)

## Tonight's ledger. Defaults to GameState.close_shift(); tests may set it first.
var ledger: Dictionary = {}
var _toggles: Dictionary = {}
var _remaining_label: Label
var _sleep: Button
var _available_amount: Label
var _expenses: VBoxContainer
## One per family member: {status: Label, note: Label}.
var _family_rows: Array[Dictionary] = []
var _tonight_labels: Array[Label] = []
var _tonight_box: VBoxContainer
## The printout, in order: {node: Control, wait: float, sound: String, count: bool}.
var _steps: Array[Dictionary] = []
var _revealing := false
var _reveal_started := false
var _reveal_tween: Tween


func _ready() -> void:
	if ledger.is_empty():
		ledger = GameState.close_shift()
	var bg := UiTheme.rect(Palette.BG_DARK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var column := centered_paper(WIDTH)
	var date := DateUtil.game_date(int(ledger["day"]))
	column.add_child(UiTheme.label(ADDRESS, UiTheme.SIZE_BIG, Palette.INK))
	column.add_child(UiTheme.label("Night of %s %s" % [DateUtil.weekday(date), DateUtil.fmt(date)], UiTheme.SIZE_BODY, Palette.INK_FADED))
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 60)
	column.add_child(columns)
	columns.add_child(_income_column())
	_expenses = _expense_column()
	columns.add_child(_expenses)

	var event: Dictionary = ledger.get("event", {})
	if not event.is_empty():
		_print(column, UiTheme.para(String(event["text"]), WIDTH - 80, UiTheme.SIZE_BODY, Palette.INK), NOTE_TIME)
	for note: String in ledger["notes"]:
		_print(column, UiTheme.para(note, WIDTH - 80, UiTheme.SIZE_BODY, Palette.RED_DARK), NOTE_TIME)
	if ledger["evicted"]:
		_print(column, UiTheme.label("YOU CANNOT MAKE RENT.", UiTheme.SIZE_BIG, Palette.RED_DARK), NOTE_TIME)
	# The line from home prints last of all, after the notes.
	_steps.append(_steps.pop_at(_home_step_index()))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_sleep = UiTheme.button("CONTINUE" if ledger["evicted"] else "SLEEP", UiTheme.SIZE_BODY, 280)
	# It plays the lamp switching off instead of the usual clack.
	_sleep.set_meta("silent", true)
	_sleep.pressed.connect(_on_sleep)
	row.add_child(_sleep)
	_print(column, row, LINE_TIME)

	_sync_requirements()
	_refresh()
	# Measured at the end of this frame, once every label has its theme.
	_hold_expense_height.call_deferred()
	if not _prints_at_once():
		for step in _steps:
			(step["node"] as Control).modulate.a = 0.0
		# Starts at once, so the sheet never waits on whoever shows it.
		_start_reveal()


func on_shown() -> void:
	_sleep.grab_focus()


## Fast mode and reduce motion put the whole sheet down at once, silently.
func _prints_at_once() -> bool:
	return fast or bool(Engine.get_meta("reduce_motion", false))


## Whether the printout is still running.
func revealing() -> bool:
	return _revealing


## How many of the printout's lines are on the sheet so far.
func printed_rows() -> int:
	var printed := 0
	for step in _steps:
		if (step["node"] as Control).modulate.a > 0.5:
			printed += 1
	return printed


## Prints every remaining line at once.
func finish_reveal() -> void:
	if _reveal_tween:
		_reveal_tween.kill()
		_reveal_tween = null
	for step in _steps:
		(step["node"] as Control).modulate.a = 1.0
	_available_amount.text = UiTheme.money(int(ledger["available"]))
	_revealing = false


func paid_choices() -> Dictionary:
	var paid := {"food": false, "heat": false, "medicine": {}}
	var extras := {}
	for id: String in _toggles:
		var on: bool = (_toggles[id] as Button).button_pressed
		if id == "food" or id == "heat":
			paid[id] = on
		elif id.begins_with("medicine:"):
			paid["medicine"][id.get_slice(":", 1)] = on
		elif id != "rent":
			extras[id] = on
	# Prescriptions and household events, only on nights that list one.
	if not extras.is_empty():
		paid["extras"] = extras
	return paid


func _on_sleep() -> void:
	if _revealing:
		# SLEEP works once it is printed; until then a press only finishes the printout.
		finish_reveal()
		return
	_sleep.disabled = true
	Sfx.play("lamp_click")
	var ending := GameState.apply_ledger(paid_choices())
	finish({"ending": ending})


func _input(event: InputEvent) -> void:
	if not _revealing:
		return
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo or _passes_through(key):
			return
	elif not (event is InputEventMouseButton and event.is_pressed()):
		return
	finish_reveal()
	get_viewport().set_input_as_handled()


## Keys the printout leaves alone, so they reach whoever handles them: F11
## (fullscreen), M (mute) and Esc (the menu).
static func _passes_through(key: InputEventKey) -> bool:
	if key.is_action("fullscreen_toggle"):
		return true
	for code: int in [KEY_F11, KEY_M, KEY_ESCAPE]:
		if key.keycode == code or key.physical_keycode == code:
			return true
	return false


# --- printout ---------------------------------------------------------------

## Adds `node` to `parent` as the printout's next line.
func _print(parent: Node, node: Control, wait: float, sound: String = "") -> Control:
	parent.add_child(node)
	_steps.append({"node": node, "wait": wait, "sound": sound, "count": false})
	return node


func _home_step_index() -> int:
	for i in _steps.size():
		if (_steps[i]["node"] as Control).has_meta("home_line"):
			return i
	return _steps.size() - 1


func _start_reveal() -> void:
	if _reveal_started or _prints_at_once():
		return
	_reveal_started = true
	_revealing = true
	_reveal_tween = create_tween()
	for step in _steps:
		_reveal_tween.tween_interval(float(step["wait"]))
		_reveal_tween.tween_callback(_print_step.bind(step))
		if step["count"]:
			_reveal_tween.tween_method(_roll_available, float(ledger["savings_before"]), float(ledger["available"]), COUNT_TIME)
	_reveal_tween.tween_callback(finish_reveal)


func _print_step(step: Dictionary) -> void:
	(step["node"] as Control).modulate.a = 1.0
	if step["count"]:
		_roll_available(float(ledger["savings_before"]))
	if String(step["sound"]) != "":
		Sfx.play(step["sound"])


func _roll_available(value: float) -> void:
	_available_amount.text = UiTheme.money(roundi(value))


# --- columns ----------------------------------------------------------------

func _income_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(COLUMN_W, 0)
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiTheme.label("INCOME", UiTheme.SIZE_TITLE, Palette.INK))
	_print(col, _money_row("Savings (this morning)", int(ledger["savings_before"]), Palette.INK), LINE_TIME, "ratchet")
	for line: Dictionary in ledger["income"]:
		var amount: int = line["amount"]
		_print(col, _money_row(line["label"], amount, Palette.INK if amount >= 0 else Palette.RED_DARK), LINE_TIME, "ratchet")
	col.add_child(UiTheme.rect(Palette.INK_FADED, Vector2(0, 2)))
	var available := _money_row("Available", int(ledger["available"]), Palette.INK, UiTheme.SIZE_TITLE)
	_available_amount = available.get_child(1)
	_print(col, available, LINE_TIME, "ratchet")
	_steps[_steps.size() - 1]["count"] = true
	col.add_child(_carbon_copies())
	return col


## One carbon per patient, like the slips in the desk's tray: who, the ruling,
## the claim and what it paid you. Who died is left to the morning paper.
func _carbon_copies() -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.flat_box(Palette.PAPER_ALT, Palette.PAPER_SHADE, 1, 10, 6))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	box.add_child(lines)
	lines.add_child(UiTheme.label("CARBON COPIES", UiTheme.SIZE_SMALL, Palette.INK_FADED))
	for text: String in ledger.get("carbons", PackedStringArray()):
		_print(lines, UiTheme.label(text, UiTheme.SIZE_SMALL, Palette.INK_BLUE), CARBON_TIME)
	if String(ledger.get("carbon_total", "")) != "":
		_print(lines, UiTheme.label(String(ledger["carbon_total"]), UiTheme.SIZE_SMALL, Palette.INK), CARBON_TIME)
	return UiTheme.margin(box, 0, 10, 0, 0)


func _expense_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(COLUMN_W, 0)
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiTheme.label("EXPENSES", UiTheme.SIZE_TITLE, Palette.INK))
	for bill: Dictionary in ledger["bills"]:
		_print(col, _bill_row(bill), LINE_TIME, "ratchet")
	col.add_child(UiTheme.rect(Palette.INK_FADED, Vector2(0, 2)))
	var after := VBoxContainer.new()
	after.add_theme_constant_override("separation", 0)
	_remaining_label = UiTheme.label("", UiTheme.SIZE_TITLE, Palette.INK)
	after.add_child(_remaining_label)
	# Night 6 is the last: day 7 ends with your own claim, not another night.
	if not ledger["evicted"] and int(ledger["day"]) < NightLogic.LAST_NIGHT:
		after.add_child(UiTheme.label(RENT_REMINDER, UiTheme.SIZE_SMALL, note_ink))
	_print(col, after, LINE_TIME, "ratchet")
	col.add_child(UiTheme.rect(Color(0, 0, 0, 0), Vector2(0, 4)))
	col.add_child(UiTheme.label("FAMILY", UiTheme.SIZE_TITLE, Palette.INK))
	for m: Dictionary in ledger["family"]:
		_print(col, _family_row(m), FAMILY_TIME)
	_tonight_box = VBoxContainer.new()
	_tonight_box.add_theme_constant_override("separation", 0)
	for i in 2:
		var l := UiTheme.label("", UiTheme.SIZE_SMALL, Palette.RED_DARK)
		_tonight_labels.append(l)
		_tonight_box.add_child(l)
	_print(col, _tonight_box, FAMILY_TIME)
	var home := UiTheme.para(String(ledger.get("home_line", "")), COLUMN_W, UiTheme.SIZE_BODY, Palette.INK_BLUE)
	home.set_meta("home_line", true)
	_print(col, home, NOTE_TIME)
	return col


func _bill_row(bill: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var evicted: bool = ledger["evicted"]
	var toggle := Button.new()
	toggle.toggle_mode = true
	# Without rent money nothing gets paid tonight, so nothing shows as paid.
	toggle.button_pressed = bill["default_on"] and not evicted
	toggle.disabled = bill["mandatory"] or evicted
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.add_theme_font_size_override("font_size", UiTheme.SIZE_BODY)
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		toggle.add_theme_stylebox_override(state, UiTheme.flat_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 2))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		toggle.add_theme_color_override(color_name, Palette.INK)
	# Rows the player can't change are printed faded, so they don't read as clickable.
	toggle.add_theme_color_override("font_disabled_color", Palette.INK_FADED)
	# The toggle clicks or buzzes itself.
	toggle.set_meta("silent", true)
	toggle.set_meta("bill", bill)
	toggle.toggled.connect(_on_toggled.bind(toggle))
	_label_toggle(toggle)
	_toggles[bill["id"]] = toggle
	row.add_child(toggle)
	var note := UiTheme.label(String(bill.get("note", "")), UiTheme.SIZE_SMALL, note_ink)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.set_meta("note", note)
	row.add_child(note)
	return row


func _family_row(m: Dictionary) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	var who := UiTheme.label("%s (%s)" % [m["name"], m["role"]], UiTheme.SIZE_BODY, Palette.INK)
	who.custom_minimum_size = Vector2(NAME_W, 0)
	row.add_child(who)
	var status := UiTheme.label("", UiTheme.SIZE_BODY, Palette.INK)
	row.add_child(status)
	block.add_child(row)
	var note := UiTheme.label("", UiTheme.SIZE_SMALL, Palette.INK_FADED)
	var holder := UiTheme.margin(note, int(NAME_W), 0, 0, 0)
	block.add_child(holder)
	_family_rows.append({"status": status, "note": note, "holder": holder})
	return block


# --- choices ----------------------------------------------------------------

func _on_toggled(on: bool, toggle: Button) -> void:
	if on and _remaining() < 0:
		toggle.set_pressed_no_signal(false)
		Sfx.play("buzz")
	else:
		Sfx.play("click")
	_sync_requirements()
	_label_toggle(toggle)
	_refresh()


## A bill that needs another (heat needs tonight's furnace repair) is unticked
## and locked while that one is unticked.
func _sync_requirements() -> void:
	for id: String in _toggles:
		var toggle: Button = _toggles[id]
		var bill: Dictionary = toggle.get_meta("bill")
		var requires: String = bill.get("requires", "")
		if requires == "" or not _toggles.has(requires):
			continue
		var needed: Button = _toggles[requires]
		var works := needed.button_pressed
		if not works and toggle.button_pressed:
			toggle.set_pressed_no_signal(false)
		toggle.disabled = not works or bool(ledger["evicted"])
		var note: Label = toggle.get_meta("note")
		var needed_bill: Dictionary = needed.get_meta("bill")
		note.text = String(bill.get("note", "")) if works else "(needs the %s)" % String(needed_bill["label"]).to_lower()
		_label_toggle(toggle)


func _label_toggle(toggle: Button) -> void:
	var bill: Dictionary = toggle.get_meta("bill")
	var text := "[%s]  %s  %s" % ["X" if toggle.button_pressed else " ", bill["label"], UiTheme.money(int(bill["amount"]))]
	if ledger["evicted"]:
		text += " (unpaid)"
	toggle.text = text


func _remaining() -> int:
	var left: int = ledger["available"]
	for id: String in _toggles:
		var toggle: Button = _toggles[id]
		if toggle.button_pressed:
			left -= int((toggle.get_meta("bill") as Dictionary)["amount"])
	return left


## Savings after bills, and what tonight's choices do to the family.
func _refresh() -> void:
	var left := _remaining()
	_remaining_label.text = "Savings after bills: %s" % UiTheme.money(left)
	_remaining_label.add_theme_color_override("font_color", Palette.INK if left >= 0 else Palette.RED_DARK)
	var rows: Array[Dictionary] = []
	var tonight := PackedStringArray()
	if ledger["evicted"] or GameState.run == null:
		# Nobody gets paid tonight: show where the family stands, no forecast.
		for m: Dictionary in ledger["family"]:
			rows.append({"status": String(m["status"]).to_upper(), "note": "", "urgent": false})
	else:
		var paid := paid_choices()
		rows = NightLogic.forecast(GameState.run, paid, ledger)
		tonight = NightLogic.tonight_lines(GameState.run, paid, ledger)
	for i in mini(rows.size(), _family_rows.size()):
		var row: Dictionary = rows[i]
		var status: Label = _family_rows[i]["status"]
		var note: Label = _family_rows[i]["note"]
		status.text = row["status"]
		status.add_theme_color_override("font_color", _status_color(row["status"]))
		note.text = row["note"]
		# Full ink, not the bills' faded fine print: these say what the night does.
		note.add_theme_color_override("font_color", Palette.RED_DARK if row["urgent"] else Palette.INK)
		# A blank note takes no room; the column keeps its height (see below).
		(_family_rows[i]["holder"] as Control).visible = note.text != ""
		_family_step(i)["sound"] = "" if row["status"] == NightLogic.HEALTHY else "tone_low"
	var any_tonight := false
	for i in _tonight_labels.size():
		var line: String = tonight[i] if i < tonight.size() else ""
		_tonight_labels[i].text = line
		_tonight_labels[i].visible = line != ""
		any_tonight = any_tonight or line != ""
	_tonight_box.visible = any_tonight


## The family notes and the "Tonight:" lines come and go as boxes are ticked.
## The expense column keeps the height they need at most, so a tick never
## changes the sheet's height and the centered sheet never moves under the
## pointer; blank lines leave their room at the bottom of the column instead
## of between the rows.
func _hold_expense_height() -> void:
	if not is_instance_valid(_expenses):
		return
	for row in _family_rows:
		(row["holder"] as Control).visible = true
	for l in _tonight_labels:
		l.visible = true
	_tonight_box.visible = true
	_expenses.custom_minimum_size.y = 0.0
	_expenses.custom_minimum_size.y = _expenses.get_combined_minimum_size().y
	_refresh()


## The printout step of family row `i`.
func _family_step(i: int) -> Dictionary:
	var block: Control = (_family_rows[i]["status"] as Label).get_parent().get_parent()
	for step in _steps:
		if step["node"] == block:
			return step
	return {}


func _status_color(status: String) -> Color:
	if status == NightLogic.HEALTHY:
		return Palette.GREEN_DARK
	if status == NightLogic.DEAD:
		return Palette.INK_FADED
	if status == NightLogic.SICK:
		return Palette.RED_DARK
	return warn_ink


func _money_row(text: String, amount: int, color: Color, size: int = UiTheme.SIZE_BODY) -> Control:
	var row := HBoxContainer.new()
	var l := UiTheme.label(text, size, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var r := UiTheme.label(UiTheme.money(amount), size, color)
	row.add_child(r)
	return row
