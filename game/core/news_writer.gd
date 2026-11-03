class_name NewsWriter
## Writes the morning paper, the memo from management and any letters, from what
## happened yesterday.
##
## `yesterday` is built by NightLogic.apply_ledger:
## {day, decisions, overturned, deaths, events, family_deaths, fines, warnings, legal, penalty}

const MEMO_TO := "Adjuster #4471, Desk 11"
const MEMO_FROM := "R. Hargrove, Regional Director, Claims Integrity"

const SCRIPTED_LEADS: Dictionary = {
	"walt:denied": {"headline": "Man dies after insurer cites lapsed coverage", "sub": "Walt Brennan, 58, missed a premium payment while in intensive care, his family says."},
	"lily:denied": {"headline": "Fundraiser for 7-year-old stalls at $3,210", "sub": "Lily Navarro's family needs $212,000 for leukemia care at the state's only children's cancer center."},
	"marcus:denied": {"headline": "Cancer patient dies awaiting experimental therapy", "sub": "Marcus Bell, 52, was denied a treatment his oncologist called his last option."},
}
const SCRIPTED_ITEMS: Dictionary = {
	"lily:approved": {"headline": "BMH slips on claims costs", "body": "Analysts blamed the dip on a single pediatric oncology claim approved Tuesday. The company called it \"a one-time event.\""},
	"priya:denied": {"headline": "Pregnancy exclusions return in the fine print", "body": "Some grandfathered plans still treat pregnancies \"known at enrollment\" as pre-existing. Benevolence Mutual called the practice standard."},
}

const RULE_DIRECTIVES: Dictionary = {
	2: ["Directive: Out-of-network providers (R-02)", "Effective today, claims from providers outside our network are not covered. The Network Directory has been added to your rulebook. Names must match exactly. \"Close\" is not a network."],
	3: ["Directive: Clerical accuracy (R-03)", "Effective today, a claim is only as good as its paperwork. If the name, member ID or date of birth on the claim differs from the member card in any way, deny it. Typos are the provider's responsibility."],
	4: ["Directive: Prior authorization (R-04)", "Effective today, itemized bills are attached to every claim. Procedures on the Prior Authorization list require a PRIOR AUTH # on the claim form. No number, no coverage."],
	5: ["Directive: Pre-existing conditions (R-05)", "Effective today, medical histories are attached to every claim. A condition on record before the card's MEMBER SINCE date is pre-existing and excluded under grandfathered plan terms. Related conditions count."],
	6: ["Directive: Excluded services (R-06)", "Effective today, services on the Exclusions list are not covered. The list is in your rulebook. A physician's recommendation is not a coverage decision."],
	7: ["Introducing DenyBot (R-07)", "Effective today, DenyBot, our proprietary review algorithm, is available for every claim. Open the DenyBot page of your rulebook and press RUN. DenyBot denials count as cited. Its reasoning is proprietary. Its accuracy is excellent."],
}


static func build_paper(run: RunState, yesterday: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var decisions: Array = yesterday.get("decisions", [])
	var outcomes := _scripted_outcomes(decisions)
	var lead: Dictionary = {}
	var events: Array = yesterday.get("events", [])
	if not events.is_empty():
		lead = NewsPool.EVENT_LEADS[int(events.max())]
	if lead.is_empty():
		for key: String in outcomes:
			if SCRIPTED_LEADS.has(key):
				lead = SCRIPTED_LEADS[key]
	if lead.is_empty():
		lead = NewsPool.pick(NewsPool.LEAD_BY_BAND[_band(run.discontent)], rng)

	var items: Array[Dictionary] = []
	var death_weekday := DateUtil.weekday(DateUtil.game_date(int(yesterday.get("day", run.day - 1))))
	for rec: Dictionary in yesterday.get("deaths", []):
		if rec["scripted_id"] != "" or items.size() >= 2:
			continue
		var template: String = NewsPool.pick(NewsPool.OBITUARY_TEMPLATES, rng)
		var body := template.format({"name": rec["name"], "age": rec["age"], "weekday": death_weekday, "condition": _lower_first(String(rec["diagnosis"]))})
		items.append({"headline": "Obituaries", "body": body})
	for key: String in outcomes:
		if SCRIPTED_ITEMS.has(key):
			items.append(SCRIPTED_ITEMS[key])

	var change := _stock_change(decisions, rng)
	var blurb_pool: Array = NewsPool.STOCK_UP if change >= 0.0 else NewsPool.STOCK_DOWN
	var blurb: String = NewsPool.pick(blurb_pool, rng)
	items.append({
		"headline": "BMH %s%.1f%%" % ["+" if change >= 0.0 else "-", absf(change)],
		"body": blurb.replace("{change}", "%.1f" % absf(change)),
	})
	items.append(NewsPool.pick(NewsPool.FLAVOR, rng))

	return {
		"date": DateUtil.fmt_long(DateUtil.game_date(run.day)),
		"lead": lead,
		"items": items,
		"stock": {"symbol": "BMH", "change": change},
	}


static func build_memo(run: RunState, yesterday: Dictionary) -> Dictionary:
	var paragraphs: PackedStringArray = []
	var subject := ""
	if run.day == 1:
		subject = "Welcome to Claims Integrity (R-01)"
		paragraphs.append_array(_welcome_paragraphs())
	else:
		var directive: Array = RULE_DIRECTIVES[run.day]
		subject = directive[0]
		paragraphs.append(directive[1])
		var performance := _performance(yesterday)
		if performance != "":
			paragraphs.append(performance)
	var effect := _effect_paragraph(run.effects)
	if effect != "":
		paragraphs.append(effect)
	paragraphs.append_array(_scripted_notes(run, yesterday))
	if run.day >= 6:
		paragraphs.append("A Regional Director position opens Monday. Candidates must hold a denial rate of at least %d%%. Yours is currently %d%%." % [roundi(Economy.PROMOTION_RATE * 100), roundi(Endings.denial_rate(run) * 100)])
	if run.day == 7:
		paragraphs.append("Note: claims flagged by DenyBot have drawn unusual public attention. Use it at your discretion.")
	return {
		"date": DateUtil.fmt(DateUtil.game_date(run.day)),
		"to": MEMO_TO,
		"from": MEMO_FROM,
		"subject": subject,
		"paragraphs": paragraphs,
	}


static func build_letters(_run: RunState, yesterday: Dictionary) -> Array[Dictionary]:
	var letters: Array[Dictionary] = []
	var outcomes := _scripted_outcomes(yesterday.get("decisions", []))
	if outcomes.has("walt:denied"):
		letters.append({
			"from": "Karen Brennan",
			"paragraphs": PackedStringArray([
				"To whoever handled my father's claim,",
				"Dad died last night. He paid Benevolence Mutual for nineteen years. The one month his payment bounced, he was in intensive care with a tube down his throat.",
				"Your letter said his coverage had lapsed. I keep reading that word.",
				"I don't know what I want you to do with this. I just wanted someone there to know his name. It was Walter.",
				"Karen Brennan",
			]),
		})
	if outcomes.has("marcus:denied"):
		letters.append({
			"from": "Denise Bell",
			"paragraphs": PackedStringArray([
				"Marcus asked me to write this, so I am.",
				"He knew the immunotherapy wasn't a sure thing. The trial doctors said maybe a year. He wanted to see our daughter graduate in May.",
				"He died last night, at home, which is what he wanted, at least.",
				"He said to tell you he doesn't blame you. I'm not there yet.",
				"Denise Bell",
			]),
		})
	return letters


# --- pieces ----------------------------------------------------------------

static func _welcome_paragraphs() -> PackedStringArray:
	var c := Economy.COMMISSION
	var a := Economy.APPROVAL_COST
	return PackedStringArray([
		"Welcome to Benevolence Mutual. Members will present their claims at your window. Your job is to protect the plan.",
		"APPROVED claims are paid by the company and deducted from your pay: $%d routine, $%d urgent, $%d critical. DENIED claims earn you a commission: $%d, $%d, $%d." % [a[0], a[1], a[2], c[0], c[1], c[2]],
		"To cite a reason, press INSPECT (or SPACE), click a rule in your rulebook, then click the field that breaks it. Cited denials pay full commission. A citation that finds nothing costs a $%d compliance review fee." % Economy.COMPLIANCE_FEE,
		"You may deny without citing a reason. Uncited denials pay half, and if legal can't defend one, the member wins on appeal and you owe a $%d legal fee." % Economy.LEGAL_FEE,
		"Approving a claim with valid grounds for denial earns a citation: two warnings a day, then $%d each." % Economy.CITATION_FINE,
		"Today's rule, R-01 COVERAGE LAPSED: if the card's COVERAGE THROUGH date is earlier than the claim's DATE OF SERVICE, the member was not covered.",
		"Rent is due tonight. We care.*",
	])


static func _performance(yesterday: Dictionary) -> String:
	var decisions: Array = yesterday.get("decisions", [])
	var denied := 0
	for rec: Dictionary in decisions:
		if not rec["approved"]:
			denied += 1
	var parts: PackedStringArray = []
	if not decisions.is_empty():
		parts.append("Yesterday you processed %d claims: %d denied, %d approved." % [decisions.size(), denied, decisions.size() - denied])
	var warnings := int(yesterday.get("warnings", 0))
	if warnings > 0:
		parts.append("You approved %d claim%s that had valid grounds for denial." % [warnings, "" if warnings == 1 else "s"])
	var fines := int(yesterday.get("fines", 0))
	if fines > 0:
		parts.append("Citation fines: $%d." % fines)
	var overturned: Array = yesterday.get("overturned", [])
	if not overturned.is_empty():
		parts.append("Legal lost %d appeal%s on denials you could not justify. Legal fees: $%d." % [overturned.size(), "" if overturned.size() == 1 else "s", int(yesterday.get("legal", 0))])
	if not decisions.is_empty():
		var rate := float(denied) / decisions.size()
		if rate >= 0.7:
			parts.append("Excellent work.")
		elif rate <= 0.3:
			parts.append("Your approval rate has been noted.")
	return " ".join(parts)


static func _effect_paragraph(effects: Dictionary) -> String:
	if effects.get("compassion", false):
		return "Ahead of the congressional hearing, today is Compassion Day. Approvals will not be deducted from your pay. Please approve visibly."
	if effects.get("audit", false):
		return "Regulators are auditing today's denials. Any denial without a cited reason will be overturned, and legal fees will apply."
	if effects.get("protest", false):
		return "Protesters have gathered at the entrance. Use the side door. Every denial today will draw additional attention."
	return ""


static func _scripted_notes(run: RunState, yesterday: Dictionary) -> PackedStringArray:
	var notes: PackedStringArray = []
	var outcomes := _scripted_outcomes(yesterday.get("decisions", []))
	if outcomes.has("dale:denied"):
		notes.append("Dale Pruitt (Desk 12) has requested a transfer to another floor. Please do not contact him regarding his claim.")
	if outcomes.has("dale:approved"):
		notes.append("Reminder: adjusters may not show favoritism toward colleagues. We will overlook it this once.")
	if outcomes.has("eleanor:denied"):
		notes.append("We need to talk about yesterday. A performance adjustment of $%d has been applied to your pay. -R.H." % Economy.BOSS_PENALTY)
	if outcomes.has("eleanor:approved"):
		notes.append("Thank you for your discretion yesterday. This conversation never happened. -R.H.")
	if outcomes.has("lily:approved"):
		notes.append("Pediatric oncology costs exceeded projections yesterday. Please keep projections in mind.")
	if int(yesterday.get("day", 0)) == NightLogic.RILEY_NIGHT:
		notes.append("Your dependent's emergency claim was reviewed under standard guidelines. Adjusters may not discuss their own claims with colleagues.")
	var lost: Array = yesterday.get("family_deaths", [])
	if not lost.is_empty():
		notes.append("Benevolence Mutual extends its condolences on the loss of %s. Bereavement leave is unpaid." % " and ".join(PackedStringArray(lost)))
	if run.day == 7 and run.scripted_outcomes.has("marcus") and run.scripted_outcomes["marcus"] == "denied":
		notes.append("You may hear about Mr. Bell. Do not speak to reporters.")
	return notes


static func _scripted_outcomes(decisions: Array) -> Dictionary:
	var outcomes := {}
	for rec: Dictionary in decisions:
		var id: String = rec.get("scripted_id", "")
		if id != "" and id != "player":
			outcomes["%s:%s" % [id, "approved" if rec["approved"] else "denied"]] = true
	return outcomes


static func _stock_change(decisions: Array, rng: RandomNumberGenerator) -> float:
	var rate := 0.5
	if not decisions.is_empty():
		var denied := 0
		for rec: Dictionary in decisions:
			if not rec["approved"]:
				denied += 1
		rate = float(denied) / decisions.size()
	return snappedf((rate - 0.45) * 8.0 + rng.randf_range(-0.6, 0.6), 0.1)


static func _band(discontent: float) -> int:
	if discontent < 30.0:
		return 0
	if discontent < 55.0:
		return 1
	if discontent < 80.0:
		return 2
	return 3


## "Colon cancer, stage III" -> "colon cancer, stage III".
static func _lower_first(text: String) -> String:
	if text.is_empty():
		return text
	return text[0].to_lower() + text.substr(1)
