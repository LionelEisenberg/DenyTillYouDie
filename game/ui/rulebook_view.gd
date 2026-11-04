class_name RulebookView
extends DocumentView
## The Claims Adjudication Manual: tabbed pages that grow as rules unlock. Rule rows
## are citable in inspect mode; reference pages (network, prior auth, exclusions)
## are for reading, and so is MEMO, today's memo from R. Hargrove. Day 7 adds the
## DenyBot page.
##
## The day's new rule is boxed NEW and run over with a highlighter all shift. A
## reference tab unlocked today pulses until it is first opened. Tab and
## Shift+Tab turn the pages when not inspecting.

signal rule_clicked(rule_id: String, row: FieldRow)
signal denybot_pressed

const WIDTH := 420.0
## Wrap width for text on a page, and inside a (padded) rule row. Everything on
## a page wraps at or under these, so no page can push the book wider than WIDTH.
const PAGE_TEXT_WIDTH := WIDTH - 40.0
const RULE_TEXT_WIDTH := WIDTH - 60.0
## The reference tab each day unlocks.
const NEW_TABS: Dictionary = {2: "NETWORK", 4: "PRIOR AUTH", 6: "EXCLUSIONS", 7: "DENYBOT"}
## Memo paragraphs stop once they would run past this height, so the book always
## fits on the desk however long the memo gets.
const MEMO_TEXT_MAX_H := 520.0
const MEMO_CUT := "The rest of this memo is on file."
const MEMO_SIGNATURE := "R. Hargrove"
## A Label's default line spacing, for estimating wrapped text heights.
const LINE_SPACING := 3
const MARKER_GAP := 6

var denybot_button: Button
var denybot_result: Label
## The rule introduced today, boxed NEW on the RULES page.
var new_rule_id: String = ""
var _pages: Dictionary = {}
var _tabs: Dictionary = {}
var _order: PackedStringArray = []
var _current: String = ""
var _pulses: Dictionary = {}
var _new_marker: Control
var _inspecting := false


## Builds the book for `day`. `memo` is today's memo; left empty, it is read from
## GameState's run (run.morning["memo"]) when there is one.
func setup(day: int, memo: Dictionary = {}) -> void:
	if memo.is_empty():
		memo = _todays_memo()
	new_rule_id = String(Rules.new_rule_on(day).get("id", ""))
	set_paper(Palette.MEMO, WIDTH, Palette.INK_FADED)
	add_title("CLAIMS ADJUDICATION MANUAL", UiTheme.SIZE_BODY)
	add_text("Benevolence Mutual  -  Rev. 7  -  Effective %s" % DateUtil.fmt(DateUtil.game_date(day)), UiTheme.SIZE_SMALL).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Tabs wrap onto a second row rather than widen the book (day 7 has six).
	var tab_bar := HFlowContainer.new()
	tab_bar.add_theme_constant_override("h_separation", 4)
	tab_bar.add_theme_constant_override("v_separation", 4)
	tab_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(tab_bar)
	add_rule(Palette.INK_FADED)

	_add_page("RULES", tab_bar, _rules_page(day))
	if not memo.is_empty():
		_add_page("MEMO", tab_bar, _memo_page(memo))
	if day >= 2:
		_add_page("NETWORK", tab_bar, _list_page("NETWORK DIRECTORY", "In-network providers. Anything else is out of network.", Medical.PROVIDERS_IN, UiTheme.SIZE_BODY))
	if day >= 4:
		_add_page("PRIOR AUTH", tab_bar, _list_page("PRIOR AUTHORIZATION", "These procedures need a PRIOR AUTH # on the claim.", Medical.pa_labels(), UiTheme.SIZE_SMALL))
	if day >= 6:
		_add_page("EXCLUSIONS", tab_bar, _list_page("EXCLUSIONS", "Not covered under any plan, whatever the doctor says.", Medical.excluded_labels(), UiTheme.SIZE_SMALL))
	if day >= 7:
		_add_page("DENYBOT", tab_bar, _denybot_page())
	var unlocked: String = NEW_TABS.get(day, "")
	if _tabs.has(unlocked):
		var pulse := TabPulse.new()
		(_tabs[unlocked] as Button).add_child(pulse)
		_pulses[unlocked] = pulse
	show_page("RULES")


func show_page(page_name: String) -> void:
	if not _pages.has(page_name):
		return
	_current = page_name
	for key: String in _pages:
		(_pages[key] as Control).visible = key == page_name
		(_tabs[key] as Button).disabled = key == page_name
	if _pulses.has(page_name):
		(_pulses[page_name] as Node).queue_free()
		_pulses.erase(page_name)


func current_page() -> String:
	return _current


## Whether `page_name`'s tab is still pulsing (unlocked today, not yet opened).
func is_tab_pulsing(page_name: String) -> bool:
	return _pulses.has(page_name)


## The NEW box beside today's rule, or null.
func new_marker() -> Control:
	return _new_marker


func find_rule_row(rule_id: String) -> FieldRow:
	return find_row(rule_id)


func set_inspect(on: bool) -> void:
	_inspecting = on
	super.set_inspect(on)


func set_denybot_enabled(on: bool) -> void:
	if denybot_button:
		denybot_button.disabled = not on


func show_denybot_result(text: String) -> void:
	if denybot_result:
		denybot_result.text = text


func denybot_text() -> String:
	return denybot_result.text if denybot_result else ""


## Tab and Shift+Tab turn the pages, unless the player is inspecting (the rules
## have to stay open for citing).
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var tab := key.keycode == KEY_TAB or key.physical_keycode == KEY_TAB
	var back_tab := key.keycode == KEY_BACKTAB
	if not (tab or back_tab) or _inspecting or not is_visible_in_tree() or _order.size() < 2:
		return
	get_viewport().set_input_as_handled()
	if key.echo:
		return
	var step := -1 if key.shift_pressed or back_tab else 1
	show_page(_order[posmod(_order.find(_current) + step, _order.size())])
	Sfx.play("page")


## Today's memo from GameState's run, or {} when there is no run yet. Read through
## the main loop: the desk builds the book before adding it to the tree.
static func _todays_memo() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return {}
	var gs := tree.root.get_node_or_null("GameState")
	if gs == null:
		return {}
	var run: Variant = gs.get("run")
	if not (run is Object):
		return {}
	var morning: Variant = (run as Object).get("morning")
	if not (morning is Dictionary):
		return {}
	var memo: Variant = (morning as Dictionary).get("memo", {})
	if memo is Dictionary:
		return memo
	return {}


func _add_page(page_name: String, tab_bar: Container, page: Control) -> void:
	var tab := UiTheme.button(page_name, UiTheme.SIZE_SMALL)
	tab.add_theme_stylebox_override("normal", UiTheme.flat_box(Palette.PAPER_SHADE, Palette.INK_FADED, 2, 8, 2))
	tab.add_theme_stylebox_override("hover", UiTheme.flat_box(Palette.PAPER_ALT, Palette.INK_FADED, 2, 8, 2))
	tab.add_theme_stylebox_override("pressed", UiTheme.flat_box(Palette.PAPER_ALT, Palette.INK_FADED, 2, 8, 2))
	tab.add_theme_stylebox_override("disabled", UiTheme.flat_box(Palette.MEMO, Palette.INK, 2, 8, 2))
	tab.add_theme_color_override("font_color", Palette.INK_FADED)
	tab.add_theme_color_override("font_hover_color", Palette.INK)
	tab.add_theme_color_override("font_disabled_color", Palette.INK)
	tab.focus_mode = Control.FOCUS_NONE
	# The page turn is its sound; no generic button clack on top of it.
	tab.set_meta("silent", true)
	tab.pressed.connect(func() -> void:
		Sfx.play("page")
		show_page(page_name))
	tab_bar.add_child(tab)
	body.add_child(page)
	_pages[page_name] = page
	_tabs[page_name] = tab
	_order.append(page_name)


func _rules_page(day: int) -> Control:
	var page := VBoxContainer.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_theme_constant_override("separation", 6)
	page.add_child(UiTheme.para("Deny when a claim breaks one of these rules. To cite: press INSPECT, click the rule, then the evidence.", PAGE_TEXT_WIDTH, UiTheme.SIZE_SMALL, Palette.INK_FADED))
	for rule_id in Rules.unlocked(day):
		var rule := Rules.get_rule(rule_id)
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_theme_constant_override("separation", 0)
		var title := String(rule["title"]).to_upper()
		if rule_id == new_rule_id:
			stack.add_child(_new_rule_title(rule_id, title))
		else:
			# Titles wrap too: "R-07  ALGORITHMIC DETERMINATION (DENYBOT)" is wider than the book.
			stack.add_child(UiTheme.para("%s  %s" % [rule_id, title], RULE_TEXT_WIDTH, UiTheme.SIZE_BODY, Palette.INK))
		stack.add_child(UiTheme.para(rule["text"], RULE_TEXT_WIDTH, UiTheme.SIZE_SMALL, Palette.INK_FADED))
		var row := FieldRow.wrap(stack, rule_id)
		row.clicked.connect(func(r: FieldRow) -> void: rule_clicked.emit(r.key, r))
		rows.append(row)
		page.add_child(row)
	return page


## "R-02 [NEW] OUT-OF-NETWORK PROVIDER": the code, a small red-ink box, and the
## title with a highlighter stroke behind it. Every width is fixed from the font,
## so the line is exactly RULE_TEXT_WIDTH wide and never widens the book.
func _new_rule_title(rule_id: String, title: String) -> Control:
	var font := UiTheme.font()
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", MARKER_GAP)
	var code := UiTheme.label(rule_id, UiTheme.SIZE_BODY, Palette.INK)
	code.clip_text = true
	code.custom_minimum_size = Vector2(ceilf(font.get_string_size(rule_id, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BODY).x), 0)
	code.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(code)
	var word := UiTheme.label("NEW", UiTheme.SIZE_SMALL, Palette.RED)
	word.clip_text = true
	word.custom_minimum_size = Vector2(ceilf(font.get_string_size("NEW", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x), 0)
	var marker := PanelContainer.new()
	marker.name = "NewMarker"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0, 0, 0, 0), Palette.RED, 2, 4, 2))
	marker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	marker.add_child(word)
	var marker_box := MarginContainer.new()
	marker_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_box.add_theme_constant_override("margin_top", 1)
	marker_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	marker_box.add_child(marker)
	line.add_child(marker_box)
	_new_marker = marker
	var used := code.custom_minimum_size.x + word.custom_minimum_size.x + 8.0 + 2.0 * MARKER_GAP
	var text := UiTheme.para(title, RULE_TEXT_WIDTH - used, UiTheme.SIZE_BODY, Palette.INK)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Highlighter.new(text, hash(rule_id)))
	line.add_child(text)
	return line


## Today's memo at 16 px: the date and RE line, the paragraphs, and the boss's
## signature. Letters stay out.
func _memo_page(memo: Dictionary) -> Control:
	var page := VBoxContainer.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_theme_constant_override("separation", 6)
	page.add_child(UiTheme.para("INTERNAL MEMORANDUM  -  %s" % String(memo.get("date", "")), PAGE_TEXT_WIDTH, UiTheme.SIZE_SMALL, Palette.INK_FADED))
	page.add_child(UiTheme.para("RE: %s" % String(memo.get("subject", "")), PAGE_TEXT_WIDTH, UiTheme.SIZE_SMALL, Palette.INK))
	page.add_child(UiTheme.rect(Palette.INK_FADED, Vector2(0, 2)))
	var room := MEMO_TEXT_MAX_H
	for paragraph: String in memo.get("paragraphs", []):
		var needed := text_height(paragraph, PAGE_TEXT_WIDTH, UiTheme.SIZE_SMALL) + 6.0
		if needed > room:
			page.add_child(UiTheme.para(MEMO_CUT, PAGE_TEXT_WIDTH, UiTheme.SIZE_SMALL, Palette.INK_FADED))
			break
		room -= needed
		page.add_child(UiTheme.para(paragraph, PAGE_TEXT_WIDTH, UiTheme.SIZE_SMALL, Palette.INK))
	page.add_child(UiTheme.label(MEMO_SIGNATURE, UiTheme.SIZE_BODY, Palette.INK_BLUE))
	return page


func _list_page(title: String, note: String, items: PackedStringArray, item_size: int) -> Control:
	var page := VBoxContainer.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_theme_constant_override("separation", 0)
	page.add_child(UiTheme.para(title, PAGE_TEXT_WIDTH, UiTheme.SIZE_BODY, Palette.INK))
	page.add_child(UiTheme.para(note, PAGE_TEXT_WIDTH, UiTheme.SIZE_SMALL, Palette.INK_FADED))
	page.add_child(UiTheme.rect(Color(0, 0, 0, 0), Vector2(0, 6)))
	for item in items:
		page.add_child(UiTheme.para("- " + item, PAGE_TEXT_WIDTH, item_size, Palette.INK))
	return page


func _denybot_page() -> Control:
	var page := VBoxContainer.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_theme_constant_override("separation", 10)
	page.add_child(UiTheme.label("DENYBOT v2.3", UiTheme.SIZE_BIG, Palette.RED_DARK))
	page.add_child(UiTheme.para("Proprietary algorithmic claim review. DenyBot determinations count as cited denials (R-07). Reasoning is not available.", PAGE_TEXT_WIDTH, UiTheme.SIZE_SMALL, Palette.INK_FADED))
	denybot_button = UiTheme.button("RUN DENYBOT", UiTheme.SIZE_BODY)
	denybot_button.disabled = true
	denybot_button.focus_mode = Control.FOCUS_NONE
	denybot_button.pressed.connect(func() -> void: denybot_pressed.emit())
	page.add_child(denybot_button)
	denybot_result = UiTheme.para("", PAGE_TEXT_WIDTH, UiTheme.SIZE_BODY, Palette.RED_DARK)
	page.add_child(denybot_result)
	return page


## Widths of the lines `text` wraps into at `width`, breaking between words the
## way a word-wrapping Label does, in the book's own font.
static func line_widths(text: String, width: float, font_size: int) -> PackedFloat32Array:
	var font := UiTheme.font()
	var widths := PackedFloat32Array()
	var line := ""
	for word in text.split(" ", false):
		var candidate := word if line == "" else "%s %s" % [line, word]
		if line != "" and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			widths.append(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
			line = word
		else:
			line = candidate
	if line != "":
		widths.append(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return widths


## Height of `text` wrapped at `width`, as a Label prints it.
static func text_height(text: String, width: float, font_size: int) -> float:
	var lines := maxi(1, line_widths(text, width, font_size).size())
	return lines * (UiTheme.font().get_height(font_size) + LINE_SPACING) - LINE_SPACING


## A pulsing amber border around a tab unlocked today, until it is opened. Steady
## when reduce_motion is set.
class TabPulse extends Control:
	const HZ := 1.2
	var _time := 0.0


	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()


	func _draw() -> void:
		var alpha := 1.0
		if not Engine.get_meta("reduce_motion", false):
			alpha = 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * TAU * HZ))
		draw_rect(Rect2(Vector2.ZERO, size).grow(1.0), Color(Palette.AMBER, alpha), false, 3.0)


## A ragged stroke of yellow highlighter behind a label's text, one band per
## wrapped line. Drawn behind its parent label, so the ink stays on top.
class Highlighter extends Control:
	const ALPHA := 0.35
	var _label: Label
	var _seed: int


	func _init(label: Label, seed_value: int) -> void:
		_label = label
		_seed = seed_value
		show_behind_parent = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


	func _draw() -> void:
		var font_size := _label.get_theme_font_size("font_size")
		var widths := RulebookView.line_widths(_label.text, size.x, font_size)
		var line_h := float(UiTheme.font().get_height(font_size))
		var step := line_h + _label.get_theme_constant("line_spacing")
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		for i in widths.size():
			var top := i * step + line_h * 0.15
			var bottom := i * step + line_h * 0.95
			var left := -3.0
			var right := minf(widths[i] + 4.0, size.x + 3.0)
			var steps := maxi(4, int((right - left) / 14.0))
			var band := PackedVector2Array()
			band.append(Vector2(left - rng.randf_range(0.0, 2.0), lerpf(top, bottom, 0.5)))
			for k in steps + 1:
				band.append(Vector2(lerpf(left, right, float(k) / steps), top + rng.randf_range(-1.5, 1.5)))
			band.append(Vector2(right + rng.randf_range(0.0, 3.0), lerpf(top, bottom, 0.55)))
			for k in range(steps, -1, -1):
				band.append(Vector2(lerpf(left, right, float(k) / steps), bottom + rng.randf_range(-1.5, 1.5)))
			draw_colored_polygon(band, Color(Palette.HIGHLIGHT, ALPHA))
