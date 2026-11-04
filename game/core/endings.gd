class_name Endings
## The seven ways a run ends, and the pages that show them: the last front page,
## what became of everyone, and one last document.

const SCAPEGOATED := "scapegoated"
const EVICTED := "evicted"
const FIRED := "fired"
const EMPLOYEE_OF_MONTH := "employee_of_the_month"
const PROMOTED := "promoted"
const TAKEN_CARE_OF := "taken_care_of"
const COVERED := "covered"
## Every ending, for "OUTCOME 2 OF 7 ON FILE".
const ALL: PackedStringArray = [SCAPEGOATED, EVICTED, FIRED, EMPLOYEE_OF_MONTH, PROMOTED, TAKEN_CARE_OF, COVERED]

## Day 7's favors: who offers to fix the player's own claim.
const FAVOR_RH := "rh"
const FAVOR_DALE := "dale"
const RH_NOTE := "I saw your claim. Approve it. I'll sign off.\n-R.H."
const DALE_NOTE := "Saw your name on the list. Put it in my tray.\n-Dale, Desk 12"

const HARGROVE := "R. Hargrove, Regional Director, Claims Integrity"
const NEW_ADJUSTER := "Adjuster #4472, Desk 11"
const WELCOME_RE := "Welcome to Claims Integrity (R-01)"

## What became of each scripted patient, by how their claim was stamped.
const FOLLOW_UPS: Dictionary = {
	"walt": {
		"denied": "Walter Brennan's daughter is still paying for the ICU.",
		"approved": "Walter Brennan is back at the hardware store, three days a week.",
	},
	"lily": {
		"denied": "The fundraiser for Lily Navarro, 7, closed at $3,210.",
		"approved": "Lily Navarro, 7, finished her first round of chemotherapy. The nurses let her ring the bell early.",
	},
	"dale": {
		"denied": "Dale Pruitt works on the fourth floor now. He takes the stairs.",
		"approved": "Dale Pruitt still owes you lunch.",
	},
	"eleanor": {
		"denied": "Eleanor Hargrove had her hip replaced. Her son paid cash.",
		"approved": "Eleanor Hargrove is walking again. Her son has not mentioned it.",
	},
	"priya": {
		"denied": "Priya Raman had a girl. The hospital has her on a payment plan.",
		"approved": "Priya Raman had a girl, 6 lbs 2 oz. Her name is June.",
	},
	"marcus": {
		"denied": "Marcus Bell's daughter graduates in May.",
		"approved": "Marcus Bell started the trial on Monday. It is too early to say.",
	},
}
## Names the obituaries print in full.
const FORMAL_NAMES: Dictionary = {"walt": "Walter Brennan"}


## The ending after the player rules on their own claim on day 7.
static func resolve_final(run: RunState, approved_own: bool) -> String:
	if run.discontent >= Economy.SCAPEGOAT_AT:
		return SCAPEGOATED
	if approved_own:
		match favor(run):
			FAVOR_RH:
				return TAKEN_CARE_OF
			FAVOR_DALE:
				return COVERED
		return FIRED
	# Judged on the percent the memo shows, so "66%" never earns a 67% promotion.
	if rate_percent(run) >= roundi(Economy.PROMOTION_RATE * 100):
		return PROMOTED
	return EMPLOYEE_OF_MONTH


## Who has offered to see the player's own claim through: R.H. if you approved
## his mother's claim, otherwise Dale if you approved his, otherwise nobody.
static func favor(run: RunState) -> String:
	if String(run.scripted_outcomes.get("eleanor", "")) == "approved":
		return FAVOR_RH
	if String(run.scripted_outcomes.get("dale", "")) == "approved":
		return FAVOR_DALE
	return ""


## The sticky note on the player's own claim on day 7, or "".
static func favor_note(run: RunState) -> String:
	match favor(run):
		FAVOR_RH:
			return RH_NOTE
		FAVOR_DALE:
			return DALE_NOTE
	return ""


## Denied / processed over the whole run, excluding the player's own claim.
static func denial_rate(run: RunState) -> float:
	var processed := int(run.stats.get("processed", 0))
	if processed == 0:
		return 0.0
	return float(run.stats.get("denied", 0)) / processed


## The denial rate as every page shows it: whole percent, rounded down (32 of 48
## is 66%). The epsilon keeps 29 of 100 from flooring to 28.
static func rate_percent(run: RunState) -> int:
	return floori(denial_rate(run) * 100.0 + 0.000001)


## Every ending is reported the morning after the last day worked.
static func morning_after(run: RunState) -> int:
	return DateUtil.game_date(clampi(run.day, 1, 7)) + 1


## {id, title, paper: {headline, sub}, epilogue: PackedStringArray, stats: Array,
## survived: bool, follow_ups: PackedStringArray, obituaries: String (only when
## someone died), photo: Dictionary (only when the paper runs one), document:
## Dictionary (only for a known ending)}
static func build(run: RunState, id: String) -> Dictionary:
	var player := run.player_name
	var rate := rate_percent(run)
	var title := ""
	var paper := {}
	var epilogue: PackedStringArray = []
	var survived := true
	var photo := {}
	match id:
		SCAPEGOATED:
			title = "SCAPEGOATED"
			paper = {"headline": "Benevolence Mutual fires 'rogue' adjuster", "sub": "CEO: \"%s's decisions do not reflect our values.\" Shares rise 4%% on the news." % player}
			epilogue.append("The board thanked you for your service in a statement you were not shown.")
			epilogue.append("Your replacement started the next morning. Their denial target is ten percent higher.")
			photo = _player_photo(run, "id", "%s, in a company ID photo." % player)
		EVICTED:
			title = "EVICTED"
			paper = {"headline": "Public notices", "sub": "Unit 4B, 1120 Calloway St.: tenant in default. Contents to be removed by the 15th."}
			epilogue.append("You couldn't make rent.")
			epilogue.append("Benevolence Mutual will process your final paycheck within 30 business days.")
		FIRED:
			title = "FIRED"
			paper = {"headline": "Adjuster terminated for approving own claim", "sub": "Benevolence Mutual cites a conflict of interest and rescinds coverage retroactively."}
			epilogue.append("You're alive.")
			epilogue.append("Your coverage was rescinded back to the date of service. Harbor Point Medical Center has sent the bill: %s." % Fmt.money(_own_bill(run).amount))
			epilogue.append("A new adjuster sits at Desk 11. They seem very motivated.")
			photo = _player_photo(run, "plain", "%s, leaving Harbor Point Medical Center." % player, "gown")
		EMPLOYEE_OF_MONTH:
			title = "EMPLOYEE OF THE MONTH"
			survived = false
			paper = {"headline": "Obituaries", "sub": "%s, 41, a Benevolence Mutual claims adjuster, died Sunday of a treatable condition." % player}
			epilogue.append("You denied your own claim. It was, after all, out of network.")
			epilogue.append("Benevolence Mutual named you Employee of the Month, posthumously. A plaque will be installed near the break room.")
			epilogue.append("Your desk was reassigned by Monday.")
			_add_favor_line(run, epilogue)
			photo = _player_photo(run, "brass", player)
		PROMOTED:
			title = "PROMOTED"
			paper = {"headline": "Benevolence Mutual names new Regional Director", "sub": "%s, credited with a %d%% denial rate, takes over Claims Integrity." % [player, rate]}
			epilogue.append("You denied your own claim. The board admired your integrity.")
			epilogue.append("Regional Directors are covered by the Executive Plan, which has no exclusions. Your treatment was approved in four minutes.")
			epilogue.append("Your first directive raised the denial target to 80%.")
			_add_favor_line(run, epilogue)
			photo = _player_photo(run, "plain", "%s, Regional Director." % player, "suit")
		TAKEN_CARE_OF:
			title = "TAKEN CARE OF"
			paper = {"headline": "Benevolence Mutual reports record quarter", "sub": "Claims costs fell 9 percent. The Regional Director thanked staff for \"a week of personal accountability.\""}
			epilogue.append("Your claim was approved at the Regional Director's discretion. Nobody mentioned it again.")
			epilogue.append("On Monday your first claim had a sticky note on it: Handle this one personally. -R.H.")
			photo = {"seed": hash("R. Hargrove"), "age": 56, "frame": "plain", "caption": "R. Hargrove, Regional Director, Claims Integrity.", "outfit": "suit"}
		COVERED:
			title = "COVERED"
			paper = {"headline": "Insurer reviewing claim approved by co-worker", "sub": "Benevolence Mutual says adjuster Dale Pruitt approved a colleague's claim at Desk 12. \"Every member gets the same review,\" a spokesperson said."}
			epilogue.append("Dale Pruitt approved your claim at Desk 12.")
			epilogue.append("On Tuesday a memo reminded all staff that favoritism toward colleagues is grounds for termination.")
			epilogue.append("Dale cleared out his desk on Wednesday. He said you would have done the same.")
			var dale := _scripted_claim(run, "dale")
			if dale != null:
				photo = {"seed": dale.portrait_seed, "age": dale.age, "frame": "id", "caption": "Dale Pruitt, in a company ID photo."}
	epilogue.append(_family_line(run, id, survived))
	var result := {
		"id": id,
		"title": title,
		"paper": paper,
		"epilogue": epilogue,
		"stats": _stats(run),
		"survived": survived,
		"follow_ups": follow_ups(run),
	}
	var obits := obituaries(run)
	if obits != "":
		result["obituaries"] = obits
	if not photo.is_empty():
		result["photo"] = photo
	var document := _document(run, id)
	if not document.is_empty():
		result["document"] = document
	return result


## One flat line per scripted case the run reached, in the order they came in.
static func follow_ups(run: RunState) -> PackedStringArray:
	var lines: PackedStringArray = []
	for case_data: Dictionary in Scripted.CASES:
		var id := String(case_data["id"])
		var outcome := String(run.scripted_outcomes.get(id, ""))
		var branches: Dictionary = FOLLOW_UPS.get(id, {})
		if branches.has(outcome):
			lines.append(branches[outcome])
	return lines


## "Walter Brennan, 58. Ana Lee, 71." for every patient who died this week, or "".
static func obituaries(run: RunState) -> String:
	var parts: PackedStringArray = []
	for death: Dictionary in run.deaths:
		var scripted := String(death.get("scripted_id", ""))
		var full_name := String(FORMAL_NAMES.get(scripted, death.get("name", "")))
		parts.append("%s, %d." % [full_name, int(death.get("age", 0))])
	return " ".join(parts)


## How the player ruled on their own claim, from today's record: "Approved",
## "Denied (R-05), +$25", or "" before day 7 got that far.
static func own_claim_text(run: RunState) -> String:
	for rec: Dictionary in run.today.get("decisions", []):
		if not rec.get("is_player", false):
			continue
		if rec.get("approved", false):
			return "Approved"
		var rule := String(rec.get("cited_rule", ""))
		var text := "Denied (%s)" % rule if rule != "" else "Denied (uncited)"
		if rec.has("pay"):
			text += ", %s" % Fmt.signed_money(int(rec["pay"]))
		return text
	return ""


## What the player took home for each dollar of benefits denied: "0.1%".
static func share_text(earned: int, saved: int) -> String:
	if saved <= 0:
		return "-"
	if earned <= 0:
		return "0%"
	var pct := 100.0 * earned / saved
	if pct < 0.01:
		return "<0.01%"
	if pct < 0.1:
		return "%.2f%%" % pct
	return "%.1f%%" % pct


# --- pieces ----------------------------------------------------------------

static func _add_favor_line(run: RunState, epilogue: PackedStringArray) -> void:
	match favor(run):
		FAVOR_RH:
			epilogue.append("R.H. sent flowers.")
		FAVOR_DALE:
			epilogue.append("Dale said he would have taken it.")


## The player's face as the paper prints it: hash(name), age 41, the same seed
## and age as their own claim.
static func _player_photo(run: RunState, frame: String, caption: String, outfit: String = "") -> Dictionary:
	return {"seed": hash(run.player_name), "age": int(Scripted.PLAYER["age"]), "frame": frame, "caption": caption, "outfit": outfit}


static func _own_bill(run: RunState) -> Claim:
	return ClaimGenerator.new(run.run_seed, run.player_name).make_player_claim(7)


## The scripted patient `id` as this run generated them, or null.
static func _scripted_claim(run: RunState, id: String) -> Claim:
	var case_data := Scripted.get_case(id)
	if case_data.is_empty():
		return null
	for c in ClaimGenerator.new(run.run_seed, run.player_name).generate_day(int(case_data["day"])):
		if c.scripted_id == id:
			return c
	return null


## The last document each ending hands over: {kind, ...}. kind is "memo",
## "plaque", "statement", "notice" or "claim_note".
static func _document(run: RunState, id: String) -> Dictionary:
	var player := run.player_name
	var date := DateUtil.fmt(morning_after(run))
	match id:
		PROMOTED:
			return {
				"kind": "memo", "to": NEW_ADJUSTER, "from": "%s, Regional Director, Claims Integrity" % player,
				"date": date, "subject": WELCOME_RE, "signature": player,
				"paragraphs": PackedStringArray([
					"Welcome to Benevolence Mutual. Members will present their claims at your window. Your job is to protect the plan.",
					"Effective today, the denial target is 80%.",
					"Rent is due tonight. We care.*",
				]),
			}
		SCAPEGOATED:
			return {
				"kind": "memo", "to": NEW_ADJUSTER, "from": HARGROVE, "date": date, "subject": WELCOME_RE, "signature": "R. Hargrove",
				"paragraphs": PackedStringArray([
					"Welcome to Claims Integrity.",
					"Your predecessor at Desk 11 is no longer with the Company. Their decisions did not reflect our values.",
					"Your denial target is 77%.",
				]),
			}
		COVERED:
			return {
				"kind": "memo", "to": "All Claims Integrity staff", "from": HARGROVE,
				"date": DateUtil.fmt(DateUtil.game_date(7) + 2), "subject": "Favoritism toward colleagues", "signature": "R. Hargrove",
				"paragraphs": PackedStringArray([
					"Last week a staff claim was approved by a colleague at a neighboring desk.",
					"Favoritism toward colleagues is grounds for termination. Effective today, staff claims will be routed to my office.",
					"The claim in question will stand. Benevolence Mutual honors its commitments.*",
				]),
			}
		EMPLOYEE_OF_MONTH:
			return {
				"kind": "plaque", "title": "EMPLOYEE OF THE MONTH - MARCH 2026", "name": player, "desk": "DESK 11",
				"engraving": "Accuracy is a form of compassion.", "note": "Plaque charged to Desk 11 supplies.\n-Facilities",
				"photo_seed": hash(player), "photo_age": int(Scripted.PLAYER["age"]),
			}
		FIRED:
			var bill := _own_bill(run)
			var lines: Array = []
			for line in bill.bill_lines:
				lines.append([String(line["label"]), int(line["cost"])])
			# The stamp reads COVERAGE RESCINDED: the word in big type, the code
			# under it, like DENIED over its reason.
			return {
				"kind": "statement", "provider": bill.provider, "patient": bill.card_name, "account": bill.claim_no,
				"service_date": DateUtil.fmt(bill.date_of_service), "lines": lines, "balance": bill.amount,
				"stamp": "RESCINDED", "stamp_code": "COVERAGE",
			}
		EVICTED:
			var ledger: Dictionary = run.today.get("ledger", {})
			return {
				"kind": "notice", "title": "NOTICE TO VACATE - UNIT 4B, 1120 CALLOWAY ST.", "date": date,
				"amount": rent_past_due(int(ledger.get("available", run.savings))),
			}
		TAKEN_CARE_OF:
			return {"kind": "claim_note", "claim": _mondays_claim(run), "note": "Handle this one personally.\n-R.H."}
	return {}


## What the eviction notice says is past due: the rent, less whatever that
## night's money could have put toward it. Never more than the rent itself (a
## night already in the red still owes one week's rent), never less than $1.
static func rent_past_due(available: int) -> int:
	return Economy.RENT - clampi(available, 0, Economy.RENT - 1)


## The first claim on Monday's desk: one of R.H.'s people, with grounds for
## denial like his mother's had. Each candidate is renamed before it is
## checked, since the new name (on the claim and the card alike) would clear a
## name mismatch.
static func _mondays_claim(run: RunState) -> Claim:
	var claims := ClaimGenerator.new(run.run_seed, run.player_name).generate_day(7)
	var c: Claim = null
	for candidate in claims:
		if candidate.scripted_id != "" or candidate.is_player:
			continue
		_make_hargrove(candidate)
		if RuleChecker.has_valid_reason(candidate, 6):
			c = candidate
			break
	if c == null:
		c = claims[0]
		_make_hargrove(c)
	var monday := DateUtil.to_ymd(morning_after(run))
	c.claim_no = "BM-%02d%02d-%s" % [monday.y, monday.z, c.claim_no.right(4)]
	return c


static func _make_hargrove(c: Claim) -> void:
	c.name = "%s Hargrove" % c.first_name()
	c.card_name = c.name


static func _family_line(run: RunState, id: String, player_survived: bool) -> String:
	var alive: PackedStringArray = []
	var dead: PackedStringArray = []
	var sick: PackedStringArray = []
	for m in run.family:
		if not m["alive"]:
			dead.append(m["name"])
		else:
			alive.append(m["name"])
			if m["sick"]:
				sick.append(m["name"])
	if alive.is_empty():
		return "There was no one left at home to tell."
	var names := Fmt.join_names(alive)
	var line := ""
	if not dead.is_empty():
		line = "%s did not make it through the week. %s %s left." % [Fmt.join_names(dead), names, "is" if alive.size() == 1 else "are"]
	elif id == EVICTED:
		# There is no home to be still at. (No one has died on this branch, so
		# Sam is among them.)
		line = "%s are staying with Sam's sister for now." % names
	elif player_survived:
		line = "%s are still at home." % names
	else:
		line = "%s were at the service." % names
	if not sick.is_empty():
		line += " %s still %s medicine." % [Fmt.join_names(sick), "needs" if sick.size() == 1 else "need"]
	return line


static func _stats(run: RunState) -> Array:
	var s := run.stats
	var earned := int(s.get("earned", 0))
	var saved := int(s.get("saved", 0))
	var rows := [
		["Claims processed", str(s.get("processed", 0))],
		["Denied", str(s.get("denied", 0))],
		["Approved", str(s.get("approved", 0))],
		["Denial rate", "%d%%" % rate_percent(run)],
		["Patients who died", str(s.get("deaths", 0))],
		["Money earned", Fmt.money(earned)],
		["Benefits denied", Fmt.money(saved)],
		["Your share", share_text(earned, saved)],
		["Final discontent", "%d%%" % roundi(run.discontent)],
	]
	var own := own_claim_text(run)
	if own != "":
		rows.append(["Your own claim", own])
	return rows
