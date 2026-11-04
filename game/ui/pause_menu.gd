class_name PauseMenu
extends CanvasLayer
## The Esc menu: a sheet of company paper over the dimmed game, with sound,
## display and motion settings, a quick reference card and the ways out. The
## Settings autoload owns it and applies whatever it asks for; the tree is
## paused while it is open. It keeps no copy of the settings: refresh() only
## redraws them, and the display switch asks Settings to flip its own value.

signal closed
signal volume_changed(value: float)
signal mute_toggled(on: bool)
## DISPLAY or F11: Settings flips full screen from the value it holds.
signal display_toggle_requested
signal motion_toggled(on: bool)
signal quit_to_title_confirmed
signal quit_game_confirmed

const WIDTH := 760.0
const LABEL_W := 260.0
const WARNING := "Your week is saved each morning. Leaving now loses today's shift."
## The quick reference card's two tables share their first column's width.
const CONTROLS: Array = [
	["Mouse", "Drag papers. Click buttons."],
	["NEXT!, Enter or N", "Call the next patient."],
	["INSPECT or Space", "Cite: click a rule, then the field that breaks it."],
	["Esc", "Leave inspect mode. Open this menu."],
	["Tab", "Turn the manual's pages."],
	["APPROVE / DENY", "Stamp the claim. Every stamp is final."],
	["M", "Mute."],
	["F11", "Full screen."],
]

var resume_button: Button
var volume_slider: HSlider
var volume_label: Label
var mute_button: Button
var display_button: Button
var motion_button: Button
var how_button: Button
var title_button: Button
var quit_button: Button
var confirm_button: Button
var cancel_button: Button
var back_button: Button
## The confirm page's heading: what CONFIRM will do.
var confirm_title: Label
var warning_label: Label
## "main", "how" or "confirm".
var page: String = "main"

var _pages: Dictionary = {}
## What CONFIRM does: "title" or "quit". Starts (and reopens) as the safe one.
var _confirm_action := "title"
var _warn := false
var _open := false
var _was_paused := false
var _prev_focus: Control


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var root := Control.new()
	root.theme = UiTheme.build()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := UiTheme.rect(Color(0, 0, 0, 0.6))
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiTheme.paper_box(Palette.PAPER, Palette.PAPER_SHADE, 32))
	sheet.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(sheet)
	var stack := VBoxContainer.new()
	sheet.add_child(stack)
	_pages["main"] = _main_page()
	_pages["how"] = _how_page()
	_pages["confirm"] = _confirm_page()
	for p: Control in _pages.values():
		stack.add_child(p)
	show_page("main")


func is_open() -> bool:
	return _open


## Opens on the main page, pauses the tree and focuses RESUME. QUIT TO TITLE is
## left out on the title itself; `warn` adds the lost-shift warning to the quit
## confirmations.
func open(show_title_quit: bool = true, warn: bool = false) -> void:
	if _open:
		return
	_open = true
	_warn = warn
	_confirm_action = "title"
	title_button.visible = show_title_quit
	_prev_focus = get_viewport().gui_get_focus_owner()
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	show_page("main")


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = _was_paused
	if is_instance_valid(_prev_focus) and _prev_focus.is_visible_in_tree():
		_prev_focus.grab_focus()
	_prev_focus = null
	closed.emit()


## Esc: from a sub-page back to the main page; from the main page, close.
func back() -> void:
	if page != "main":
		show_page("main")
	else:
		close()


## "main", "how" or "confirm". The confirm page always names what CONFIRM will
## do: QUIT TO TITLE unless QUIT GAME asked.
func show_page(page_name: String) -> void:
	page = page_name
	if page_name == "confirm":
		confirm_title.text = "QUIT TO TITLE?" if _confirm_action == "title" else "QUIT THE GAME?"
		warning_label.visible = _warn
	for key: String in _pages:
		(_pages[key] as Control).visible = key == page_name
	if not _open:
		return
	match page_name:
		"main":
			resume_button.grab_focus()
		"how":
			back_button.grab_focus()
		"confirm":
			cancel_button.grab_focus()


## Shows the current values without sending any of them back out.
func refresh(volume: float, muted: bool, fullscreen: bool, reduce_motion: bool) -> void:
	volume_slider.set_value_no_signal(roundf(volume * 100.0))
	volume_label.text = "%d%%" % roundi(volume * 100.0)
	mute_button.set_pressed_no_signal(muted)
	mute_button.text = "MUTED" if muted else "MUTE"
	display_button.text = "FULLSCREEN" if fullscreen else "WINDOWED"
	motion_button.set_pressed_no_signal(reduce_motion)
	motion_button.text = "ON" if reduce_motion else "OFF"


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fullscreen_toggle"):
		# main.gd's F11 is paused along with the game while the menu is open.
		display_toggle_requested.emit()
		get_viewport().set_input_as_handled()


# --- pages ----------------------------------------------------------------------

func _main_page() -> VBoxContainer:
	var col := _column()
	col.add_child(UiTheme.label("ON BREAK", UiTheme.SIZE_BIG, Palette.INK))
	col.add_child(UiTheme.label("BENEVOLENCE MUTUAL  -  EMPLOYEE SETTINGS", UiTheme.SIZE_SMALL, Palette.INK_FADED))
	col.add_child(_rule())
	resume_button = _wide_button("RESUME")
	resume_button.pressed.connect(close)
	col.add_child(resume_button)
	col.add_child(_rule())

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.custom_minimum_size = Vector2(220, 32)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_slider(volume_slider)
	volume_slider.value_changed.connect(func(v: float) -> void:
		volume_label.text = "%d%%" % roundi(v)
		volume_changed.emit(v / 100.0))
	volume_label = UiTheme.label("", UiTheme.SIZE_BODY, Palette.INK)
	volume_label.custom_minimum_size = Vector2(64, 0)
	mute_button = UiTheme.button("MUTE", UiTheme.SIZE_BODY, 130)
	mute_button.toggle_mode = true
	mute_button.toggled.connect(func(on: bool) -> void:
		mute_button.text = "MUTED" if on else "MUTE"
		mute_toggled.emit(on))
	col.add_child(_row("SOUND", [volume_slider, volume_label, mute_button]))

	display_button = UiTheme.button("FULLSCREEN", UiTheme.SIZE_BODY, 220)
	display_button.pressed.connect(display_toggle_requested.emit)
	col.add_child(_row("DISPLAY", [display_button]))

	motion_button = UiTheme.button("OFF", UiTheme.SIZE_BODY, 220)
	motion_button.toggle_mode = true
	motion_button.toggled.connect(func(on: bool) -> void:
		motion_button.text = "ON" if on else "OFF"
		motion_toggled.emit(on))
	col.add_child(_row("REDUCE MOTION", [motion_button]))
	col.add_child(_rule())

	how_button = _wide_button("HOW TO PLAY")
	how_button.pressed.connect(show_page.bind("how"))
	col.add_child(how_button)
	title_button = _wide_button("QUIT TO TITLE")
	title_button.pressed.connect(_ask.bind("title"))
	col.add_child(title_button)
	quit_button = _wide_button("QUIT GAME")
	quit_button.pressed.connect(_ask.bind("quit"))
	col.add_child(quit_button)
	col.add_child(UiTheme.label("Esc returns to work.", UiTheme.SIZE_SMALL, Palette.INK_FADED))
	return col


## The quick reference card: controls and the basics of citing, denying and
## approving, with every number read from Economy.
func _how_page() -> VBoxContainer:
	var col := _column()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.flat_box(Palette.CARD, Palette.CARD_BAND, 2, 0, 0))
	col.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", UiTheme.flat_box(Palette.CARD_BAND, Palette.CARD_BAND, 0, 16, 6))
	var band_row := HBoxContainer.new()
	var left := UiTheme.label("BENEVOLENCE MUTUAL", UiTheme.SIZE_BODY, Palette.CARD)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band_row.add_child(left)
	band_row.add_child(UiTheme.label("QUICK REFERENCE", UiTheme.SIZE_BODY, Palette.CARD))
	band.add_child(band_row)
	inner.add_child(band)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	inner.add_child(UiTheme.margin(body, 16, 6, 16, 14))

	# Both tables start their second column at the same x: the first column is
	# as wide as the widest key or term in either.
	var key_w := 0.0
	for pair: Array in CONTROLS + _basics():
		key_w = maxf(key_w, UiTheme.font().get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BODY).x)
	key_w = ceilf(key_w)
	body.add_child(UiTheme.label("CONTROLS", UiTheme.SIZE_SMALL, Palette.INK_FADED))
	body.add_child(_card_table(CONTROLS, key_w, 2, false))
	body.add_child(UiTheme.rect(Color(0, 0, 0, 0), Vector2(0, 8)))
	body.add_child(UiTheme.label("THE BASICS", UiTheme.SIZE_SMALL, Palette.INK_FADED))
	body.add_child(_card_table(_basics(), key_w, 8, true))
	body.add_child(UiTheme.rect(Color(0, 0, 0, 0), Vector2(0, 6)))
	body.add_child(UiTheme.label("Keep this card at your desk. Do not show it to members.", UiTheme.SIZE_SMALL, Palette.INK_FADED))
	back_button = _wide_button("BACK")
	back_button.pressed.connect(show_page.bind("main"))
	col.add_child(back_button)
	return col


## Two columns: the key or term at `key_w`, then what it means (wrapped when
## `wrap`, for the longer basics).
func _card_table(rows: Array, key_w: float, v_gap: int, wrap: bool) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", v_gap)
	for pair: Array in rows:
		var key := UiTheme.label(pair[0], UiTheme.SIZE_BODY, Palette.INK)
		key.custom_minimum_size = Vector2(key_w, 0)
		grid.add_child(key)
		grid.add_child(UiTheme.para(pair[1], 560, UiTheme.SIZE_BODY, Palette.INK) if wrap else UiTheme.label(pair[1], UiTheme.SIZE_BODY, Palette.INK))
	return grid


static func _basics() -> Array:
	return [
		["CITED DENIAL", "Full commission."],
		["UNCITED DENIAL", "Half commission. If the claim was clean, the member may win on appeal: %s legal fee." % Fmt.money(Economy.LEGAL_FEE)],
		["EMPTY CITATION", "A citation that finds nothing costs a %s compliance fee." % Fmt.money(Economy.COMPLIANCE_FEE)],
		["APPROVAL", "Comes out of your pay. Approving a claim with grounds for denial earns a citation: %s a day, then %s fines." % [Fmt.plural(Economy.FREE_WARNINGS, "warning"), Fmt.money(Economy.CITATION_FINE)]],
		["DISCONTENT", "Denials raise it. Approvals lower it. At %d%%, the Company lets you go." % roundi(Economy.SCAPEGOAT_AT)],
	]


func _confirm_page() -> VBoxContainer:
	var col := _column()
	confirm_title = UiTheme.label("", UiTheme.SIZE_TITLE, Palette.INK)
	col.add_child(confirm_title)
	warning_label = UiTheme.para(WARNING, WIDTH - 64, UiTheme.SIZE_BODY, Palette.RED_DARK)
	col.add_child(warning_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	confirm_button = UiTheme.button("CONFIRM", UiTheme.SIZE_BODY, 220)
	confirm_button.pressed.connect(_confirm)
	cancel_button = UiTheme.button("CANCEL", UiTheme.SIZE_BODY, 220)
	cancel_button.pressed.connect(show_page.bind("main"))
	row.add_child(confirm_button)
	row.add_child(cancel_button)
	col.add_child(row)
	return col


func _ask(action: String) -> void:
	_confirm_action = action
	show_page("confirm")


func _confirm() -> void:
	if _confirm_action == "title":
		quit_to_title_confirmed.emit()
	else:
		quit_game_confirmed.emit()


# --- widgets ------------------------------------------------------------------------

func _column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	return col


func _rule() -> ColorRect:
	return UiTheme.rect(Palette.PAPER_SHADE, Vector2(0, 2))


func _wide_button(text: String) -> Button:
	var b := UiTheme.button(text, UiTheme.SIZE_BODY, 0)
	b.custom_minimum_size = Vector2(0, 48)
	return b


func _row(caption: String, controls: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := UiTheme.label(caption, UiTheme.SIZE_BODY, Palette.INK)
	label.custom_minimum_size = Vector2(LABEL_W, 0)
	row.add_child(label)
	for c: Control in controls:
		row.add_child(c)
	return row


## Ink track, blue fill, and a pixel grabber in place of Godot's default look.
func _style_slider(s: HSlider) -> void:
	var track := UiTheme.flat_box(Palette.PAPER_SHADE, Palette.INK, 2, 0, 4)
	s.add_theme_stylebox_override("slider", track)
	var fill := UiTheme.flat_box(Palette.INK_BLUE, Palette.INK, 2, 0, 4)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var focus := UiTheme.flat_box(Color(0, 0, 0, 0), Palette.AMBER, 2, 0, 0)
	focus.draw_center = false
	s.add_theme_stylebox_override("focus", focus)
	var grabber := _grabber_icon(Palette.PAPER)
	s.add_theme_icon_override("grabber", grabber)
	s.add_theme_icon_override("grabber_highlight", _grabber_icon(Palette.HIGHLIGHT))
	s.add_theme_icon_override("grabber_disabled", grabber)


static func _grabber_icon(fill: Color) -> ImageTexture:
	var img := Image.create_empty(16, 28, false, Image.FORMAT_RGBA8)
	img.fill(Palette.INK)
	img.fill_rect(Rect2i(3, 3, 10, 22), fill)
	img.fill_rect(Rect2i(7, 8, 2, 12), Palette.INK)
	return ImageTexture.create_from_image(img)
