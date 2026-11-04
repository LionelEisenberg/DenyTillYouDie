extends RefCounted
## The papers, the manual, the meter and the desk props: what they say, how big
## they are and how they move. Layout checks use the real font.

var t: TestContext
var tree: SceneTree
var gs: Node
## Nodes a test added to the tree; freed after it.
var _nodes: Array[Node] = []

## Where the desk spawns each paper (DeskScreen._spawn_documents), and its size.
const CLAIM_AT := Vector2(20, 16)
const CARD_AT := Vector2(540, 16)
const BILL_AT := Vector2(540, 320)
const HISTORY_AT := Vector2(20, 470)
const DESK_H := 864.0
## The manual sits 12 px down the desk (DeskScreen._build_desk).
const BOOK_TOP := 12.0


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	gs.save_path_override = TestContext.save_path()
	gs.new_run("Pat Doe", 77)


func after_each() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	if Engine.has_meta("reduce_motion"):
		Engine.remove_meta("reduce_motion")
	await tree.process_frame
	gs.delete_save()
	gs.save_path_override = ""


## Adds `node` to the tree with the game's theme (real font metrics) and lets
## the containers settle.
func _place(node: Control) -> void:
	node.theme = UiTheme.build()
	tree.root.add_child(node)
	_nodes.append(node)
	for i in 3:
		await tree.process_frame


func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	if node is Label:
		found.append(node as Label)
	for child in node.get_children():
		found.append_array(_labels(child))
	return found


func _texts(node: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	for l in _labels(node):
		texts.append(l.text)
	return texts


## Every PortraitView under `node` (find_children's type filter only knows
## engine classes).
func _faces(node: Node) -> Array[PortraitView]:
	var found: Array[PortraitView] = []
	for child in node.get_children():
		if child is PortraitView:
			found.append(child as PortraitView)
		found.append_array(_faces(child))
	return found


func _contains_text(node: Node, part: String) -> bool:
	for text in _texts(node):
		if text.contains(part):
			return true
	return false


func _book(day: int, memo: Dictionary = {}) -> RulebookView:
	var book := RulebookView.new()
	book.setup(day, memo)
	await _place(book)
	return book


# --- the manual --------------------------------------------------------------

## The amber borders drawn on a tab (RulebookView.TabPulse children).
func _pulse_nodes(tab: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in tab.get_children():
		if child is RulebookView.TabPulse and not child.is_queued_for_deletion():
			found.append(child)
	return found


func test_the_tab_unlocked_today_pulses_until_opened() -> void:
	var book: RulebookView = await _book(2)
	t.ok(book.is_tab_pulsing("NETWORK"), "day 2's NETWORK tab pulses")
	t.ok(not book.is_tab_pulsing("RULES") and not book.is_tab_pulsing("MEMO"), "nothing else does")
	var network: Button = book._tabs["NETWORK"]
	t.eq(_pulse_nodes(network).size(), 1, "an amber border is drawn on the NETWORK tab")
	if _pulse_nodes(network).size() == 1:
		var pulse := _pulse_nodes(network)[0] as Control
		t.eq(pulse.size, network.size, "around the whole tab")
		t.eq(pulse.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and the tab still takes the click")
	for page: String in ["RULES", "MEMO"]:
		t.eq(_pulse_nodes(book._tabs[page]).size(), 0, "no border on %s" % page)
	book.show_page("RULES")
	t.ok(book.is_tab_pulsing("NETWORK"), "still pulsing until it is opened")
	book.show_page("NETWORK")
	t.ok(not book.is_tab_pulsing("NETWORK"), "opening it stops the pulse")
	t.eq(_pulse_nodes(network).size(), 0, "and takes the border away")
	book.show_page("RULES")
	t.ok(not book.is_tab_pulsing("NETWORK"), "and it stays stopped")
	for day: int in [3, 5]:
		var plain: RulebookView = await _book(day)
		for page: String in plain._pages:
			t.ok(not plain.is_tab_pulsing(page), "day %d: no new tab, no pulse (%s)" % [day, page])
	for day: int in [4, 6, 7]:
		var later: RulebookView = await _book(day)
		t.ok(later.is_tab_pulsing(RulebookView.NEW_TABS[day]), "day %d pulses %s" % [day, RulebookView.NEW_TABS[day]])


func test_the_memo_page_prints_todays_memo() -> void:
	var memo := {"date": "03/03/2026", "subject": "Directive: Out-of-network providers (R-02)", "paragraphs": PackedStringArray(["First paragraph.", "Second paragraph."])}
	var book: RulebookView = await _book(2, memo)
	var page: Control = book._pages["MEMO"]
	t.ok(_contains_text(page, memo["subject"]), "the RE line: %s" % _texts(page))
	t.ok(_contains_text(page, "Second paragraph."), "the paragraphs")
	t.ok(_texts(page).has(RulebookView.MEMO_SIGNATURE), "signed")
	for l in _labels(page):
		if l.text == RulebookView.MEMO_SIGNATURE:
			t.eq(l.get_theme_color("font_color"), Palette.INK_BLUE, "in blue ink")
		elif l.text.contains("paragraph") or l.text.contains(memo["subject"]):
			t.eq(l.get_theme_font_size("font_size"), UiTheme.SIZE_SMALL, "memo text is 16 px: %s" % l.text)


func test_the_memo_comes_from_the_run_when_none_is_passed() -> void:
	var subject: String = gs.run.morning["memo"]["subject"]
	var book: RulebookView = await _book(1)
	t.ok(book._pages.has("MEMO"), "the desk's book has a MEMO tab")
	t.ok(_contains_text(book._pages["MEMO"], subject), "with this morning's memo: %s" % subject)


func test_a_long_memo_is_cut_short_and_the_book_still_fits() -> void:
	var paragraphs := PackedStringArray()
	for i in 20:
		paragraphs.append("Paragraph %d. Claims Integrity reminds every adjuster that a denial without a reason on file is a denial the Company may have to explain, and nobody wants that." % i)
	var book: RulebookView = await _book(7, {"date": "03/08/2026", "subject": "A long memo", "paragraphs": paragraphs})
	t.ok(_texts(book._pages["MEMO"]).has(RulebookView.MEMO_CUT), "the memo says the rest is on file")
	for page: String in book._pages:
		book.show_page(page)
		for i in 3:
			await tree.process_frame
		t.eq(book.size.x, RulebookView.WIDTH, "%s page width with every day-7 tab" % page)
		t.ok(BOOK_TOP + book.size.y <= DESK_H, "%s page fits the desk: %d px" % [page, book.size.y])


func test_todays_rule_is_marked_new() -> void:
	for day in range(1, 8):
		var book: RulebookView = await _book(day)
		var rule: String = Rules.new_rule_on(day)["id"]
		t.eq(book.new_rule_id, rule, "day %d" % day)
		var marker := book.new_marker()
		t.ok(marker != null and book.find_rule_row(rule).is_ancestor_of(marker), "day %d: %s carries the NEW box" % [day, rule])
		t.ok(_texts(book.find_rule_row(rule)).has("NEW"), "day %d: it says NEW" % day)
		var strokes := _highlighters(book.find_rule_row(rule))
		t.eq(strokes.size(), 1, "day %d: one highlighter stroke on %s" % [day, rule])
		if strokes.size() == 1:
			var title := strokes[0].get_parent() as Label
			t.ok(title != null and title.text == String(Rules.get_rule(rule)["title"]).to_upper(), "day %d: behind the rule's title" % day)
			t.ok(strokes[0].show_behind_parent, "day %d: drawn under the ink" % day)
			t.ok(strokes[0].size.x > 0.0 and strokes[0].size.y > 0.0, "day %d: covering the title: %s" % [day, strokes[0].size])
		for other in Rules.unlocked(day):
			if other != rule:
				t.ok(not _texts(book.find_rule_row(other)).has("NEW"), "day %d: %s is not new" % [day, other])
				t.eq(_highlighters(book.find_rule_row(other)).size(), 0, "day %d: %s is not highlighted" % [day, other])
		t.eq(book.size.x, RulebookView.WIDTH, "day %d: the marker doesn't widen the book" % day)


## Highlighter strokes anywhere under `node`.
func _highlighters(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child in node.find_children("*", "", true, false):
		if child is RulebookView.Highlighter:
			found.append(child as Control)
	return found


func test_tab_turns_the_pages_unless_inspecting() -> void:
	var book: RulebookView = await _book(4)
	tree.root.gui_release_focus()
	var order := ["RULES", "MEMO", "NETWORK", "PRIOR AUTH"]
	t.eq(Array(book._order), order, "tab order")
	for expected: String in ["MEMO", "NETWORK", "PRIOR AUTH", "RULES"]:
		_key(KEY_TAB)
		await tree.process_frame
		t.eq(book.current_page(), expected, "Tab")
	_key(KEY_TAB, true)
	await tree.process_frame
	t.eq(book.current_page(), "PRIOR AUTH", "Shift+Tab goes back")
	book.show_page("RULES")
	book.set_inspect(true)
	_key(KEY_TAB)
	await tree.process_frame
	t.eq(book.current_page(), "RULES", "no page turning while inspecting")
	book.set_inspect(false)
	for tab: Button in book._tabs.values():
		t.ok(tab.get_meta("silent", false), "%s is silent (it plays its own page turn)" % tab.text)
		t.eq(tab.focus_mode, Control.FOCUS_NONE)


func _key(keycode: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.shift_pressed = shift
		e.pressed = pressed
		tree.root.push_input(e)


# --- paper in the hand ---------------------------------------------------------

func _sheet() -> DocumentView:
	var d := DocumentView.new()
	d.set_paper(Palette.PAPER, 300)
	d.add_field("NAME", "Maria Okafor", "claim.name")
	d.add_field("MEMBER ID", "BMH-483-2291", "claim.member_id")
	d.position = Vector2(200, 150)
	await _place(d)
	return d


func test_a_miss_shakes_the_whole_document_and_puts_it_back() -> void:
	var d: DocumentView = await _sheet()
	var row := d.find_row("claim.name")
	var home := d.position
	var row_home := row.position
	row.set_mark(FieldRow.Mark.INVALID)
	t.ok(d.is_shaking(), "a miss shakes the sheet")
	t.near(absf(d.paper.position.x), 6.0, 0.01, "the paper jogs 6 px at once")
	t.eq(d.paper.position.y, 0.0, "sideways only")
	t.eq(d.overlay.position, d.paper.position, "stamps and notes move with it")
	t.eq(row.position, row_home, "the row itself stays put on the paper")
	t.eq(d.position, home, "the sheet's own position is never touched")
	var offsets := {}
	while d.is_shaking():
		offsets[d.paper.position.x] = true
		t.eq(d.position, home, "not even mid-shake")
		await tree.process_frame
	t.ok(offsets.size() >= 2, "it moves back and forth: %s" % [offsets.keys()])
	t.eq(d.paper.position, Vector2.ZERO, "and ends square on the sheet")
	t.eq(d.overlay.position, Vector2.ZERO)
	t.eq(d.position, home, "exactly where it was")
	row.set_mark(FieldRow.Mark.INVALID)
	d._stop_shake()
	t.eq(d.paper.position, Vector2.ZERO, "stopping early squares it up too")
	Engine.set_meta("reduce_motion", true)
	row.set_mark(FieldRow.Mark.INVALID)
	t.ok(not d.is_shaking(), "reduce_motion: no shake")
	t.eq(d.paper.position, Vector2.ZERO)


## The desk slides each paper in with a position tween. A miss while it is still
## arriving must not leave it off its spot, even when the slide ends mid-shake.
func test_a_miss_on_a_sliding_sheet_leaves_it_where_the_slide_ends() -> void:
	var d: DocumentView = await _sheet()
	var target := Vector2(20, 200)
	d.position = Vector2(-520, 240)
	var slide := d.create_tween()
	slide.tween_property(d, "position", target, 0.12)
	await tree.create_timer(0.04).timeout
	d.find_row("claim.name").set_mark(FieldRow.Mark.INVALID)
	t.ok(d.is_shaking(), "missed mid-slide")
	await slide.finished
	t.ok(d.is_shaking(), "the slide ends while the paper still shakes")
	await tree.create_timer(0.3).timeout
	t.ok(not d.is_shaking())
	t.eq(d.position, target, "the slide ends exactly on its spot")
	t.eq(d.paper.position, Vector2.ZERO)


func _screen_pos(c: Control, local: Vector2) -> Vector2:
	# Pushed events are in window coordinates (see test_desk_input.gd).
	return tree.root.get_final_transform() * (c.get_global_transform_with_canvas() * local)


func _press(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.position = at
	e.global_position = at
	tree.root.push_input(e)


func _move(from: Vector2, to: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	e.global_position = to
	e.relative = to - from
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	tree.root.push_input(e)


## Picked up mid-shake with the real mouse, the sheet stops shaking and the spot
## grabbed stays under the cursor as it moves.
func test_a_sheet_grabbed_mid_shake_follows_the_hand() -> void:
	var d: DocumentView = await _sheet()
	d.move_to_front()
	await tree.process_frame
	var home := d.position
	var grab_local := Vector2(d.size.x / 2.0, 6)
	var grab := _screen_pos(d, grab_local)
	var scale := (tree.root.get_final_transform() * d.get_global_transform_with_canvas()).get_scale().x
	d.find_row("claim.member_id").set_mark(FieldRow.Mark.INVALID)
	t.ok(d.is_shaking() and d.paper.position != Vector2.ZERO, "shaking")
	_move(grab, grab)
	_press(grab, true)
	await tree.process_frame
	t.ok(d.is_dragging(), "picked up mid-shake")
	t.ok(not d.is_shaking(), "it stops shaking in the hand")
	t.eq(d.paper.position, Vector2.ZERO, "square under the hand")
	t.eq(d.position, home, "nothing jumped")
	var to := grab + Vector2(90, 40) * scale
	_move(grab, to)
	await tree.process_frame
	t.near(d.position.x - home.x, 90.0, 1.0, "follows the hand right")
	t.near(d.position.y - home.y, 40.0, 1.0, "and down")
	var under := (tree.root.get_final_transform() * d.get_global_transform_with_canvas()).affine_inverse() * to
	t.near(under.x, grab_local.x, 1.0, "the spot grabbed is still under the cursor")
	t.near(under.y, grab_local.y, 1.0)
	_press(to, false)
	await tree.create_timer(0.3).timeout
	t.ok(not d.is_dragging(), "let go")
	t.eq(d.paper.position, Vector2.ZERO)


func test_a_new_citation_link_draws_itself_in() -> void:
	var overlay := CiteOverlay.new()
	overlay.size = Vector2(800, 600)
	await _place(overlay)
	var a := UiTheme.rect(Palette.INK, Vector2(40, 20))
	var b := UiTheme.rect(Palette.INK, Vector2(40, 20))
	b.position = Vector2(400, 300)
	overlay.add_child(a)
	overlay.add_child(b)
	overlay.link(a, b)
	t.eq(overlay.progress, 0.0, "starts undrawn")
	await tree.process_frame
	await tree.process_frame
	t.ok(overlay.progress > 0.0, "draws in: %s" % overlay.progress)
	await tree.create_timer(0.3).timeout
	t.eq(overlay.progress, 1.0, "fully drawn within 0.3 s")
	Engine.set_meta("reduce_motion", true)
	overlay.link(b, a)
	t.eq(overlay.progress, 1.0, "reduce_motion: drawn at once")


## Inside a screen running fast (tests, the screenshot tour), a link is drawn at
## once, so a shot taken right after citing shows the whole line.
func test_a_fast_screen_draws_the_link_at_once() -> void:
	var screen := ScreenBase.new()
	await _place(screen)
	var holder := Control.new()
	screen.add_child(holder)
	var overlay := CiteOverlay.new()
	overlay.size = Vector2(800, 600)
	holder.add_child(overlay)
	var a := UiTheme.rect(Palette.INK, Vector2(40, 20))
	var b := UiTheme.rect(Palette.INK, Vector2(40, 20))
	b.position = Vector2(400, 300)
	overlay.add_child(a)
	overlay.add_child(b)
	overlay.link(a, b)
	t.eq(overlay.progress, 0.0, "a normal screen draws it in")
	screen.fast = true
	overlay.link(b, a)
	t.eq(overlay.progress, 1.0, "a fast one draws it at once")


func test_rows_show_a_crosshair_only_when_citable() -> void:
	var d: DocumentView = await _sheet()
	var row := d.find_row("claim.name")
	t.eq(d.mouse_default_cursor_shape, Control.CURSOR_MOVE, "paper: move")
	t.eq(d.paper.mouse_default_cursor_shape, Control.CURSOR_MOVE, "the sheet under the rows too")
	t.eq(row.mouse_default_cursor_shape, Control.CURSOR_MOVE, "row outside inspect: move")
	d.set_inspect(true)
	t.eq(row.mouse_default_cursor_shape, Control.CURSOR_CROSS, "row in inspect: crosshair")
	d.set_inspect(false)
	t.eq(row.mouse_default_cursor_shape, Control.CURSOR_MOVE)
	t.eq(row.mouse_filter, Control.MOUSE_FILTER_PASS, "rows still pass clicks to the paper")
	var card := Paperwork.member_card(Claim.new())
	t.ok(card.is_card, "the member card ticks instead of rustling")
	card.free()


## A sheet shown only to be read (the ending shows a claim form set to ignore
## the mouse) can't be picked up, so it shows no hand, inspecting or not.
func test_a_sheet_that_ignores_the_mouse_shows_a_plain_arrow() -> void:
	var c: Claim = ClaimGenerator.new(41, "Pat Doe").generate_day(5)[0]
	var still := Paperwork.claim_form(c)
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await _place(still)
	for inspecting: bool in [false, true, false]:
		still.set_inspect(inspecting)
		t.eq(still.mouse_default_cursor_shape, Control.CURSOR_ARROW, "the sheet (inspect %s)" % inspecting)
		t.eq(still.paper.mouse_default_cursor_shape, Control.CURSOR_ARROW, "the paper (inspect %s)" % inspecting)
		for row in still.rows:
			t.eq(row.mouse_default_cursor_shape, Control.CURSOR_ARROW, "%s (inspect %s)" % [row.key, inspecting])
	var live := Paperwork.claim_form(c)
	await _place(live)
	t.eq(live.mouse_default_cursor_shape, Control.CURSOR_MOVE, "a sheet on the desk still shows the open hand")
	t.eq(live.paper.mouse_default_cursor_shape, Control.CURSOR_MOVE)
	t.eq(live.find_row("claim.name").mouse_default_cursor_shape, Control.CURSOR_MOVE)


# --- readable evidence ---------------------------------------------------------

## Procedure ids by how wide their label prints at 24 px, widest first.
func _widest_procedures(count: int) -> Array[String]:
	var ids: Array[String] = []
	for id: String in Medical.PROCEDURES:
		ids.append(id)
	var font := UiTheme.font()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return font.get_string_size(Medical.PROCEDURES[a]["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BODY).x > font.get_string_size(Medical.PROCEDURES[b]["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BODY).x)
	return ids.slice(0, count)


func _longest(items: Array) -> String:
	var best := ""
	for item: String in items:
		if UiTheme.font().get_string_size(item, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BODY).x > UiTheme.font().get_string_size(best, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_BODY).x:
			best = item
	return best


## A day-6 claim with the longest everything: name, provider, diagnosis, the four
## widest bill lines, and four history entries with the longest labels.
func _worst_claim() -> Claim:
	var c := Claim.new()
	c.day = 6
	c.age = 61
	c.claim_no = "BM-0307-9999"
	c.name = "%s %s" % [_longest(Array(Names.FIRST)), _longest(Array(Names.LAST))]
	c.card_name = c.name
	c.dob = DateUtil.from_ymd(1964, 12, 28)
	c.card_dob = c.dob
	c.member_id = "BMH-888-8888"
	c.card_member_id = c.member_id
	var providers: Array = Array(Medical.PROVIDERS_IN) + Array(Medical.PROVIDERS_OUT)
	c.provider = _longest(providers)
	var labels: Array = []
	for dx: Dictionary in Medical.DIAGNOSES:
		labels.append(dx["label"])
	c.diagnosis = _longest(labels)
	c.plan = _longest(Array(Medical.PLANS))
	c.date_of_service = DateUtil.game_date(6) - 12
	c.member_since = DateUtil.from_ymd(2025, 12, 28)
	c.coverage_through = DateUtil.from_ymd(2026, 12, 31)
	c.prior_auth = "PA-88888"
	for id in _widest_procedures(4):
		c.bill_lines.append(Claim.make_line(id))
	c.amount = c.bill_total()
	var history_labels: Array = []
	for dx: Dictionary in Medical.DIAGNOSES:
		if dx["history_label"] != "":
			history_labels.append(dx["history_label"])
	for entry: Dictionary in Medical.FILLER_HISTORY:
		history_labels.append(entry["label"])
	history_labels.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for i in 4:
		c.history.append({"date": DateUtil.from_ymd(2020 + i, 12, 28), "label": history_labels[i], "condition": "hx_%d" % i})
	return c


func test_worst_case_papers_fit_where_the_desk_puts_them() -> void:
	var c := _worst_claim()
	var claim: DocumentView = Paperwork.claim_form(c)
	var card: DocumentView = Paperwork.member_card(c)
	var bill: DocumentView = Paperwork.itemized_bill(c)
	var history: DocumentView = Paperwork.medical_history(c)
	for d: DocumentView in [claim, card, bill, history]:
		await _place(d)
	t.ok(bill.size.y <= 520.0, "the bill with the four widest lines is %d px tall" % bill.size.y)
	t.ok(CLAIM_AT.y + claim.size.y <= HISTORY_AT.y, "the claim form (%d px) clears the history" % claim.size.y)
	t.ok(CARD_AT.y + card.size.y <= BILL_AT.y, "the card (%d px) clears the bill" % card.size.y)
	for pair: Array in [[claim, CLAIM_AT, "claim form"], [card, CARD_AT, "card"], [bill, BILL_AT, "bill"], [history, HISTORY_AT, "history"]]:
		var d: DocumentView = pair[0]
		var at: Vector2 = pair[1]
		t.ok(at.y + d.size.y <= DESK_H, "%s ends at %d, inside the %d px desk" % [pair[2], at.y + d.size.y, DESK_H])
	for i in c.bill_lines.size():
		for l in _labels(bill.find_row("bill.line.%d" % i)):
			t.eq(l.get_theme_font_size("font_size"), UiTheme.SIZE_BODY, "bill line %d: %s" % [i, l.text])


func test_the_citation_slip_reads_at_body_size() -> void:
	for args: Array in [[1, 0], [Economy.FREE_WARNINGS, 0], [Economy.FREE_WARNINGS + 1, Economy.CITATION_FINE]]:
		var slip := Paperwork.citation_slip(args[0], args[1])
		for l in _labels(slip):
			if l.text == "CITATION":
				continue
			var expected := UiTheme.SIZE_SMALL if l.text.begins_with("-") else UiTheme.SIZE_BODY
			t.eq(l.get_theme_font_size("font_size"), expected, "slip line '%s'" % l.text)
		slip.free()


## The slip says what ShiftLogic just did: the day's free warnings, counted, then
## the fine, with every number from Economy.
func test_the_citation_slip_says_what_shift_logic_did() -> void:
	var run := RunState.create("Pat Doe", 41)
	var lapsed: Claim = ClaimGenerator.new(41, "Pat Doe").generate_day(1)[0]
	t.ok(RuleChecker.has_valid_reason(lapsed, 1), "a claim with grounds to deny")
	var money := UiTheme.money(Economy.CITATION_FINE)
	var expected: Array[String] = []
	for n in range(1, Economy.FREE_WARNINGS):
		expected.append("Warning %d of %d today." % [n, Economy.FREE_WARNINGS])
	expected.append("Warning %d of %d today. Further citations will be fined %s." % [Economy.FREE_WARNINGS, Economy.FREE_WARNINGS, money])
	expected.append("Fine deducted: %s." % money)
	expected.append("Fine deducted: %s." % money)
	for line in expected:
		var result := ShiftLogic.apply_decision(run, lapsed, true, "")
		t.ok(result["citation"], "approving it is cited")
		var slip := Paperwork.citation_slip(int(result["warning"]), int(result["fine"]))
		t.ok(_texts(slip).has(line), "warning %d: %s" % [result["warning"], _texts(slip)])
		slip.free()
	t.eq(expected[1], "Warning 2 of 2 today. Further citations will be fined $5.", "as the spec words it")
	run.reset_today()
	var tomorrow := ShiftLogic.apply_decision(run, lapsed, true, "")
	var fresh := Paperwork.citation_slip(int(tomorrow["warning"]), int(tomorrow["fine"]))
	t.ok(_texts(fresh).has("Warning 1 of %d today." % Economy.FREE_WARNINGS), "the count starts over each day: %s" % _texts(fresh))
	fresh.free()


# --- exhibits --------------------------------------------------------------------

func _scripted_claims(seed_value: int) -> Dictionary:
	var gen := ClaimGenerator.new(seed_value, "Pat Doe")
	var found := {}
	for day in range(1, 8):
		for c in gen.generate_day(day):
			if c.scripted_id != "":
				found[c.scripted_id] = c
	return found


func test_scripted_patients_bring_one_personal_paper() -> void:
	var cases := _scripted_claims(41)
	t.eq(cases.size(), Scripted.CASES.size() + 1, "every scripted case and the player")
	for id: String in cases:
		var c: Claim = cases[id]
		var doc := Paperwork.exhibit(c)
		if id == "eleanor" or id == "player":
			t.ok(c.exhibit.is_empty() and doc == null, "%s brings no exhibit" % id)
			continue
		t.ok(not c.exhibit.is_empty() and doc != null, "%s brings an exhibit" % id)
		if doc == null:
			continue
		await _place(doc)
		var rows: Array = c.exhibit["rows"]
		t.ok(rows.size() > 0 and doc.rows.size() == rows.size(), "%s: %d rows" % [id, doc.rows.size()])
		for i in doc.rows.size():
			t.eq(doc.rows[i].key, "exhibit.%d" % i, "%s row %d key" % [id, i])
		t.near(doc.rotation_degrees, Paperwork.EXHIBIT_TILT, 0.001, "%s is tilted" % id)
		var max_h := Paperwork.EXHIBIT_LETTER_MAX_H if c.exhibit["kind"] == "letter" else Paperwork.EXHIBIT_MAX_H
		t.ok(doc.size.x <= Paperwork.EXHIBIT_WIDTH and doc.size.y <= max_h, "%s exhibit is %s, at most %s" % [id, doc.size, Vector2(Paperwork.EXHIBIT_WIDTH, max_h)])
	var marcus: Claim = cases["marcus"]
	t.ok(marcus.diagnosis.contains("stage IV"), "Marcus: %s" % marcus.diagnosis)


## The letters are what a player reads on a tilted sheet at the default window
## size, so their text is set at body size; captions and dates stay small.
func test_letters_are_set_to_be_read() -> void:
	var cases := _scripted_claims(2026)
	for id: String in ["lily", "marcus"]:
		var c: Claim = cases[id]
		var doc := Paperwork.exhibit(c)
		await _place(doc)
		var found := false
		for l in _labels(doc):
			if l.text == String(c.exhibit["body"]):
				found = true
				t.eq(l.get_theme_font_size("font_size"), UiTheme.SIZE_BODY, "%s's letter at 24 px" % id)
		t.ok(found, "%s's letter is printed" % id)
		for row in doc.rows:
			var labels := _labels(row)
			t.eq(labels[0].get_theme_font_size("font_size"), UiTheme.SIZE_SMALL, "%s caption '%s' stays 16 px" % [id, labels[0].text])
		t.ok(doc.size.y <= Paperwork.EXHIBIT_LETTER_MAX_H, "%s's letter fits: %d px" % [id, doc.size.y])


## The scan's screen prints the heart rate the report states, read from the row.
func test_the_ultrasound_prints_the_reports_heart_rate() -> void:
	var priya: Claim = _scripted_claims(2026)["priya"]
	var scans := _scans(Paperwork.exhibit(priya))
	t.eq(scans.size(), 1, "one scan")
	if scans.size() == 1:
		t.eq(scans[0].label, "FHR 142 BPM", "the report's own number")
	var rate_row: Array = []
	for row: Array in priya.exhibit["rows"]:
		if row[0] == "FETAL HEART RATE":
			rate_row = row
	t.eq(rate_row.size(), 2, "the report has a heart rate row")
	if rate_row.size() == 2:
		rate_row[1] = "150 BPM"
		var changed := _scans(Paperwork.exhibit(priya))
		t.ok(changed.size() == 1 and changed[0].label == "FHR 150 BPM", "change the row, the screen follows")


func _scans(doc: DocumentView) -> Array[Paperwork.UltrasoundScan]:
	var found: Array[Paperwork.UltrasoundScan] = []
	for child in doc.find_children("*", "", true, false):
		if child is Paperwork.UltrasoundScan:
			found.append(child as Paperwork.UltrasoundScan)
	_nodes.append(doc)
	return found


func test_exhibits_say_what_the_story_needs() -> void:
	var cases := _scripted_claims(2026)
	var walt: Claim = cases["walt"]
	t.eq(String(walt.exhibit["title"]), "ST. AGNES MEDICAL CENTER - ICU NURSING LOG")
	var log_rows: Array = walt.exhibit["rows"]
	t.eq(log_rows.size(), 5, "five days in the ICU")
	for i in log_rows.size():
		t.eq(log_rows[i][0], DateUtil.fmt(walt.date_of_service - 5 + i), "Walt's log row %d is dated DOS-%d" % [i, 5 - i])
	t.eq(log_rows[0][1], "Admitted. Intubated, sedated.")
	t.eq(log_rows[4][1], "Extubated. Alert. Asked what day it was.")
	t.ok(walt.coverage_through >= walt.date_of_service - 5 and walt.coverage_through <= walt.date_of_service - 1, "the lapse falls while he was in the ICU")
	var dale: Claim = cases["dale"]
	t.eq(dale.exhibit["kind"], "badge")
	var badge := Paperwork.exhibit(dale)
	await _place(badge)
	t.ok(_texts(badge).has("DALE PRUITT"), "his badge spells his name right: %s" % _texts(badge))
	t.ok(_texts(badge).has("CLAIMS ADJUSTER #4470") and _texts(badge).has("12"), "adjuster #4470, desk 12")
	var faces := _faces(badge)
	t.eq(faces.size(), 1, "with his photo")
	if faces.size() == 1:
		var expected := PortraitView.new()
		expected.show_patient(dale.portrait_seed, dale.age, false)
		t.eq(faces[0]._skin, expected._skin, "the face from his own case")
		t.eq(faces[0]._hair, expected._hair)
		t.eq(faces[0]._age, dale.age)
		expected.free()
	var priya: Claim = cases["priya"]
	t.ok(str(priya.exhibit).contains("142") and str(priya.exhibit).contains("03/19/2026") and String(priya.exhibit["body"]) == "Everything looks good. Rest.", "Priya's ultrasound")
	t.ok(String(cases["lily"].exhibit["signature"]).contains("Adeyemi"), "Lily's letter is signed")
	t.ok(String(cases["lily"].exhibit["body"]).contains("only pediatric oncology program in the state"))
	t.ok(String(cases["marcus"].exhibit["signature"]).contains("Lindgren"), "Marcus's letter is signed")
	t.ok(String(cases["marcus"].exhibit["body"]).contains("last reasonable option"))


## Exhibits look citable but never are: no rule names an exhibit row as evidence.
func test_exhibit_rows_are_never_evidence() -> void:
	var checked := 0
	for seed_value in 50:
		var gen := ClaimGenerator.new(seed_value, "Pat Doe")
		for day in range(1, 8):
			for c in gen.generate_day(day):
				for v in RuleChecker.violations(c, 7):
					checked += 1
					for key: String in v["evidence"]:
						t.ok(not key.begins_with("exhibit."), "seed %d %s: %s cites %s" % [seed_value, c.claim_no, v["rule"], key])
				for i in (c.exhibit.get("rows", []) as Array).size():
					for rule_id in Rules.unlocked(7):
						t.ok(not RuleChecker.check_citation(c, rule_id, "exhibit.%d" % i, 7), "%s exhibit row %d cites %s" % [c.scripted_id, i, rule_id])
	t.ok(checked > 500, "violations checked: %d" % checked)


# --- the discontent meter ---------------------------------------------------------

func test_the_meter_explains_itself() -> void:
	var meter := DiscontentMeter.new()
	await _place(meter)
	t.eq(meter.mouse_filter, Control.MOUSE_FILTER_PASS, "hoverable")
	meter.set_value(33.0, false)
	t.ok(meter.tooltip_text.begins_with("PUBLIC DISCONTENT 33%"), meter.tooltip_text)
	t.ok(meter.tooltip_text.contains("100%"), "names the end")
	for threshold in Economy.THRESHOLDS:
		t.ok(meter.tooltip_text.contains("\n%d%%  " % threshold), "names the %d%% threshold" % threshold)
	t.ok(meter.tooltip_text.contains("-%d%% each night" % roundi(Economy.NIGHT_DECAY)), "the overnight easing")
	t.ok(meter.tooltip_text.contains("adds %d%% more" % roundi(Economy.PROTEST_EXTRA)), "the protest penalty")
	meter.set_value(47.6, false)
	t.ok(meter.tooltip_text.begins_with("PUBLIC DISCONTENT 48%"), "refreshed on every set_value")


func test_the_meter_blinks_what_changed() -> void:
	var meter := DiscontentMeter.new()
	await _place(meter)
	meter.set_value(29.0)
	t.ok(not meter.is_tick_blinking(30), "no tick before crossing")
	meter.set_value(31.0, true)
	t.ok(meter.is_tick_blinking(30), "crossing 30 blinks its tick")
	t.ok(not meter.is_tick_blinking(55), "only the crossed one")
	t.ok(meter.is_segment_blinking(), "the new segment blinks")
	await tree.create_timer(1.0).timeout
	t.ok(not meter.is_tick_blinking(30) and not meter.is_segment_blinking(), "three blinks, then steady")
	meter.set_value(20.0, true)
	t.ok(not meter.is_segment_blinking(), "a fall doesn't blink")
	meter.set_value(91.0)
	t.ok(meter.blinking, "at 91 the border beats")
	meter.set_value(85.0)
	t.ok(not meter.blinking, "below 90 it stops")
	meter.set_value(95.0, false)
	t.ok(meter.blinking, "even when set without animation")


## From 90% the border beats between 2 and 4 px at 1.5 Hz: thick for the first
## half of each 2/3 s period, thin for the second. Read at set times.
func test_the_meter_border_beats_at_one_and_a_half_hertz() -> void:
	var meter := DiscontentMeter.new()
	await _place(meter)
	meter.set_value(50.0, false)
	t.eq(meter.border_width(), 2.0, "below 90: a plain 2 px border")
	meter.set_value(91.0, false)
	var period := 1.0 / DiscontentMeter.BORDER_HZ
	t.near(period, 2.0 / 3.0, 0.0001)
	for k in 3:
		for phase: float in [0.05, 0.25, 0.45]:
			meter._time = k * period + phase * period
			t.eq(meter.border_width(), 4.0, "thick at %.2f s" % meter._time)
		for phase: float in [0.55, 0.75, 0.95]:
			meter._time = k * period + phase * period
			t.eq(meter.border_width(), 2.0, "thin at %.2f s" % meter._time)
	# And as it runs: both widths turn up within one period.
	var seen := {}
	var until := Time.get_ticks_msec() + int(period * 1000.0 * 1.5)
	while Time.get_ticks_msec() < until:
		seen[meter.border_width()] = true
		await tree.process_frame
	t.ok(seen.has(2.0) and seen.has(4.0), "beats while running: %s" % [seen.keys()])
	Engine.set_meta("reduce_motion", true)
	for time: float in [0.1, 0.4, 0.5, 0.9]:
		meter._time = time
		t.eq(meter.border_width(), 4.0, "reduce_motion: a steady 4 px at %.1f s" % time)
	meter.set_value(85.0, false)
	t.eq(meter.border_width(), 2.0, "and back to 2 px below 90")


## Under reduce_motion the new segment and a crossed tick show lit and steady for
## as long as they would have blinked, instead of flashing.
func test_the_meter_does_not_flash_under_reduce_motion() -> void:
	var meter := DiscontentMeter.new()
	await _place(meter)
	meter.set_value(29.0, false)
	meter.set_value(31.0, true)
	var start := meter._time
	var widths := {}
	var segment := {}
	for step in 6:
		meter._time = start + 0.05 + step * DiscontentMeter.BLINK_PERIOD / 4.0
		widths[meter.tick_width(30)] = true
		segment[meter.is_segment_lit()] = true
	t.ok(widths.has(2.0) and widths.has(4.0), "normally the tick flashes: %s" % [widths.keys()])
	t.ok(segment.has(true) and segment.has(false), "and so does the new segment")
	Engine.set_meta("reduce_motion", true)
	meter.set_value(20.0, false)
	meter.set_value(31.0, true)
	start = meter._time
	for step in 6:
		meter._time = start + 0.05 + step * DiscontentMeter.BLINK_PERIOD / 4.0
		var at := meter._time - start
		t.eq(meter.tick_width(30), 4.0, "reduce_motion: the crossed tick stays lit at +%.2f s" % at)
		t.ok(meter.is_segment_blinking() and meter.is_segment_lit(), "and the new segment stays lit at +%.2f s" % at)
	meter._time = start + DiscontentMeter.TICK_BLINKS * DiscontentMeter.BLINK_PERIOD + 0.01
	t.eq(meter.tick_width(30), 2.0, "then the tick goes back to normal")
	t.ok(not meter.is_segment_lit(), "and so does the segment")


# --- desk props --------------------------------------------------------------------

func _all_controls(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child in node.get_children():
		if child is Control:
			found.append(child as Control)
		found.append_array(_all_controls(child))
	return found


func test_the_desk_props_remember_the_week() -> void:
	var run := RunState.create("Pat Doe", 9)
	run.day = 6
	run.member("mother")["alive"] = false
	var props := DeskProps.create(run)
	await _place(props)
	t.eq(props.size, Vector2(1360, 864))
	t.eq(props.ribbons, 1, "one ribbon for Mom")
	var drawn := props.find_children("Ribbon*", "", true, false)
	t.eq(drawn.size(), 1, "exactly one drawn")
	var holders := _face_holders(props)
	t.eq(holders.size(), 3, "three pictures in the frame")
	if drawn.size() == 1 and holders.size() == 3:
		t.ok(drawn[0].get_parent() == holders[2], "the ribbon is on the third picture, Mom's: %s" % drawn[0].get_parent().name)
		t.eq(_faces(holders[2])[0]._age, 68, "the picture of the 68-year-old")
	t.eq(props.rings.size(), 5, "day 6: five coffee rings")
	t.eq(props.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var controls := _all_controls(props)
	t.ok(controls.size() > 5, "props found: %d" % controls.size())
	for c in controls:
		t.eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % c.name)
	for c in props.get_children():
		if c is DeskProps.CoffeeRings:
			continue
		# Every corner, as drawn (the photo is tilted).
		var prop := c as Control
		var xform := prop.get_global_transform()
		for corner: Vector2 in [Vector2.ZERO, Vector2(prop.size.x, 0), prop.size, Vector2(0, prop.size.y)]:
			var at := xform * corner
			t.ok(at.y >= DeskProps.STRIP_TOP and at.y <= DESK_H and at.x >= 0.0 and at.x <= props.size.x, "%s corner %s sits in the bottom strip" % [prop.name, at])
	for spot in props.rings:
		t.ok(spot.y - DeskProps.RING_RADIUS >= DeskProps.STRIP_TOP and spot.y + DeskProps.RING_RADIUS <= DESK_H, "ring at %s stays in the strip" % spot)
	var faces := _faces(props)
	t.eq(faces.size(), 3, "Sam, Riley and Mom")
	var ages: Array[int] = []
	for face in faces:
		ages.append(face._age)
		t.ok(not face._sick, "healthy in the photo")
		t.eq(face._mood, PortraitView.Mood.RELIEVED, "smiling")
	t.eq(ages, [38, 9, 68] as Array[int])


func test_the_desk_props_grow_by_day_and_otherwise_never_change() -> void:
	var run := RunState.create("Pat Doe", 9)
	run.day = 1
	var first := DeskProps.create(run)
	t.eq(first.rings.size(), 0, "no rings on the first morning")
	t.eq(first.ribbons, 0, "nobody has died")
	first.free()
	run.day = 7
	var last := DeskProps.create(run)
	t.eq(last.calendar_text(), "SUN 8", "the calendar shows today")
	t.eq(last.rings.size(), 6)
	run.day = 6
	var before := DeskProps.create(run)
	t.eq(last.rings.slice(0, 5), before.rings, "yesterday's rings stay where they were")
	for m: Dictionary in run.family:
		m["alive"] = false
	var all_gone := DeskProps.create(run)
	t.eq(all_gone.ribbons, 3)
	t.eq(all_gone.find_children("Ribbon*", "", true, false).size(), 3)
	for holder in _face_holders(all_gone):
		t.eq(holder.find_children("Ribbon*", "", true, false).size(), 1, "one ribbon on %s" % holder.name)
	for node: Node in [last, before, all_gone]:
		node.free()


## The photo's pictures, left to right: the holders each face sits in.
func _face_holders(props: DeskProps) -> Array[Control]:
	var found: Array[Control] = []
	var frame := props.find_child("FamilyPhoto", false, false)
	if frame == null:
		return found
	for child in frame.get_children():
		if not _faces(child).is_empty():
			found.append(child as Control)
	found.sort_custom(func(a: Control, b: Control) -> bool: return a.position.x < b.position.x)
	return found


## A ribbon marks the person who died, never whoever sits in the first corner.
func test_a_ribbon_goes_on_the_picture_of_whoever_died() -> void:
	var ages := {"partner": 38, "child": 9, "mother": 68}
	for id: String in ["partner", "child", "mother"]:
		var run := RunState.create("Pat Doe", 9)
		run.day = 5
		run.member(id)["alive"] = false
		var props := DeskProps.create(run)
		await _place(props)
		var drawn := props.find_children("Ribbon*", "", true, false)
		t.eq(drawn.size(), 1, "%s died: one ribbon" % id)
		if drawn.size() != 1:
			continue
		var faces := _faces(drawn[0].get_parent())
		t.ok(faces.size() == 1 and faces[0]._age == ages[id], "%s: the ribbon is on the picture of the %d-year-old" % [id, ages[id]])
		var holder := drawn[0].get_parent() as Control
		t.ok(holder.clip_contents, "%s: clipped to that picture" % id)
		var ribbon := drawn[0] as Control
		t.eq(ribbon.size, holder.size, "%s: drawn across that picture's corner" % id)
		t.eq(ribbon.mouse_filter, Control.MOUSE_FILTER_IGNORE)


## Coffee rings are faint stains, not drawn circles: two or three broken arcs and
## one darker arc each, and a ring looks the same every day.
func test_coffee_rings_are_faint_broken_stains() -> void:
	var run := RunState.create("Pat Doe", 9)
	run.day = 7
	var props := DeskProps.create(run)
	_nodes.append(props)
	var layer: DeskProps.CoffeeRings = props.find_child("CoffeeRings", false, false)
	t.ok(layer != null, "the ring layer")
	if layer == null:
		return
	for i in props.rings.size():
		var arcs := layer.ring_arcs(i)
		t.ok(arcs.size() >= 3 and arcs.size() <= 4, "ring %d: two or three arcs and a dark one (%d)" % [i, arcs.size()])
		var covered := 0.0
		for k in arcs.size() - 1:
			var arc: Dictionary = arcs[k]
			covered += float(arc["to"]) - float(arc["from"])
			t.ok(float(arc["alpha"]) >= 0.2 and float(arc["alpha"]) <= 0.3, "ring %d arc %d is faint: %.2f" % [i, k, arc["alpha"]])
			t.ok(absf(float(arc["radius"]) - DeskProps.RING_RADIUS) <= 2.0, "ring %d arc %d radius" % [i, k])
		t.ok(covered < TAU - 0.5, "ring %d is broken: %.2f of %.2f" % [i, covered, TAU])
		var dark: Dictionary = arcs[arcs.size() - 1]
		t.ok(float(dark["alpha"]) > 0.3 and float(dark["alpha"]) <= 0.45, "ring %d has one darker arc" % i)
		t.ok(float(dark["to"]) - float(dark["from"]) < PI / 2.0, "a short one")
	run.day = 4
	var earlier := DeskProps.create(run)
	_nodes.append(earlier)
	var earlier_layer: DeskProps.CoffeeRings = earlier.find_child("CoffeeRings", false, false)
	for i in earlier.rings.size():
		t.eq(earlier_layer.ring_arcs(i), layer.ring_arcs(i), "ring %d looks the same on day 4 and day 7" % i)
