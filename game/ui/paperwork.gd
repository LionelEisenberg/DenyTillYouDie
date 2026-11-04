class_name Paperwork
## Builds the documents for one patient. Every visible fact is a citable row, so
## which rows are clickable never gives the answer away. Evidence is set at
## SIZE_BODY: 16 px text is unreadable once the canvas is scaled to the window.

const BLANK := "__________"
## A scripted patient's personal paper: this wide, tilted this much, and no
## taller than EXHIBIT_MAX_H (a letter, EXHIBIT_LETTER_MAX_H).
const EXHIBIT_WIDTH := 380.0
const EXHIBIT_TILT := 2.0
const EXHIBIT_MAX_H := 220.0
const EXHIBIT_LETTER_MAX_H := 300.0
const EXHIBIT_PAD := 14
## A staff badge photo: a PortraitView at this scale (8 px blocks become 2 px).
const BADGE_PHOTO_SCALE := 0.25


static func claim_form(c: Claim) -> DocumentView:
	var d := DocumentView.new()
	d.set_paper(Palette.PAPER, 500)
	d.add_title("BENEVOLENCE MUTUAL", UiTheme.SIZE_BODY)
	d.add_text("CLAIM FOR BENEFITS  -  FORM BM-1500").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_rule()
	d.add_field("CLAIM NO.", c.claim_no, "claim.claim_no")
	d.add_field("PATIENT", c.name, "claim.name")
	d.add_field("DATE OF BIRTH", DateUtil.fmt(c.dob), "claim.dob")
	d.add_field("MEMBER ID", c.member_id, "claim.member_id")
	d.add_field("PROVIDER", c.provider, "claim.provider")
	d.add_field("DATE OF SERVICE", DateUtil.fmt(c.date_of_service), "claim.date_of_service")
	d.add_field("DIAGNOSIS", c.diagnosis, "claim.diagnosis")
	if c.shows_bill():
		d.add_field("TREATMENT", "See itemized bill", "claim.treatment", Palette.INK_FADED)
	else:
		d.add_field("TREATMENT", c.treatment_summary(), "claim.treatment")
	d.add_field("AMOUNT", UiTheme.money(c.amount), "claim.amount")
	d.add_field("PRIORITY", c.priority_name(), "claim.priority", priority_color(c.priority))
	if c.shows_bill():
		d.add_field("PRIOR AUTH #", c.prior_auth if c.prior_auth != "" else BLANK, "claim.prior_auth")
	return d


static func member_card(c: Claim) -> DocumentView:
	var d := DocumentView.new()
	d.is_card = true
	d.set_paper(Palette.CARD, 380, Palette.CARD_BAND)
	var band := PanelContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_theme_stylebox_override("panel", UiTheme.flat_box(Palette.CARD_BAND, Palette.CARD_BAND, 0, 10, 4))
	var band_text := UiTheme.label("BENEVOLENCE MUTUAL  -  MEMBER CARD", UiTheme.SIZE_SMALL, Palette.CARD)
	band_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.add_child(band_text)
	d.body.add_child(band)
	d.add_space(4)
	d.add_field("NAME", c.card_name, "card.name")
	d.add_field("MEMBER ID", c.card_member_id, "card.member_id")
	d.add_field("DATE OF BIRTH", DateUtil.fmt(c.card_dob), "card.dob")
	d.add_field("PLAN", c.plan, "card.plan")
	d.add_field("MEMBER SINCE", DateUtil.fmt(c.member_since), "card.member_since")
	d.add_field("COVERAGE THROUGH", DateUtil.fmt(c.coverage_through), "card.coverage_through")
	d.add_text("We care.*   *Terms, conditions and exclusions apply.")
	return d


static func itemized_bill(c: Claim) -> DocumentView:
	var d := DocumentView.new()
	d.set_paper(Palette.PAPER_ALT, 380)
	d.add_field("", c.provider, "bill.provider", Palette.INK, UiTheme.SIZE_BODY)
	d.add_text("ITEMIZED STATEMENT")
	d.add_field("PATIENT", c.name, "bill.patient")
	d.add_field("SERVICE DATE", DateUtil.fmt(c.date_of_service), "bill.date_of_service")
	d.add_rule()
	for i in c.bill_lines.size():
		var line := c.bill_lines[i]
		d.add_line_item(line["label"], UiTheme.money(int(line["cost"])), "bill.line.%d" % i)
	d.add_rule()
	d.add_line_item("TOTAL DUE", UiTheme.money(c.bill_total()), "bill.total", UiTheme.SIZE_TITLE, UiTheme.SIZE_TITLE)
	return d


static func medical_history(c: Claim) -> DocumentView:
	var d := DocumentView.new()
	d.set_paper(Palette.PAPER, 400)
	d.add_title("MEDICAL HISTORY", UiTheme.SIZE_BODY)
	d.add_text("Records release on file.").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_field("PATIENT", c.card_name, "history.name")
	d.add_field("DATE OF BIRTH", DateUtil.fmt(c.card_dob), "history.dob")
	d.add_rule()
	for i in c.history.size():
		var entry := c.history[i]
		d.add_dated_item(DateUtil.fmt(int(entry["date"])), entry["label"], "history.entry.%d" % i)
	return d


## The pink slip for approving a claim that had valid grounds for denial. Its
## message is set at SIZE_BODY like evidence; only the sign-off is fine print.
## The wording follows ShiftLogic: the free warnings reset each day, and the
## citations after them are fined.
static func citation_slip(warning: int, fine: int) -> DocumentView:
	var d := DocumentView.new()
	d.set_paper(Palette.PINK_SLIP, 340, Palette.RED_DARK)
	d.add_title("CITATION", UiTheme.SIZE_TITLE, Palette.RED_DARK)
	d.add_text("Approved a claim with valid grounds for denial.", UiTheme.SIZE_BODY, Palette.INK)
	if fine > 0:
		d.add_text("Fine deducted: %s." % UiTheme.money(fine), UiTheme.SIZE_BODY, Palette.RED_DARK)
	elif warning < Economy.FREE_WARNINGS:
		d.add_text("Warning %d of %d today." % [warning, Economy.FREE_WARNINGS], UiTheme.SIZE_BODY, Palette.INK)
	else:
		d.add_text("Warning %d of %d today. Further citations will be fined %s." % [warning, Economy.FREE_WARNINGS, UiTheme.money(Economy.CITATION_FINE)], UiTheme.SIZE_BODY, Palette.INK)
	d.add_text("-Claims Integrity", UiTheme.SIZE_SMALL, Palette.INK_FADED)
	return d


## The one personal paper a scripted patient brings (an ICU log, a doctor's
## letter, a staff badge, an ultrasound), or null. Its rows look as citable as
## any other, so clicking about never gives away what counts; none of them ever
## does (RuleChecker never names an "exhibit." key).
static func exhibit(c: Claim) -> DocumentView:
	var ex := c.exhibit
	if ex.is_empty():
		return null
	var d := DocumentView.new()
	match String(ex.get("kind", "log")):
		"badge":
			_badge(d, c, ex)
		"letter":
			_letter(d, ex)
		_:
			_log(d, ex)
	d.rotation_degrees = EXHIBIT_TILT
	return d


## A typed record: an institution's heading, dated or captioned rows, and a
## handwritten note at the bottom when there is one.
static func _log(d: DocumentView, ex: Dictionary) -> void:
	_exhibit_paper(d, Palette.PAPER_ALT, Palette.PAPER_SHADE)
	d.add_title(String(ex.get("title", "")), UiTheme.SIZE_SMALL)
	_subtitle(d, ex)
	if String(ex.get("image", "")) == "ultrasound":
		# The screen prints the heart rate the report states, from its own row.
		d.body.add_child(UltrasoundScan.new(_row_value(ex.get("rows", []), "FETAL HEART RATE")))
	d.add_rule()
	_exhibit_rows(d, d.body, ex.get("rows", []))
	if String(ex.get("body", "")) != "":
		d.add_text(String(ex["body"]), UiTheme.SIZE_BODY, Palette.INK_BLUE)
	_signature(d, ex)


## A letter on letterhead, signed by hand. The letter itself is set at
## SIZE_BODY: it is the part meant to be read, on a tilted sheet.
static func _letter(d: DocumentView, ex: Dictionary) -> void:
	_exhibit_paper(d, Palette.PAPER, Palette.PAPER_SHADE)
	d.add_title(String(ex.get("title", "")), UiTheme.SIZE_BODY)
	_subtitle(d, ex)
	d.add_rule(Palette.INK_FADED)
	_exhibit_rows(d, d.body, ex.get("rows", []))
	if String(ex.get("body", "")) != "":
		d.add_text(String(ex["body"]), UiTheme.SIZE_BODY, Palette.INK)
	_signature(d, ex)


## A staff ID: the band like a member card's, the photo, and the rows beside it.
static func _badge(d: DocumentView, c: Claim, ex: Dictionary) -> void:
	d.is_card = true
	_exhibit_paper(d, Palette.CARD, Palette.CARD_BAND)
	var band := PanelContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_theme_stylebox_override("panel", UiTheme.flat_box(Palette.CARD_BAND, Palette.CARD_BAND, 0, 10, 4))
	var band_text := UiTheme.label(String(ex.get("title", "")), UiTheme.SIZE_SMALL, Palette.CARD)
	band_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.add_child(band_text)
	d.body.add_child(band)
	d.add_space(4)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	d.body.add_child(row)
	# Containers reset child scale, so the photo sits in a plain holder.
	var face := PortraitView.new()
	face.scale = Vector2(BADGE_PHOTO_SCALE, BADGE_PHOTO_SCALE)
	face.show_patient(c.portrait_seed, c.age, false)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = face.size * BADGE_PHOTO_SCALE
	holder.add_child(face)
	row.add_child(holder)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)
	_exhibit_rows(d, column, ex.get("rows", []))


static func _exhibit_paper(d: DocumentView, color: Color, border: Color) -> void:
	d.set_paper(color, EXHIBIT_WIDTH, border)
	d.paper.add_theme_stylebox_override("panel", UiTheme.paper_box(color, border, EXHIBIT_PAD))


static func _subtitle(d: DocumentView, ex: Dictionary) -> void:
	if String(ex.get("subtitle", "")) != "":
		d.add_text(String(ex["subtitle"]), UiTheme.SIZE_SMALL, Palette.INK_FADED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func _signature(d: DocumentView, ex: Dictionary) -> void:
	if String(ex.get("signature", "")) != "":
		d.add_text(String(ex["signature"]), UiTheme.SIZE_BODY, Palette.INK_BLUE).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## The value of the first [caption, value] row with this caption, or "".
static func _row_value(rows: Array, caption: String) -> String:
	for pair: Array in rows:
		if String(pair[0]) == caption:
			return String(pair[1])
	return ""


## Exhibit rows at 16 px, keyed "exhibit.<i>", with captions only as wide as the
## longest one so the values keep the room.
static func _exhibit_rows(d: DocumentView, parent: Control, rows: Array) -> void:
	var caption_width := 0.0
	for pair: Array in rows:
		caption_width = maxf(caption_width, UiTheme.font().get_string_size(String(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x)
	for i in rows.size():
		var pair: Array = rows[i]
		d.add_field_in(parent, String(pair[0]), String(pair[1]), "exhibit.%d" % i, Palette.INK, UiTheme.SIZE_SMALL, ceilf(caption_width) + 4.0)


## A printed ultrasound frame: a wide speckled fan on black, the dark sac, and a
## small pale curl inside it, with the heart rate in the corner like the screen.
class UltrasoundScan extends Control:
	const HEIGHT := 64.0
	const SPREAD := 52.0
	## The curl: [angle in degrees around its center, dot radius], head first.
	const CURL: Array = [[-170.0, 5.0], [-128.0, 4.0], [-88.0, 4.0], [-48.0, 3.5], [-10.0, 3.0], [26.0, 2.5]]
	## What the screen prints in its corner ("FHR 142 BPM"), or "" for nothing.
	var label := ""


	func _init(heart_rate: String = "") -> void:
		custom_minimum_size = Vector2(0, HEIGHT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if heart_rate != "":
			label = "FHR %s" % heart_rate


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.BG_DARK)
		var apex := Vector2(size.x / 2.0, 2.0)
		var reach := size.y - 5.0
		var fan := PackedVector2Array([apex])
		for i in 25:
			var a := deg_to_rad(lerpf(-SPREAD, SPREAD, i / 24.0))
			fan.append(apex + Vector2(sin(a), cos(a)) * reach)
		draw_colored_polygon(fan, Palette.WALL)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["ultrasound", label])
		for i in 420:
			var a := deg_to_rad(rng.randf_range(-SPREAD, SPREAD))
			var p := apex + Vector2(sin(a), cos(a)) * reach * sqrt(rng.randf())
			draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(Palette.TEXT_DIM, rng.randf_range(0.1, 0.5)))
		var sac := apex + Vector2(0, reach * 0.6)
		var oval := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			oval.append(sac + Vector2(cos(a) * 21.0, sin(a) * 12.0))
		draw_colored_polygon(oval, Color(Palette.BG_DARK, 0.9))
		for dot: Array in CURL:
			var a := deg_to_rad(float(dot[0]))
			draw_circle(sac + Vector2(1, 3) + Vector2(cos(a), sin(a)) * 7.0, float(dot[1]), Color(Palette.PAPER_SHADE, 0.8))
		if label != "":
			draw_string(UiTheme.font(), Vector2(6, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, Palette.TEXT_DIM)


static func priority_color(priority: int) -> Color:
	match priority:
		Claim.Priority.CRITICAL:
			return Palette.RED_DARK
		Claim.Priority.URGENT:
			return Color("8a5a1c")
	return Palette.INK


## A handwritten sticky note that came stuck to the claim (the boss's mother).
static func sticky_note(text: String) -> DocumentView:
	var d := DocumentView.new()
	d.set_paper(Palette.HIGHLIGHT, 260, Palette.AMBER)
	d.add_text(text, UiTheme.SIZE_BODY, Palette.INK_BLUE)
	d.rotation_degrees = 3.0
	return d
