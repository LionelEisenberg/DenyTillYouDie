class_name RulebookView
extends DocumentView
## The Claims Adjudication Manual: tabbed pages that grow as rules unlock. Rule rows
## are citable in inspect mode; reference pages (network, prior auth, exclusions)
## are for reading. Day 7 adds the DenyBot page.

signal rule_clicked(rule_id: String, row: FieldRow)
signal denybot_pressed

const WIDTH := 420.0
## Wrap width for text on a page, and inside a (padded) rule row. Everything on
## a page wraps at or under these, so no page can push the book wider than WIDTH.
const PAGE_TEXT_WIDTH := WIDTH - 40.0
const RULE_TEXT_WIDTH := WIDTH - 60.0

var denybot_button: Button
var denybot_result: Label
var _pages: Dictionary = {}
var _tabs: Dictionary = {}


func setup(day: int) -> void:
	set_paper(Palette.MEMO, WIDTH, Palette.INK_FADED)
	add_title("CLAIMS ADJUDICATION MANUAL", UiTheme.SIZE_BODY)
	add_text("Benevolence Mutual  -  Rev. 7  -  Effective %s" % DateUtil.fmt(DateUtil.game_date(day)), UiTheme.SIZE_SMALL).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	tab_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(tab_bar)
	add_rule(Palette.INK_FADED)

	_add_page("RULES", tab_bar, _rules_page(day))
	if day >= 2:
		_add_page("NETWORK", tab_bar, _list_page("NETWORK DIRECTORY", "In-network providers. Anything else is out of network.", Medical.PROVIDERS_IN, UiTheme.SIZE_BODY))
	if day >= 4:
		_add_page("PRIOR AUTH", tab_bar, _list_page("PRIOR AUTHORIZATION", "These procedures need a PRIOR AUTH # on the claim.", Medical.pa_labels(), UiTheme.SIZE_SMALL))
	if day >= 6:
		_add_page("EXCLUSIONS", tab_bar, _list_page("EXCLUSIONS", "Not covered under any plan, whatever the doctor says.", Medical.excluded_labels(), UiTheme.SIZE_SMALL))
	if day >= 7:
		_add_page("DENYBOT", tab_bar, _denybot_page())
	show_page("RULES")


func show_page(page_name: String) -> void:
	for key: String in _pages:
		(_pages[key] as Control).visible = key == page_name
		(_tabs[key] as Button).disabled = key == page_name


func find_rule_row(rule_id: String) -> FieldRow:
	return find_row(rule_id)


func set_denybot_enabled(on: bool) -> void:
	if denybot_button:
		denybot_button.disabled = not on


func show_denybot_result(text: String) -> void:
	if denybot_result:
		denybot_result.text = text


func denybot_text() -> String:
	return denybot_result.text if denybot_result else ""


func _add_page(page_name: String, tab_bar: HBoxContainer, page: Control) -> void:
	var tab := UiTheme.button(page_name, UiTheme.SIZE_SMALL)
	tab.add_theme_stylebox_override("normal", UiTheme.flat_box(Palette.PAPER_SHADE, Palette.INK_FADED, 2, 8, 2))
	tab.add_theme_stylebox_override("hover", UiTheme.flat_box(Palette.PAPER_ALT, Palette.INK_FADED, 2, 8, 2))
	tab.add_theme_stylebox_override("pressed", UiTheme.flat_box(Palette.PAPER_ALT, Palette.INK_FADED, 2, 8, 2))
	tab.add_theme_stylebox_override("disabled", UiTheme.flat_box(Palette.MEMO, Palette.INK, 2, 8, 2))
	tab.add_theme_color_override("font_color", Palette.INK_FADED)
	tab.add_theme_color_override("font_hover_color", Palette.INK)
	tab.add_theme_color_override("font_disabled_color", Palette.INK)
	tab.focus_mode = Control.FOCUS_NONE
	tab.pressed.connect(show_page.bind(page_name))
	tab_bar.add_child(tab)
	body.add_child(page)
	_pages[page_name] = page
	_tabs[page_name] = tab


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
		# Titles wrap too: "R-07  ALGORITHMIC DETERMINATION (DENYBOT)" is wider than the book.
		stack.add_child(UiTheme.para("%s  %s" % [rule_id, String(rule["title"]).to_upper()], RULE_TEXT_WIDTH, UiTheme.SIZE_BODY, Palette.INK))
		stack.add_child(UiTheme.para(rule["text"], RULE_TEXT_WIDTH, UiTheme.SIZE_SMALL, Palette.INK_FADED))
		var row := FieldRow.wrap(stack, rule_id)
		row.clicked.connect(func(r: FieldRow) -> void: rule_clicked.emit(r.key, r))
		rows.append(row)
		page.add_child(row)
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
