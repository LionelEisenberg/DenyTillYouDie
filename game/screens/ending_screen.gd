class_name EndingScreen
extends ScreenBase
## The last front page, what became of everyone, and one last document. Paged
## like the memo: NEXT PAGE, NEXT PAGE, then RETURN TO TITLE, with a retry of
## the morning that was lost beside it. Every page is built up front.

const PAGE_W := 1400.0
const TEXT_W := 1320.0
const STORY_W := 820.0
const STORY_W_WITH_PHOTO := 640.0
const PHOTO_BLOCK := 3
const CAPTION_W := 170.0
## Kept clear at the bottom of the screen for the button bar.
const BAR_H := 120.0
const STAMP_TURN := -12.0
## R.H.'s note on Monday's claim: it covers this much of the form's top-right
## corner, from this far above the form's top edge.
const NOTE_OVERLAP := 100.0
const NOTE_LIFT := 70.0

var page: Dictionary = {}
## Front page, ALSO IN TODAY'S LEDGER, then the document.
var pages: Array[Control] = []
## Every halftone photo on these pages.
var photos: Array[NewsPhoto] = []
## The stamp on Harbor Point's statement (FIRED only).
var stamp: StampMark
## The claim form and R.H.'s note on it (TAKEN CARE OF only).
var claim_form: Control
var claim_note: Control
var _page_index := 0
## The paging button: NEXT PAGE, then RETURN TO TITLE. Focused by on_shown().
var _back: Button
var _retry: Button
var _record: Label
var _retry_day := 0


func _ready() -> void:
	var run := GameState.run
	page = Endings.build(run, run.ending)
	var bg := UiTheme.rect(Palette.BG_DARK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_lamp_pool()
	pages.append(_front_page(run))
	pages.append(_inside_page(run))
	pages.append(_document_page())
	for p in pages:
		add_child(p)
	add_child(_button_bar())
	_show_page(0)


func on_shown() -> void:
	_back.grab_focus()


func _advance() -> void:
	if _page_index < pages.size() - 1:
		Sfx.play("paper")
		_show_page(_page_index + 1)
	else:
		finish({})


func _show_page(index: int) -> void:
	_page_index = index
	for i in pages.size():
		pages[i].visible = i == index
	var last := index == pages.size() - 1
	# Newspaper pages land like the paper; the document slides across the table.
	sheet_entrance(pages[index], "slide" if last else "drop")
	_back.text = "RETURN TO TITLE" if last else "NEXT PAGE"
	_retry.visible = last and _retry_day > 0
	_record.visible = last


func _button_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.position = Vector2(60, 1080 - 96)
	bar.size = Vector2(1920 - 120, 48)
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 24)
	_record = UiTheme.label("OUTCOME %d OF %d ON FILE" % [GameState.outcomes_on_file(), Endings.ALL.size()], UiTheme.SIZE_SMALL, Palette.TEXT_LIGHT)
	_record.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_record.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_record)
	_retry_day = GameState.retry_day()
	var weekday := DateUtil.weekday(DateUtil.game_date(clampi(_retry_day, 1, 7))).to_upper()
	_retry = UiTheme.button("RETRY DAY %d (%s MORNING)" % [_retry_day, weekday], UiTheme.SIZE_BODY, 440)
	_retry.pressed.connect(func() -> void: finish({"action": "retry", "day": _retry_day}))
	bar.add_child(_retry)
	_back = UiTheme.button("", UiTheme.SIZE_BODY, 320)
	_back.pressed.connect(_advance)
	bar.add_child(_back)
	return bar


## A full-window page with a CenterContainer (its first child) that keeps the
## sheet clear of the button bar.
func _page_holder() -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -BAR_H
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(center)
	return holder


# --- page 1: the front page ------------------------------------------------

func _front_page(run: RunState) -> Control:
	var holder := _page_holder()
	var column := sheet_in(holder.get_child(0), PAGE_W, Palette.NEWSPRINT)
	NewspaperScreen.build_masthead(column, DateUtil.fmt_long(Endings.morning_after(run)))
	var paper: Dictionary = page.get("paper", {})
	column.add_child(UiTheme.para(String(paper.get("headline", "")).to_upper(), TEXT_W, UiTheme.SIZE_BIG, Palette.INK))
	column.add_child(UiTheme.para(String(paper.get("sub", "")), TEXT_W, UiTheme.SIZE_BODY, Palette.INK_FADED))
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 40)
	column.add_child(body)
	var story_w := STORY_W
	if page.has("photo"):
		body.add_child(_photo_column(page["photo"]))
		story_w = STORY_W_WITH_PHOTO
	var story := VBoxContainer.new()
	story.add_theme_constant_override("separation", 12)
	var survived: bool = page.get("survived", true)
	story.add_child(UiTheme.label(String(page.get("title", "")), UiTheme.SIZE_BIG, Palette.INK if survived else Palette.RED_DARK))
	for line: String in page.get("epilogue", []):
		story.add_child(UiTheme.para(line, story_w, UiTheme.SIZE_BODY, Palette.INK))
	body.add_child(story)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 24)
	stats.add_theme_constant_override("v_separation", 6)
	for pair: Array in page.get("stats", []):
		stats.add_child(UiTheme.label(String(pair[0]).to_upper(), UiTheme.SIZE_SMALL, Palette.INK_FADED))
		stats.add_child(UiTheme.label(String(pair[1]), UiTheme.SIZE_BODY, Palette.INK))
	var stats_box := VBoxContainer.new()
	stats_box.add_child(UiTheme.label("THE WEEK IN NUMBERS", UiTheme.SIZE_BODY, Palette.INK))
	stats_box.add_child(stats)
	body.add_child(stats_box)
	return holder


## The photo the paper ran: a brass-framed one for the late Employee of the
## Month, a thin rule for the rest, with its caption.
func _photo_column(photo: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var outfit := String(photo.get("outfit", ""))
	var p := NewsPhoto.halftone(int(photo.get("seed", 0)), int(photo.get("age", 41)), PHOTO_BLOCK, outfit == "gown")
	if outfit == "suit":
		p.dress_suit()
	photos.append(p)
	if String(photo.get("frame", "")) == "brass":
		col.add_child(NewsPhoto.in_frame(p, Palette.PAPER_SHADE, Palette.AMBER, 6, 10))
	else:
		col.add_child(NewsPhoto.in_frame(p, Palette.NEWSPRINT, Palette.INK_FADED, 2, 0))
	var caption := String(photo.get("caption", ""))
	if caption != "":
		col.add_child(UiTheme.para(caption, CAPTION_W, UiTheme.SIZE_SMALL, Palette.INK_FADED))
	return col


# --- page 2: also in today's ledger ----------------------------------------

func _inside_page(run: RunState) -> Control:
	var holder := _page_holder()
	var column := sheet_in(holder.get_child(0), PAGE_W, Palette.NEWSPRINT)
	var strip := HBoxContainer.new()
	var paper_name := UiTheme.label("THE DAILY LEDGER", UiTheme.SIZE_BODY, Palette.INK)
	paper_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(paper_name)
	strip.add_child(UiTheme.label(DateUtil.fmt_long(Endings.morning_after(run)).to_upper() + "   PAGE 2", UiTheme.SIZE_SMALL, Palette.INK))
	column.add_child(strip)
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 4)))
	column.add_child(UiTheme.label("ALSO IN TODAY'S LEDGER", UiTheme.SIZE_BIG, Palette.INK))
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))
	column.add_child(UiTheme.label("FOLLOW-UPS", UiTheme.SIZE_BODY, Palette.INK))
	var lines: PackedStringArray = page.get("follow_ups", PackedStringArray())
	if lines.is_empty():
		column.add_child(UiTheme.para("Nothing further to report.", TEXT_W, UiTheme.SIZE_SMALL, Palette.INK))
	else:
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", 48)
		var half := ceili(lines.size() / 2.0)
		var col_w := (TEXT_W - 48) / 2.0
		for side in 2:
			var briefs := VBoxContainer.new()
			briefs.add_theme_constant_override("separation", 10)
			for i in range(side * half, mini((side + 1) * half, lines.size())):
				briefs.add_child(UiTheme.para(lines[i], col_w, UiTheme.SIZE_SMALL, Palette.INK))
				briefs.add_child(UiTheme.rect(Palette.PAPER_SHADE, Vector2(col_w, 1)))
			columns.add_child(briefs)
		column.add_child(columns)
	if page.has("obituaries"):
		column.add_child(UiTheme.rect(Color(0, 0, 0, 0), Vector2(0, 8)))
		column.add_child(UiTheme.label("THIS WEEK'S OBITUARIES", UiTheme.SIZE_TITLE, Palette.INK))
		column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))
		column.add_child(UiTheme.para(String(page["obituaries"]), TEXT_W, UiTheme.SIZE_BODY, Palette.INK))
	return holder


# --- page 3: the last document ---------------------------------------------

func _document_page() -> Control:
	var holder := _page_holder()
	var center: Control = holder.get_child(0)
	var doc: Dictionary = page.get("document", {})
	match String(doc.get("kind", "")):
		"memo":
			_memo_document(center, doc)
		"plaque":
			_plaque_document(center, doc)
		"statement":
			_statement_document(center, doc)
		"notice":
			_notice_document(center, doc)
		"claim_note":
			_claim_note_document(center, doc)
	return holder


## A memo laid out like the morning memos: header, TO/FROM/DATE/RE, signature.
func _memo_document(center: Control, doc: Dictionary) -> void:
	var column := sheet_in(center, 1100, Palette.MEMO)
	column.add_theme_constant_override("separation", 10)
	column.add_child(UiTheme.label("BENEVOLENCE MUTUAL  -  INTERNAL MEMORANDUM", UiTheme.SIZE_TITLE, Palette.INK))
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))
	for pair: Array in [["TO", doc.get("to", "")], ["FROM", doc.get("from", "")], ["DATE", doc.get("date", "")], ["RE", doc.get("subject", "")]]:
		var row := HBoxContainer.new()
		var cap := UiTheme.label(pair[0], UiTheme.SIZE_SMALL, Palette.INK_FADED)
		cap.custom_minimum_size = Vector2(90, 0)
		row.add_child(cap)
		row.add_child(UiTheme.label(String(pair[1]), UiTheme.SIZE_BODY, Palette.INK))
		column.add_child(row)
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))
	for paragraph: String in doc.get("paragraphs", []):
		column.add_child(UiTheme.para(paragraph, 1020, UiTheme.SIZE_BODY, Palette.INK))
	column.add_child(UiTheme.label(String(doc.get("signature", "")), UiTheme.SIZE_TITLE, Palette.INK_BLUE))


## The break-room plaque: dark wood, brass plates, your photo, and the bill.
func _plaque_document(center: Control, doc: Dictionary) -> void:
	var wood := UiTheme.paper_box(Palette.DESK_DARK, Palette.DESK_LIGHT, 0)
	wood.set_border_width_all(8)
	wood.content_margin_left = 64
	wood.content_margin_right = 64
	wood.content_margin_top = 40
	wood.content_margin_bottom = 40
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", wood)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)
	column.add_child(_brass_plate([UiTheme.label(String(doc.get("title", "")), UiTheme.SIZE_TITLE, Palette.INK)]))
	var p := NewsPhoto.halftone(int(doc.get("photo_seed", 0)), int(doc.get("photo_age", 41)), PHOTO_BLOCK)
	photos.append(p)
	var photo_row := CenterContainer.new()
	photo_row.add_child(NewsPhoto.in_frame(p, Palette.PAPER_SHADE, Palette.AMBER, 6, 10))
	column.add_child(photo_row)
	column.add_child(_brass_plate([
		_centered(UiTheme.label(String(doc.get("name", "")), UiTheme.SIZE_BIG, Palette.INK)),
		_centered(UiTheme.label(String(doc.get("desk", "")), UiTheme.SIZE_BODY, Palette.INK)),
	]))
	column.add_child(_centered(UiTheme.label(String(doc.get("engraving", "")), UiTheme.SIZE_BODY, Palette.AMBER)))
	# Facilities' note, stuck on the frame's bottom corner and hanging off it.
	var corner := HBoxContainer.new()
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corner.add_child(spacer)
	corner.add_child(_stuck(_sticky(String(doc.get("note", ""))), Vector2(-40, 4), 5.0))
	column.add_child(corner)


func _brass_plate(children: Array) -> Control:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.flat_box(Palette.AMBER, Palette.AMBER.darkened(0.35), 3, 24, 8))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	for c: Control in children:
		inner.add_child(c)
	plate.add_child(inner)
	var row := CenterContainer.new()
	row.add_child(plate)
	return row


## Harbor Point's itemized statement for your own claim, coverage rescinded.
func _statement_document(center: Control, doc: Dictionary) -> void:
	var column := sheet_in(center, 760, Palette.PAPER_ALT)
	column.add_theme_constant_override("separation", 6)
	column.add_child(_centered(UiTheme.label(String(doc.get("provider", "")), UiTheme.SIZE_TITLE, Palette.INK)))
	column.add_child(_centered(UiTheme.label("ITEMIZED STATEMENT", UiTheme.SIZE_SMALL, Palette.INK_FADED)))
	column.add_child(UiTheme.rect(Palette.PAPER_SHADE, Vector2(0, 2)))
	for pair: Array in [["PATIENT", doc.get("patient", "")], ["ACCOUNT", doc.get("account", "")], ["DATE OF SERVICE", doc.get("service_date", "")]]:
		var row := HBoxContainer.new()
		var cap := UiTheme.label(pair[0], UiTheme.SIZE_SMALL, Palette.INK_FADED)
		cap.custom_minimum_size = Vector2(220, 0)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cap)
		row.add_child(UiTheme.label(String(pair[1]), UiTheme.SIZE_BODY, Palette.INK))
		column.add_child(row)
	column.add_child(UiTheme.rect(Palette.PAPER_SHADE, Vector2(0, 2)))
	for line: Array in doc.get("lines", []):
		column.add_child(_amount_row(String(line[0]), int(line[1]), UiTheme.SIZE_BODY, Palette.INK))
	# RESCINDED in big type over COVERAGE, the way a DENIED stamp sits over
	# its reason code.
	stamp = StampMark.create(false, String(doc.get("stamp_code", "")))
	stamp.word = String(doc.get("stamp", ""))
	# Over the blank middle of the line items, clear of the amounts.
	column.add_child(_stuck(stamp, Vector2(250, -140), STAMP_TURN))
	column.add_child(UiTheme.rect(Palette.PAPER_SHADE, Vector2(0, 2)))
	var balance := int(doc.get("balance", 0))
	column.add_child(_amount_row("TOTAL CHARGES", balance, UiTheme.SIZE_BODY, Palette.INK))
	column.add_child(_amount_row("PAID BY INSURANCE", 0, UiTheme.SIZE_BODY, Palette.INK))
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))
	var due := UiTheme.label("BALANCE DUE: %s" % Fmt.money(balance), UiTheme.SIZE_BIG, Palette.RED_DARK)
	due.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(due)
	column.add_child(UiTheme.para("Payment is due within 30 days. Unpaid balances are referred to collections.", 680, UiTheme.SIZE_SMALL, Palette.INK_FADED))


## The landlord's notice, with what you were short.
func _notice_document(center: Control, doc: Dictionary) -> void:
	var column := sheet_in(center, 960, Palette.PAPER)
	column.add_theme_constant_override("separation", 14)
	column.add_child(_centered(UiTheme.label(String(doc.get("title", "")), UiTheme.SIZE_TITLE, Palette.INK)))
	column.add_child(UiTheme.rect(Palette.INK, Vector2(0, 2)))
	var final_notice := UiTheme.label("FINAL NOTICE", UiTheme.SIZE_TITLE, Palette.RED)
	final_notice.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0, 0, 0, 0), Palette.RED, 3, 12, 4))
	var date_row := HBoxContainer.new()
	var date := UiTheme.label("DATE  %s" % String(doc.get("date", "")), UiTheme.SIZE_SMALL, Palette.INK_FADED)
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_row.add_child(date)
	date_row.add_child(_stuck(final_notice, Vector2(-250, -6), -6.0))
	column.add_child(date_row)
	column.add_child(UiTheme.para("To the tenants of Unit 4B:", 880, UiTheme.SIZE_BODY, Palette.INK))
	column.add_child(UiTheme.para("You are in default of your lease for nonpayment of rent.", 880, UiTheme.SIZE_BODY, Palette.INK))
	column.add_child(UiTheme.label("Amount past due: %s" % Fmt.money(int(doc.get("amount", 0))), UiTheme.SIZE_TITLE, Palette.RED_DARK))
	column.add_child(UiTheme.para("You must vacate the premises by noon on the 15th. Contents remaining after that date will be removed and disposed of.", 880, UiTheme.SIZE_BODY, Palette.INK))
	column.add_child(UiTheme.label("Calloway Street Properties, Management", UiTheme.SIZE_BODY, Palette.INK_FADED))


## Monday's first claim, with R.H.'s note stuck on its top-right corner, above
## and past the form so the header stays readable.
func _claim_note_document(center: Control, doc: Dictionary) -> void:
	var c: Claim = doc.get("claim")
	if c == null:
		return
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(holder)
	claim_form = Paperwork.claim_form(c)
	claim_form.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(claim_form)
	claim_note = Paperwork.sticky_note(String(doc.get("note", "")))
	claim_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(claim_note)
	# Both size themselves once laid out; the holder follows so the pair stays
	# centered as one piece.
	var form := claim_form
	var note := claim_note
	var fit := func() -> void:
		form.position = Vector2(0, NOTE_LIFT)
		note.position = Vector2(form.size.x - NOTE_OVERLAP, 0)
		holder.custom_minimum_size = Vector2(note.position.x + note.size.x, NOTE_LIFT + form.size.y)
	form.resized.connect(fit)
	note.resized.connect(fit)
	fit.call()


func _sticky(text: String) -> Control:
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", UiTheme.paper_box(Palette.HIGHLIGHT, Palette.AMBER, 14))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(UiTheme.label(text, UiTheme.SIZE_BODY, Palette.INK_BLUE))
	return note


## `child` placed at `offset` from a zero-size holder and turned `degrees`, so it
## overlaps whatever it is laid out beside (containers reset rotation).
func _stuck(child: Control, offset: Vector2, degrees: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	child.position = offset
	child.rotation_degrees = degrees
	holder.add_child(child)
	return holder


func _amount_row(text: String, amount: int, font_size: int, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := UiTheme.label(text, font_size, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	row.add_child(UiTheme.label(Fmt.money(amount), font_size, color))
	return row


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
