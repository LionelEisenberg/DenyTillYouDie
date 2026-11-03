class_name Paperwork
## Builds the documents for one patient. Every visible fact is a citable row, so
## which rows are clickable never gives the answer away.

const BLANK := "__________"


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
		d.add_field("TREATMENT", c.treatment_summary(), "claim.treatment", Palette.INK, UiTheme.SIZE_SMALL)
	d.add_field("AMOUNT", UiTheme.money(c.amount), "claim.amount")
	d.add_field("PRIORITY", c.priority_name(), "claim.priority", priority_color(c.priority))
	if c.shows_bill():
		d.add_field("PRIOR AUTH #", c.prior_auth if c.prior_auth != "" else BLANK, "claim.prior_auth")
	return d


static func member_card(c: Claim) -> DocumentView:
	var d := DocumentView.new()
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
	d.add_line_item("TOTAL DUE", UiTheme.money(c.bill_total()), "bill.total", UiTheme.SIZE_BODY, UiTheme.SIZE_BODY)
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


## The pink slip for approving a claim that had valid grounds for denial.
static func citation_slip(warning: int, fine: int) -> DocumentView:
	var d := DocumentView.new()
	d.set_paper(Palette.PINK_SLIP, 340, Palette.RED_DARK)
	d.add_title("CITATION", UiTheme.SIZE_TITLE, Palette.RED_DARK)
	d.add_text("Approved a claim with valid grounds for denial.", UiTheme.SIZE_SMALL, Palette.INK)
	if fine > 0:
		d.add_text("Fine deducted: %s" % UiTheme.money(fine), UiTheme.SIZE_BODY, Palette.RED_DARK)
	else:
		d.add_text("Warning %d of %d. Further citations today will be fined." % [warning, Economy.FREE_WARNINGS], UiTheme.SIZE_SMALL, Palette.INK)
	d.add_text("-Claims Integrity", UiTheme.SIZE_SMALL, Palette.INK_FADED)
	return d


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
