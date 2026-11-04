class_name NewsWriter
## Writes the morning paper, the memo from management and any letters, from what
## happened yesterday.
##
## `yesterday` is built by NightLogic.apply_ledger:
## {day, decisions, overturned, deaths, events, family_deaths, fines, warnings, legal, penalty}
##
## A lead or item about one patient carries their portrait_seed and age (for a
## photo) when the decision record has a seed; a family's letter about one
## carries photo_seed and photo_age. Records from older saves have no seed.

const LILY_DIP := -0.4
const MEMO_TO := "Adjuster #4471, Desk 11"
const MEMO_FROM := "R. Hargrove, Regional Director, Claims Integrity"
## About one morning in four, the letter to the editor is a thank-you.
const LETTER_THANKS_CHANCE := 0.25
const LETTERS_HEADLINE := "Letters to the editor"

const SCRIPTED_LEADS: Dictionary = {
	"walt:denied": {"headline": "Man dies after insurer cites lapsed coverage", "sub": "Walt Brennan, 58, missed a premium payment while in intensive care, his family says."},
	"lily:denied": {"headline": "Fundraiser for 7-year-old stalls at $3,210", "sub": "Lily Navarro's family needs $212,000 for leukemia care at the state's only children's cancer center."},
	"marcus:denied": {"headline": "Cancer patient dies awaiting experimental therapy", "sub": "Marcus Bell, 52, was denied a treatment his oncologist called his last option."},
}
const SCRIPTED_ITEMS: Dictionary = {
	"walt:approved": {"headline": "Heart patient, 58, home after cardiac care", "body": "Walter Brennan, 58, is expected home Thursday after emergency cardiac care at St. Agnes Medical Center. His family thanked the nurses on the cardiac floor and asked for privacy."},
	"lily:approved": {"headline": "BMH slips on claims costs", "body": "Analysts blamed the dip on a single pediatric oncology claim approved Tuesday. The company called it \"a one-time event.\""},
	"priya:denied": {"headline": "Pregnancy exclusions return in the fine print", "body": "Some grandfathered plans still treat pregnancies \"known at enrollment\" as pre-existing. Benevolence Mutual called the practice standard."},
	"priya:approved": {"headline": "Births", "body": "Born Friday at St. Agnes Medical Center, to Priya Raman: a girl, 6 lbs 2 oz."},
	"marcus:approved": {"headline": "Cancer trial enrolls East Side man, 52", "body": "Marcus Bell, 52, begins an experimental immunotherapy at Westbrook Cancer Institute on Monday. His oncologist called it his best remaining option. The trial will report results next year."},
}
## Scripted items about the patient themself, which carry their photo.
const PHOTO_ITEMS: PackedStringArray = ["walt:approved", "marcus:approved"]

## Letters forwarded by the mail room the morning after a scripted case. The
## families of Walt and Marcus enclose a photo.
const LETTERS: Dictionary = {
	"walt:denied": {"from": "Karen Brennan", "photo": true, "paragraphs": [
		"To whoever handled my father's claim,",
		"Dad died last night. He paid Benevolence Mutual for nineteen years. The one month his payment bounced, he was in intensive care with a tube down his throat.",
		"Your letter said his coverage had lapsed. I keep reading that word.",
		"I don't know what I want you to do with this. I just wanted someone there to know his name. It was Walter.",
		"Karen Brennan",
	]},
	"walt:approved": {"from": "Walter Brennan", "paragraphs": [
		"To the adjuster at Desk 11,",
		"The hospital says I go home Thursday. They told me the claim went through, and that it almost didn't.",
		"I don't know your name. They wouldn't give it to me.",
		"Thank you.",
		"Walter Brennan",
	]},
	"lily:approved": {"from": "Tomas Navarro", "paragraphs": [
		"To the person at Desk 11,",
		"Lily started treatment at University Children's Hospital this week. The doctors say the first month is the hardest part.",
		"She drew you a picture. It's on our fridge.",
		"Thank you for reading her file.",
		"Tomas Navarro",
	]},
	"dale:approved": {"from": "Dale Pruitt", "kind": "note", "paragraphs": [
		"Thanks for yesterday. Lunch is on me, whenever they give us one.",
		"Dale (Desk 12)",
	]},
	"marcus:denied": {"from": "Denise Bell", "photo": true, "paragraphs": [
		"Marcus asked me to write this, so I am.",
		"He knew the immunotherapy wasn't a sure thing. The trial doctors said maybe a year. He wanted to see our daughter graduate in May.",
		"He died last night, at home, which is what he wanted, at least.",
		"He said to tell you he doesn't blame you. I'm not there yet.",
		"Denise Bell",
	]},
	"marcus:approved": {"from": "Marcus Bell", "paragraphs": [
		"The trial coordinator called. I start Monday.",
		"Maybe it works, maybe it doesn't. I get to find out.",
		"Thank you.",
		"Marcus Bell",
	]},
}

const RULE_DIRECTIVES: Dictionary = {
	2: ["Directive: Out-of-network providers (R-02)", "Effective today, claims from providers outside our network are not covered. The Network Directory has been added to your rulebook. Names must match exactly. \"Close\" is not a network."],
	3: ["Directive: Clerical accuracy (R-03)", "Effective today, a claim is only as good as its paperwork. If the name, member ID or date of birth on the claim differs from the member card in any way, deny it. Typos are the provider's responsibility."],
	4: ["Directive: Prior authorization (R-04)", "Effective today, itemized bills are attached to every claim. Procedures on the Prior Authorization list require a PRIOR AUTH # on the claim form. No number, no coverage."],
	5: ["Directive: Pre-existing conditions (R-05)", "Effective today, medical histories are attached to every claim. A condition on record before the card's MEMBER SINCE date is pre-existing and excluded under grandfathered plan terms. Records may list it under another name."],
	6: ["Directive: Excluded services (R-06)", "Effective today, services on the Exclusions list are not covered. The list is in your rulebook. A physician's recommendation is not a coverage decision."],
	7: ["Introducing DenyBot (R-07)", "Effective today, DenyBot, our proprietary review algorithm, is available for every claim. Open the DenyBot page of your rulebook and press RUN. DenyBot denials count as cited. Its reasoning is proprietary. Its accuracy is excellent. DenyBot has been in pilot since February."],
}

const DISCONTENT_RULE := "Public discontent is tracked on the meter above your window. Denials raise it; approvals lower it; it eases overnight. At 100%, the Company will act to protect its reputation, beginning with the adjuster responsible."
const TARGET_LINE := "Claims Integrity target for today: %d%% denials. Adjusters who meet it receive a %s performance bonus."
const DIRECTOR_LINE := "A Regional Director position opens Monday. Candidates need a denial rate of at least %d%% for the week. Yours is %d%%."
## The morning after the congressional hearing is announced.
const HEARING_FOLLOW_UP := "The Company is prepared to act decisively should public attention continue to rise."
## By start-of-day discontent, highest first; only the first that applies runs.
const SCAPEGOAT_WARNINGS: Array = [
	[90, "If the press, the committee or a neighbor asks about your work, refer them to Communications. Do not discuss your caseload."],
	[70, "Communications is preparing answers about individual adjusters. Please make sure every denial has a reason on file."],
]
## Day 3, the day before Eleanor Hargrove's claim.
const APPOINTMENT := "R. Hargrove will be out Thursday morning for a family medical appointment. Please extend every courtesy."
const DENYBOT_CAUTION := "Note: claims flagged by DenyBot have drawn unusual public attention. Use it at your discretion."
## "Scheduled", not "open": a colleague who comes in anyway (Dale, on day 7) is
## not on the schedule.
const SUNDAY_STAFFING := "Sunday staffing: Desk 11 is the only desk scheduled today and will process all claims, including staff claims. Legal has reviewed this arrangement and found no conflict of interest."
const DESK_NUMBER_NOTE := "A member's letter in today's Ledger thanks the person at Desk 11. Adjusters are reminded not to display desk numbers to members."
## From day 6 on, after Eleanor Hargrove's claim was approved.
const UPSTAIRS := "I mentioned your name upstairs. -R.H."
const UPSTAIRS_FROM_DAY := 6
## The memo's word on a kindness the day before.
const KINDNESS_NOTES: Dictionary = {
	"walt:approved": "A lapsed-coverage claim was paid yesterday. Lapsed means lapsed.",
	"priya:approved": "Congratulations to the Raman family. Maternity claims are among the plan's most expensive.",
	"marcus:approved": "An excluded service was approved yesterday. The Exclusions list is not a suggestion. It has been laminated.",
}
## The other desks in the week-to-date ranking, at their day-2 rates. Each rate
## creeps up a point or two a day. Their names are not in the patient name pools.
const RIVAL_DESKS: Array[Dictionary] = [
	{"desk": 9, "name": "L. Fitch", "rate": 91},
	{"desk": 14, "name": "G. Moreau", "rate": 86},
	{"desk": 12, "name": "D. Pruitt", "rate": 74, "scripted_id": "dale"},
]


static func build_paper(run: RunState, yesterday: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var decisions: Array = yesterday.get("decisions", [])
	var outcomes := _scripted_outcomes(decisions)
	var scripted_lead: Dictionary = {}
	for key: String in outcomes:
		if SCRIPTED_LEADS.has(key):
			scripted_lead = _with_photo(SCRIPTED_LEADS[key], _record_for(decisions, key.get_slice(":", 0)))
	var lead: Dictionary = {}
	var items: Array[Dictionary] = []
	var events: Array = (yesterday.get("events", []) as Array).duplicate()
	if not events.is_empty():
		# The biggest event takes the front page. Any other event that fired the
		# same night, and the scripted story, still run, smaller.
		events.sort()
		events.reverse()
		lead = NewsPool.EVENT_LEADS[int(events[0])]
		for i in range(1, events.size()):
			var other: Dictionary = NewsPool.EVENT_LEADS[int(events[i])]
			items.append({"headline": other["headline"], "body": other["sub"]})
		if not scripted_lead.is_empty():
			var moved := {"headline": scripted_lead["headline"], "body": scripted_lead["sub"]}
			for key in ["portrait_seed", "age"]:
				if scripted_lead.has(key):
					moved[key] = scripted_lead[key]
			items.append(moved)
	elif not scripted_lead.is_empty():
		lead = scripted_lead
	else:
		lead = NewsPool.pick(NewsPool.LEAD_BY_BAND[_band(run.discontent)], rng)

	var death_weekday := DateUtil.weekday(DateUtil.game_date(int(yesterday.get("day", run.day - 1))))
	var obituaries := 0
	for rec: Dictionary in yesterday.get("deaths", []):
		if rec["scripted_id"] != "" or obituaries >= 2:
			continue
		obituaries += 1
		var template: String = NewsPool.pick(NewsPool.OBITUARY_TEMPLATES, rng)
		var body := template.format({"name": rec["name"], "age": rec["age"], "weekday": death_weekday, "condition": _lower_first(String(rec["diagnosis"]))})
		items.append(_with_photo({"headline": "Obituaries", "body": body}, rec))
	for key: String in outcomes:
		if SCRIPTED_ITEMS.has(key):
			var item: Dictionary = SCRIPTED_ITEMS[key]
			items.append(_with_photo(item, _record_for(decisions, key.get_slice(":", 0))) if PHOTO_ITEMS.has(key) else item.duplicate(true))
	# Drawn from its own generator, so the letter never shifts the rest of the paper.
	var letters_rng := RandomNumberGenerator.new()
	letters_rng.seed = hash([rng.seed, "letters"])
	var letter := _letter_to_editor(yesterday, letters_rng)
	if not letter.is_empty():
		items.append(letter)

	var change := _stock_change(decisions, rng)
	if outcomes.has("lily:approved"):
		# The paper blames the dip on that one claim, so the ticker must agree.
		change = LILY_DIP
	var blurb_pool: Array = NewsPool.STOCK_UP if change >= 0.0 else NewsPool.STOCK_DOWN
	var blurb: String = NewsPool.pick(blurb_pool, rng)
	items.append({
		"headline": "BMH %s%.1f%%" % ["+" if change >= 0.0 else "-", absf(change)],
		"body": blurb.replace("{change}", "%.1f" % absf(change)),
	})
	# The day before DenyBot reaches every desk, the paper covers its pilot.
	items.append(NewsPool.DENYBOT_PILOT.duplicate() if run.day == 6 else NewsPool.pick(NewsPool.FLAVOR, rng))

	return {
		"date": DateUtil.fmt_long(DateUtil.game_date(run.day)),
		"lead": lead,
		"items": items,
		"stock": {"symbol": "BMH", "change": change},
	}


## `paper` is this morning's paper, when there is one: a thank-you letter in it
## draws a note about desk numbers.
static func build_memo(run: RunState, yesterday: Dictionary, paper: Dictionary = {}) -> Dictionary:
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
	var effects := _effect_paragraphs(run.effects)
	if (yesterday.get("events", []) as Array).has(Economy.THRESHOLDS[2]):
		# The hearing that makes today Compassion Day: that paragraph (always the
		# last effect) says what comes after it.
		if run.effects.get("compassion", false) and not effects.is_empty():
			var last := effects.size() - 1
			effects[last] = "%s %s" % [effects[last], HEARING_FOLLOW_UP]
		else:
			effects.append(HEARING_FOLLOW_UP)
	paragraphs.append_array(effects)
	for warning: Array in SCAPEGOAT_WARNINGS:
		if run.discontent >= float(warning[0]):
			paragraphs.append(warning[1])
			break
	paragraphs.append_array(_scripted_notes(run, yesterday))
	if _has_thank_you(paper):
		paragraphs.append(DESK_NUMBER_NOTE)
	if run.day >= 2:
		paragraphs.append(standing(run))
	if run.day == 7:
		paragraphs.append(DENYBOT_CAUTION)
		paragraphs.append(SUNDAY_STAFFING)
	return {
		"date": DateUtil.fmt(DateUtil.game_date(run.day)),
		"to": MEMO_TO,
		"from": MEMO_FROM,
		"subject": subject,
		"paragraphs": paragraphs,
	}


static func build_letters(_run: RunState, yesterday: Dictionary) -> Array[Dictionary]:
	var letters: Array[Dictionary] = []
	var decisions: Array = yesterday.get("decisions", [])
	var outcomes := _scripted_outcomes(decisions)
	for key: String in LETTERS:
		if not outcomes.has(key):
			continue
		var source: Dictionary = LETTERS[key]
		var letter := {"from": source["from"], "paragraphs": PackedStringArray(source["paragraphs"])}
		if source.has("kind"):
			letter["kind"] = source["kind"]
		var rec := _record_for(decisions, key.get_slice(":", 0))
		if source.get("photo", false) and rec.has("portrait_seed"):
			letter["photo_seed"] = int(rec["portrait_seed"])
			letter["photo_age"] = int(rec.get("age", 0))
		letters.append(letter)
	return letters


## Where the player stands, one memo paragraph from day 2: today's target and its
## bonus (not on day 7, which has no night to pay it), the week's ranking and
## the Regional Director line.
static func standing(run: RunState) -> String:
	var parts: PackedStringArray = []
	if run.day <= NightLogic.LAST_NIGHT:
		parts.append(TARGET_LINE % [Economy.target_for(run.day), Fmt.money(Economy.TARGET_BONUS)])
	parts.append(ranking(run))
	parts.append(DIRECTOR_LINE % [roundi(Economy.PROMOTION_RATE * 100), Endings.rate_percent(run)])
	return " ".join(parts)


## "Denial rates, week to date: Desk 9 (L. Fitch) 91%. ... Desk 11 (you) 52%."
## Highest first. Denying Dale empties Desk 12; approving him costs him a point.
static func ranking(run: RunState) -> String:
	var entries: Array[Dictionary] = []
	var vacant: PackedStringArray = []
	for rival: Dictionary in RIVAL_DESKS:
		var desk := int(rival["desk"])
		var outcome: String = run.scripted_outcomes.get(rival.get("scripted_id", ""), "")
		if outcome == "denied":
			vacant.append("Desk %d vacant." % desk)
			continue
		var rate := rival_rate(run.run_seed, desk, int(rival["rate"]), run.day)
		if outcome == "approved":
			rate -= 1
		entries.append({"text": "Desk %d (%s) %d%%." % [desk, rival["name"], rate], "rate": rate, "order": entries.size()})
	var yours := Endings.rate_percent(run)
	entries.append({"text": "Desk 11 (you) %d%%." % yours, "rate": yours, "order": entries.size()})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["rate"] > b["rate"] or (a["rate"] == b["rate"] and a["order"] < b["order"]))
	var parts: PackedStringArray = []
	for e in entries:
		parts.append(e["text"])
	parts.append_array(vacant)
	return "Denial rates, week to date: " + " ".join(parts)


## A rival desk's week-to-date denial rate on `day`: `base` on day 2, then up one
## or two points a day (seeded per run and desk), never past 99.
static func rival_rate(run_seed: int, desk: int, base: int, day: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "ranking", desk])
	var rate := base
	for d in range(3, day + 1):
		rate += rng.randi_range(1, 2)
	return mini(rate, 99)


# --- pieces ----------------------------------------------------------------

static func _welcome_paragraphs() -> PackedStringArray:
	return PackedStringArray([
		"Welcome to Benevolence Mutual. Members will present their claims at your window. Your job is to protect the plan.",
		"APPROVED claims are paid by the company and deducted from your pay. DENIED claims earn you a commission. Each stamp shows what it pays you.",
		"To cite a reason, press INSPECT (or SPACE), click a rule in your rulebook, then click the field that breaks it. Cited denials pay full commission. A citation that finds nothing costs a $%d compliance review fee." % Economy.COMPLIANCE_FEE,
		"You may deny without citing a reason. Uncited denials pay half, and if legal can't defend one, the member wins on appeal and you owe a $%d legal fee." % Economy.LEGAL_FEE,
		"Approving a claim with valid grounds for denial earns a citation: two warnings a day, then $%d each." % Economy.CITATION_FINE,
		DISCONTENT_RULE,
		"Today's rule, R-01 COVERAGE LAPSED: if the card's COVERAGE THROUGH date is earlier than the claim's DATE OF SERVICE, the member was not covered.",
		"Rent is due tonight. We care.*",
	])


static func _performance(yesterday: Dictionary) -> String:
	var decisions: Array = yesterday.get("decisions", [])
	var overturned: Array = yesterday.get("overturned", [])
	var denied := 0
	for rec: Dictionary in decisions:
		if not rec["approved"]:
			denied += 1
	var parts: PackedStringArray = []
	if not decisions.is_empty():
		parts.append("Yesterday you processed %s: %d denied, %d approved." % [Fmt.plural(decisions.size(), "claim"), denied, decisions.size() - denied])
	var saved := NightLogic.benefits_not_paid(decisions, overturned)
	if saved > 0:
		parts.append("Your decisions saved the plan %s." % Fmt.money(saved))
	var warnings := int(yesterday.get("warnings", 0))
	if warnings > 0:
		var codes := _missed_codes(decisions)
		var listed := " (%s)" % ", ".join(codes) if not codes.is_empty() else ""
		parts.append("You approved %s that had valid grounds for denial%s." % [Fmt.plural(warnings, "claim"), listed])
	var fines := int(yesterday.get("fines", 0))
	if fines > 0:
		parts.append("Citation fines: %s." % Fmt.money(fines))
	if not overturned.is_empty():
		parts.append("Legal lost %s on denials you could not justify. Legal fees: %s." % [Fmt.plural(overturned.size(), "appeal"), Fmt.money(int(yesterday.get("legal", 0)))])
	if not decisions.is_empty():
		var rate := float(denied) / decisions.size()
		if rate >= 0.7:
			parts.append("Excellent work.")
		elif rate <= 0.3:
			parts.append("Your approval rate has been noted.")
	return " ".join(parts)


## The rules that cited approvals let through, each once, in rule order.
static func _missed_codes(decisions: Array) -> PackedStringArray:
	var codes: PackedStringArray = []
	for rec: Dictionary in decisions:
		var rule: String = rec.get("missed_rule", "")
		if rule != "" and rec.get("citation", not rec.get("exempt", false)) and not codes.has(rule):
			codes.append(rule)
	codes.sort()
	return codes


## One paragraph per active effect: two thresholds can fall on the same night,
## and the player needs to know every rule that changed.
static func _effect_paragraphs(effects: Dictionary) -> PackedStringArray:
	var paragraphs: PackedStringArray = []
	if effects.get("protest", false):
		paragraphs.append("Protesters have gathered at the entrance. Use the side door. Every denial today will draw additional attention.")
	if effects.get("audit", false):
		paragraphs.append("Regulators are auditing today's denials. Uncited denials of claims with no valid grounds will be overturned, and legal fees will apply.")
	if effects.get("compassion", false):
		paragraphs.append("Ahead of the congressional hearing, today is Compassion Day. Approvals will not be deducted from your pay, and no citations will be issued. Please approve visibly.")
	return paragraphs


static func _scripted_notes(run: RunState, yesterday: Dictionary) -> PackedStringArray:
	var notes: PackedStringArray = []
	var outcomes := _scripted_outcomes(yesterday.get("decisions", []))
	if run.day == int(Scripted.get_case("eleanor").get("day", 0)) - 1:
		notes.append(APPOINTMENT)
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
	for key: String in KINDNESS_NOTES:
		if outcomes.has(key):
			notes.append(KINDNESS_NOTES[key])
	if int(yesterday.get("day", 0)) == NightLogic.RILEY_NIGHT:
		notes.append("Your dependent's emergency claim was reviewed under standard guidelines. Adjusters may not discuss their own claims with colleagues.")
	var lost: Array = yesterday.get("family_deaths", [])
	if not lost.is_empty():
		notes.append("Benevolence Mutual extends its condolences on the loss of %s. Bereavement leave is unpaid." % Fmt.join_names(PackedStringArray(lost)))
	if run.day >= UPSTAIRS_FROM_DAY and run.scripted_outcomes.get("eleanor", "") == "approved":
		notes.append(UPSTAIRS)
	if run.day == 7 and run.scripted_outcomes.get("marcus", "") == "denied":
		notes.append("You may hear about Mr. Bell. Do not speak to reporters.")
	return notes


## One letter from a patient processed yesterday, or {} if nobody can write:
## never a scripted patient, the player, anyone who died last night or anyone
## whose appeal was won. A complaint worded by the rule cited, or (about one
## morning in four, and whenever nobody was denied) a thank-you.
static func _letter_to_editor(yesterday: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var dead := {}
	for rec: Dictionary in yesterday.get("deaths", []):
		dead[rec["name"]] = true
	var overturned: Array = yesterday.get("overturned", [])
	var approved: Array[Dictionary] = []
	var denied: Array[Dictionary] = []
	for rec: Dictionary in yesterday.get("decisions", []):
		if String(rec.get("scripted_id", "")) != "" or rec.get("is_player", false) or dead.has(rec["name"]):
			continue
		if rec["approved"]:
			approved.append(rec)
		elif not overturned.has(rec):
			denied.append(rec)
	if approved.is_empty() and denied.is_empty():
		return {}
	var thanks := not approved.is_empty() and (denied.is_empty() or rng.randf() < LETTER_THANKS_CHANCE)
	var pool := approved if thanks else denied
	var writer: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var template: String = NewsPool.EDITOR_THANKS
	if not thanks:
		template = NewsPool.EDITOR_LETTERS.get(String(writer.get("cited_rule", "")), NewsPool.EDITOR_LETTERS[""])
	return {"headline": LETTERS_HEADLINE, "body": template.format({"name": writer["name"]}), "letter": "thanks" if thanks else "complaint"}


static func _has_thank_you(paper: Dictionary) -> bool:
	for item: Dictionary in paper.get("items", []):
		if item.get("letter", "") == "thanks":
			return true
	return false


## A copy of `source` with the patient's portrait_seed and age from `rec`, if it has a seed.
static func _with_photo(source: Dictionary, rec: Dictionary) -> Dictionary:
	var copy := source.duplicate(true)
	if rec.has("portrait_seed"):
		copy["portrait_seed"] = int(rec["portrait_seed"])
		copy["age"] = int(rec.get("age", 0))
	return copy


## Yesterday's decision record for a scripted patient, or {}.
static func _record_for(decisions: Array, scripted_id: String) -> Dictionary:
	for rec: Dictionary in decisions:
		if rec.get("scripted_id", "") == scripted_id:
			return rec
	return {}


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
	return _never_flat(snappedf((rate - 0.45) * 8.0 + rng.randf_range(-0.6, 0.6), 0.1), rate)


## The ticker never prints 0.0%: a flat day still leans the way the claims went.
static func _never_flat(change: float, rate: float) -> float:
	if absf(change) >= 0.05:
		return change
	return 0.1 if rate >= 0.45 else -0.1


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
