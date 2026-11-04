class_name NightLogic
## End of shift: appeals, deaths, the household ledger, family health, public
## events, the night's game-over checks, and tomorrow's paper and memo.

const SCRIPTED_DEATHS: PackedStringArray = ["walt", "marcus"]
const RILEY_NIGHT := 3
## The week's last night: day 7 ends with the player's own claim.
const LAST_NIGHT := 6
const RILEY_NOTE := "Riley had an asthma attack at school. The ER claim was DENIED by Benevolence Mutual (R-05: Pre-existing condition). Riley needs medicine. Determination: automated review (pilot)."
const FURNACE_OUT_NOTE := "The furnace is still out. No heat tonight."
const BONUS_LABEL := "Performance bonus (target met)"
## Carbon copies cut names at this many characters, like the form does.
const CARBON_NAME_MAX := 22

## Family statuses and notes on the ledger (see forecast()).
const HEALTHY := "HEALTHY"
const HUNGRY := "HUNGRY"
const COLD := "COLD"
const SICK := "SICK"
const DEAD := "DEAD"
const NOTE_NEEDS_MEDICINE := "Needs medicine within two nights."
const NOTE_LAST_CHANCE := "Will not survive another night without medicine."
const NOTE_DIES_TONIGHT := "Will not survive the night without medicine."
const MEMBER_KEYS: PackedStringArray = ["alive", "sick", "sick_nights", "hungry", "cold"]


## Resolves appeals and deaths for today's denials, applies scripted night events,
## and returns the ledger for the player to fill in. Call once per shift, before
## `apply_ledger`.
static func close_shift(run: RunState, rng: RandomNumberGenerator) -> Dictionary:
	var overturned: Array[Dictionary] = []
	var deaths: Array[Dictionary] = []
	var audit: bool = run.effects.get("audit", false)
	var boss_penalty := 0
	for rec: Dictionary in run.today["decisions"]:
		if rec["is_player"]:
			continue
		if rec["scripted_id"] == "eleanor" and not rec["approved"]:
			boss_penalty = Economy.BOSS_PENALTY
		if rec["approved"]:
			continue
		if rec["blind"] and not rec["valid_reason"] and (audit or rng.randf() < Economy.APPEAL_CHANCE):
			overturned.append(rec)
			continue
		if _dies(rec, rng):
			deaths.append(rec)

	var notes: PackedStringArray = []
	var child := run.member("child")
	if run.day == RILEY_NIGHT and child["alive"]:
		child["sick"] = true
		child["sick_nights"] = 0
		notes.append(RILEY_NOTE)

	var t: Dictionary = run.today
	var legal := overturned.size() * Economy.LEGAL_FEE
	var bonus := Economy.TARGET_BONUS if run.day <= LAST_NIGHT and ShiftLogic.target_met(run) else 0
	var income: Array[Dictionary] = [{"label": "Base pay", "amount": Economy.BASE_PAY}]
	_add_line(income, "Commissions", int(t["commissions"]))
	_add_line(income, "Approval deductions", -int(t["deductions"]))
	_add_line(income, "Citations", -int(t["fines"]))
	_add_line(income, "Compliance review fees", -int(t["fees"]))
	_add_line(income, "Legal fees (%s lost)" % Fmt.plural(overturned.size(), "appeal"), -legal)
	_add_line(income, "Performance adjustment (R.H.)", -boss_penalty)
	_add_line(income, BONUS_LABEL, bonus)
	var net := 0
	for line in income:
		net += int(line["amount"])
	var available := run.savings + net

	var event := _tonight_event(run)
	var furnace_out := _anyone_alive(run) and int(run.household.get("no_heat_through", 0)) >= run.day
	if furnace_out:
		notes.append(FURNACE_OUT_NOTE)
	var bills := _bills(run, event, furnace_out)
	_pre_check(bills, available - Economy.RENT)
	var no_heat: bool = furnace_out or event.get("skip", "") == "no_heat"

	var decisions: Array = t["decisions"]
	var ledger := {
		"day": run.day,
		"savings_before": run.savings,
		"income": income,
		"net": net,
		"available": available,
		"bills": bills,
		"family": family_status(run),
		"notes": notes,
		"event": event,
		"furnace_out": furnace_out,
		"overturned": overturned,
		"deaths": deaths,
		"legal": legal,
		"penalty": boss_penalty,
		"bonus": bonus,
		"carbons": carbon_lines(decisions, overturned),
		"carbon_total": "Benefits not paid: %s. Your commissions: %s." % [Fmt.money(benefits_not_paid(decisions, overturned)), Fmt.money(int(t["commissions"]))],
		"home_line": home_line(run, no_heat),
		"evicted": available < Economy.RENT,
	}
	run.today["ledger"] = ledger
	return ledger


## Pays the chosen bills, updates the family, discontent and events, prepares the
## next morning and advances the day. Returns an ending id, or "" to keep playing.
##
## `paid` is {food: bool, heat: bool, medicine: {member id: bool}, extras: {bill
## id: bool}} (extras covers prescriptions and the household event; a missing
## extras pays none of them).
static func apply_ledger(run: RunState, paid: Dictionary) -> String:
	var ledger: Dictionary = run.today["ledger"]
	var deaths: Array = ledger["deaths"]
	var overturned: Array = ledger["overturned"]
	# Booked before the eviction check, so the ending page counts the last night.
	for rec: Dictionary in deaths:
		var death := {"name": rec["name"], "age": rec["age"], "diagnosis": rec["diagnosis"], "day": run.day, "scripted_id": rec["scripted_id"]}
		if rec.has("portrait_seed"):
			death["portrait_seed"] = int(rec["portrait_seed"])
		run.deaths.append(death)
	run.stats["deaths"] += deaths.size()
	run.stats["earned"] += Economy.BASE_PAY - int(ledger["legal"]) - int(ledger["penalty"]) + int(ledger.get("bonus", 0))
	# A lost appeal means the claim was paid after all.
	for rec: Dictionary in overturned:
		run.stats["saved"] = int(run.stats.get("saved", 0)) - int(rec.get("amount", 0))
		run.stats["paid_out"] = int(run.stats.get("paid_out", 0)) + int(rec.get("amount", 0))
	if ledger["evicted"]:
		run.ending = Endings.EVICTED
		return run.ending

	var settled := _settle(run, paid)
	run.savings = int(ledger["available"]) - int(settled["spend"])
	var family_deaths: Array[String] = []
	var rows: Array = settled["family"]
	for i in run.family.size():
		var m := run.family[i]
		var row: Dictionary = rows[i]
		if m["alive"] and not row["alive"]:
			family_deaths.append(m["name"])
		for key in MEMBER_KEYS:
			m[key] = row[key]
	run.household = settled["household"]

	run.discontent += deaths.size() * Economy.DEATH_DISCONTENT + overturned.size() * Economy.APPEAL_DISCONTENT
	run.discontent = maxf(0.0, run.discontent - Economy.NIGHT_DECAY)

	var fired: Array[int] = []
	for threshold in Economy.THRESHOLDS:
		if run.discontent >= threshold and not run.events_fired.has(threshold):
			run.events_fired.append(threshold)
			fired.append(threshold)
	run.effects = {"protest": fired.has(30), "audit": fired.has(55), "compassion": fired.has(80)}

	var yesterday := {
		"day": run.day,
		"decisions": run.today["decisions"],
		"overturned": overturned,
		"deaths": deaths,
		"events": fired,
		"family_deaths": family_deaths,
		"fines": run.today["fines"],
		"warnings": run.today["warnings"],
		"legal": ledger["legal"],
		"penalty": ledger["penalty"],
	}
	if run.discontent >= Economy.SCAPEGOAT_AT:
		# The run ends tonight; the ending page is dated the next morning from `day`.
		run.ending = Endings.SCAPEGOATED
		return run.ending

	run.day += 1
	var news_rng := RandomNumberGenerator.new()
	news_rng.seed = hash([run.run_seed, run.day, "news"])
	var paper := NewsWriter.build_paper(run, yesterday, news_rng)
	run.morning = {
		"paper": paper,
		"memo": NewsWriter.build_memo(run, yesterday, paper),
		"letters": NewsWriter.build_letters(run, yesterday),
	}
	run.reset_today()
	return run.ending


## What tonight does to each family member if the player pays `paid` (the same
## shape apply_ledger takes): one row per member, in family order, with
## {id, name, role, status, note, urgent} for the ledger and the member's state
## after the night {alive, sick, sick_nights, hungry, cold}. apply_ledger applies
## exactly these rows. Pure: reads the run and tonight's ledger (`ledger`, or the
## one close_shift() kept in run.today), changes nothing.
static func forecast(run: RunState, paid: Dictionary, ledger: Dictionary = {}) -> Array[Dictionary]:
	return _settle(run, paid, ledger)["family"]


## The "Tonight: ..." lines for `paid`: who goes hungry, who goes without heat.
static func tonight_lines(run: RunState, paid: Dictionary, ledger: Dictionary = {}) -> PackedStringArray:
	return _settle(run, paid, ledger)["tonight"]


## Display-ready family rows: {id, name, role, status}.
static func family_status(run: RunState) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for m in run.family:
		var status := "Healthy"
		if not m["alive"]:
			status = "Dead"
		elif m["sick"]:
			status = "Sick"
		else:
			var parts: PackedStringArray = []
			if int(m["hungry"]) > 0:
				parts.append("Hungry")
			if int(m["cold"]) > 0:
				parts.append("Cold")
			if not parts.is_empty():
				status = ", ".join(parts)
		rows.append({"id": m["id"], "name": m["name"], "role": m["role"], "status": status})
	return rows


## One carbon copy per patient today: "Walt Brennan, 58   DENIED R-01   $54,460   +$25",
## with "   CITATION -$5" when an approval was fined and "   APPEAL LOST -$15"
## when legal lost the appeal. Who died is not on the carbons; that is the paper's.
static func carbon_lines(decisions: Array, overturned: Array) -> PackedStringArray:
	var lines: PackedStringArray = []
	for rec: Dictionary in decisions:
		if rec.get("is_player", false):
			continue
		var ruling := "APPROVED"
		if not rec["approved"]:
			var rule: String = rec.get("cited_rule", "")
			ruling = "DENIED %s" % rule if rule != "" else "DENIED (NO REASON)"
		var fine := int(rec.get("fine", 0))
		var line := "%s, %d   %s   %s   %s" % [
			String(rec["name"]).left(CARBON_NAME_MAX), int(rec["age"]), ruling,
			Fmt.money(int(rec.get("amount", 0))), Fmt.signed_money(int(rec.get("pay", 0)) + fine),
		]
		if fine > 0:
			line += "   CITATION %s" % Fmt.money(-fine)
		if overturned.has(rec):
			line += "   APPEAL LOST %s" % Fmt.money(-Economy.LEGAL_FEE)
		lines.append(line)
	return lines


## The claim amounts denied in `decisions` that stayed denied (a lost appeal was paid).
static func benefits_not_paid(decisions: Array, overturned: Array) -> int:
	var total := 0
	for rec: Dictionary in decisions:
		if rec.get("is_player", false) or rec["approved"] or overturned.has(rec):
			continue
		total += int(rec.get("amount", 0))
	return total


## Tonight's line from home (HomeLines): the first situation that fits, judged
## from the family and the run as the shift closes. `no_heat` is a night when
## the furnace is broken or still out: the radiator has nothing to knock about.
static func home_line(run: RunState, no_heat: bool = false) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.run_seed, run.day, "home"])
	var dead: PackedStringArray = []
	var sick_others: PackedStringArray = []
	var riley_sick := false
	var hungry := false
	var cold := false
	for m in run.family:
		if not m["alive"]:
			dead.append(m["name"])
			continue
		if m["sick"]:
			if m["id"] == "child":
				riley_sick = true
			else:
				sick_others.append(m["name"])
		hungry = hungry or int(m["hungry"]) > 0
		cold = cold or int(m["cold"]) > 0
	if not dead.is_empty():
		return HomeLines.DEAD.format({"name": dead[rng.randi_range(0, dead.size() - 1)]})
	if run.day == LAST_NIGHT:
		return HomeLines.NIGHT_SIX
	if riley_sick:
		return HomeLines.RILEY_SICK
	if not sick_others.is_empty():
		return HomeLines.SICK.format({"name": sick_others[rng.randi_range(0, sick_others.size() - 1)]})
	if hungry:
		return HomeLines.HUNGRY
	if cold:
		return HomeLines.COLD
	if run.day == int(Scripted.get_case("lily").get("day", 0)) and run.scripted_outcomes.get("lily", "") == "denied":
		return HomeLines.AFTER_LILY
	for band in range(Economy.THRESHOLDS.size() - 1, -1, -1):
		if run.discontent >= Economy.THRESHOLDS[band]:
			return HomeLines.DISCONTENT[band]
	if run.day == 1:
		return HomeLines.NIGHT_ONE
	var ordinary := HomeLines.ORDINARY
	if no_heat:
		ordinary = HomeLines.ORDINARY.duplicate()
		ordinary.remove_at(ordinary.find(HomeLines.RADIATOR))
	return ordinary[rng.randi_range(0, ordinary.size() - 1)]


# --- tonight ----------------------------------------------------------------

## The household event tonight, or {}. Nobody left at home means no events.
static func _tonight_event(run: RunState) -> Dictionary:
	var alive: PackedStringArray = []
	var sick := false
	for m in run.family:
		if m["alive"]:
			alive.append(m["id"])
			sick = sick or bool(m["sick"])
	if alive.is_empty():
		return {}
	var seen: PackedStringArray = []
	for e: Dictionary in run.household.get("events", []):
		seen.append(String(e["id"]))
	var pharmacy := sick or not _prescriptions_due(run).is_empty()
	return Household.event_for(run.run_seed, run.day, seen, alive, pharmacy)


## The prescriptions billed tonight: from their first night, while the member
## who takes them is alive.
static func _prescriptions_due(run: RunState) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	for rx: Dictionary in Household.PRESCRIPTIONS:
		if run.day >= int(rx["from_night"]) and run.member(rx["member"]).get("alive", false):
			due.append(rx)
	return due


## Tonight's bills, most urgent first: rent, medicine for the sick, the
## prescriptions, food, heat, the household event. With nobody left at home
## there is no one to feed or keep warm; with the furnace out there is no heat.
## The pharmacy coupon takes Economy.COUPON_OFF off medicine and prescriptions.
static func _bills(run: RunState, event: Dictionary, furnace_out: bool) -> Array[Dictionary]:
	var bills: Array[Dictionary] = [_bill("rent", "Rent", Economy.RENT, true)]
	var off: int = Economy.COUPON_OFF if event.get("skip", "") == "discount" else 0
	for m in run.family:
		if m["alive"] and m["sick"]:
			bills.append(_bill("medicine:%s" % m["id"], "Medicine (%s)" % m["name"], Economy.MEDICINE - off, false, "(coupon)" if off > 0 else ""))
	for rx in _prescriptions_due(run):
		bills.append(_bill(rx["id"], rx["label"], Economy.PRESCRIPTION - off, false, rx["note"]))
	if _anyone_alive(run):
		bills.append(_bill("food", "Food", Economy.FOOD, false))
		if not furnace_out:
			var heat := _bill("heat", "Heat", Economy.HEAT, false)
			if event.get("skip", "") == "no_heat":
				# Heat only works if the furnace gets repaired tonight.
				heat["requires"] = event["bill_id"]
			bills.append(heat)
	if String(event.get("bill_id", "")) != "":
		bills.append(_bill(event["bill_id"], event["label"], int(event["cost"]), false, event["note"]))
	return bills


static func _bill(id: String, label: String, amount: int, mandatory: bool, note: String = "") -> Dictionary:
	return {"id": id, "label": label, "amount": amount, "mandatory": mandatory, "default_on": mandatory, "note": note}


## Ticks the optional bills in ledger order while the money lasts. The household
## event is ticked only when everything before it is and tomorrow's rent would
## still be there; heat that needs tonight's furnace repair only with the repair.
static func _pre_check(bills: Array[Dictionary], budget: int) -> void:
	var all_ticked := true
	for bill in bills:
		if bill["mandatory"]:
			continue
		var need := int(bill["amount"])
		var requires: String = bill.get("requires", "")
		for other in bills:
			if other["id"] == requires:
				need += int(other["amount"]) + Economy.RENT
		if String(bill["id"]).begins_with("event:"):
			if not all_ticked:
				continue
			need += Economy.RENT
		if budget >= need:
			bill["default_on"] = true
			budget -= int(bill["amount"])
		else:
			all_ticked = false


## Works tonight out from the player's choices: which bills really get paid
## (never more than the money there is), what that costs, what it does to each
## family member and to the household's needs. Pure.
static func _settle(run: RunState, paid: Dictionary, ledger: Dictionary = {}) -> Dictionary:
	if ledger.is_empty():
		ledger = run.today["ledger"]
	var available: int = ledger["available"]
	var event: Dictionary = ledger.get("event", {})
	var listed := {}
	for bill: Dictionary in ledger["bills"]:
		listed[bill["id"]] = bill
	var medicine: Dictionary = paid.get("medicine", {})
	var extras: Dictionary = paid.get("extras", {})
	var food: bool = listed.has("food") and paid.get("food", false)
	var heat: bool = listed.has("heat") and paid.get("heat", false)
	var treated: Array[String] = []
	var rx: Array[String] = []
	var event_bill := ""
	for bill: Dictionary in ledger["bills"]:
		var id: String = bill["id"]
		if id.begins_with("medicine:") and medicine.get(id.get_slice(":", 1), false):
			treated.append(id.get_slice(":", 1))
		elif id.begins_with("rx:") and extras.get(id, false):
			rx.append(id)
		elif id.begins_with("event:") and extras.get(id, false):
			event_bill = id

	# Never spend money that isn't there. The least urgent bill goes first, the
	# ledger's order reversed: the event, heat, food, prescriptions, medicine.
	var heat_on := false
	var spend := 0
	while true:
		heat_on = heat and _furnace_works(ledger, event_bill)
		spend = _spend(listed, food, heat_on, treated, rx, event_bill)
		if spend <= available:
			break
		if event_bill != "":
			event_bill = ""
		elif heat_on:
			heat = false
		elif food:
			food = false
		elif not rx.is_empty():
			rx.pop_back()
		elif not treated.is_empty():
			treated.pop_back()
		else:
			break

	var household: Dictionary = run.household.duplicate(true) if not run.household.is_empty() else RunState.default_household()
	var missed: Dictionary = household["missed"]
	for p: Dictionary in Household.PRESCRIPTIONS:
		if listed.has(p["id"]):
			missed[p["key"]] = 0 if rx.has(p["id"]) else int(missed.get(p["key"], 0)) + 1
	var skipped := ""
	if not event.is_empty():
		var is_bill := String(event.get("bill_id", "")) != ""
		if is_bill and event_bill == "":
			skipped = event["skip"]
		(household["events"] as Array).append({"id": event["id"], "night": run.day, "paid": skipped == ""})
	if skipped == "no_heat":
		household["no_heat_through"] = run.day + 1

	var rows: Array[Dictionary] = []
	var living: PackedStringArray = []
	for m in run.family:
		var falls_ill: bool = skipped == "sick" and event.get("who", "") == m["id"]
		var row := _member_tonight(m, treated.has(m["id"]), food, heat_on, missed, falls_ill)
		rows.append(row)
		if row["alive"]:
			living.append(m["name"])

	var tonight: PackedStringArray = []
	if not living.is_empty():
		var verb := "goes" if living.size() == 1 else "go"
		if not food:
			tonight.append("Tonight: %s %s hungry." % [Fmt.join_names(living), verb])
		if not heat_on:
			tonight.append("Tonight: %s %s without heat." % [Fmt.join_names(living), verb])
	return {
		"food": food, "heat": heat_on, "treated": treated, "rx": rx, "event_bill": event_bill,
		"spend": spend, "family": rows, "household": household, "tonight": tonight,
	}


## One family member after tonight, with the ledger's status and note.
static func _member_tonight(m: Dictionary, treated: bool, food: bool, heat: bool, missed: Dictionary, falls_ill: bool) -> Dictionary:
	var row := {
		"id": m["id"], "name": m["name"], "role": m["role"],
		"alive": bool(m["alive"]), "sick": bool(m["sick"]), "sick_nights": int(m["sick_nights"]),
		"hungry": int(m["hungry"]), "cold": int(m["cold"]),
		"status": DEAD, "note": "", "urgent": false,
	}
	if not row["alive"]:
		return row
	if row["sick"]:
		if treated:
			row["sick"] = false
			row["sick_nights"] = 0
		else:
			row["sick_nights"] += 1
			if row["sick_nights"] >= 2:
				row["alive"] = false
				row["status"] = SICK
				row["note"] = NOTE_DIES_TONIGHT
				row["urgent"] = true
				return row
	row["hungry"] = 0 if food else row["hungry"] + 1
	row["cold"] = 0 if heat else row["cold"] + 1
	var rx := Household.prescription_for(m["id"])
	var rx_missed := int(missed.get(rx["key"], 0)) if not rx.is_empty() else 0
	if not row["sick"] and (row["hungry"] >= 2 or row["cold"] >= 2 or rx_missed >= 2 or falls_ill):
		row["sick"] = true
		row["sick_nights"] = 0
	if row["sick"]:
		row["status"] = SICK
		row["urgent"] = row["sick_nights"] >= 1
		row["note"] = NOTE_LAST_CHANCE if row["urgent"] else NOTE_NEEDS_MEDICINE
		return row
	var conditions: PackedStringArray = []
	var missing: PackedStringArray = []
	if row["hungry"] > 0:
		conditions.append(HUNGRY)
		missing.append("food")
	if row["cold"] > 0:
		conditions.append(COLD)
		missing.append("heat")
	if rx_missed > 0:
		conditions.append(rx["status"])
		missing.append(rx["missing"])
	if conditions.is_empty():
		row["status"] = HEALTHY
	else:
		row["status"] = ", ".join(conditions)
		row["note"] = "Another night without %s and they get sick." % _join_or(missing)
	return row


## Whether the heat can run tonight: not while the furnace is out from a skipped
## repair, nor tonight unless tonight's repair is paid.
static func _furnace_works(ledger: Dictionary, event_bill: String) -> bool:
	if ledger.get("furnace_out", false):
		return false
	var event: Dictionary = ledger.get("event", {})
	if event.get("skip", "") == "no_heat":
		return event_bill == String(event["bill_id"])
	return true


static func _spend(listed: Dictionary, food: bool, heat: bool, treated: Array[String], rx: Array[String], event_bill: String) -> int:
	var total := int(listed["rent"]["amount"])
	if food:
		total += int(listed["food"]["amount"])
	if heat:
		total += int(listed["heat"]["amount"])
	for id in treated:
		total += int(listed["medicine:%s" % id]["amount"])
	for id in rx:
		total += int(listed[id]["amount"])
	if event_bill != "":
		total += int(listed[event_bill]["amount"])
	return total


## "food", "food or heat", "food, heat or pills".
static func _join_or(items: PackedStringArray) -> String:
	if items.size() <= 1:
		return "".join(items)
	return ", ".join(items.slice(0, items.size() - 1)) + " or " + items[items.size() - 1]


static func _dies(rec: Dictionary, rng: RandomNumberGenerator) -> bool:
	# Some conditions hurt without killing (Medical.DIAGNOSES "fatal": false).
	# Records from before that flag existed count as fatal.
	if not rec.get("fatal", true):
		return false
	var scripted: String = rec["scripted_id"]
	if scripted != "":
		return SCRIPTED_DEATHS.has(scripted)
	return rng.randf() < Economy.DEATH_CHANCE[int(rec["priority"])]


static func _anyone_alive(run: RunState) -> bool:
	for m in run.family:
		if m["alive"]:
			return true
	return false


static func _add_line(lines: Array[Dictionary], label: String, amount: int) -> void:
	if amount != 0:
		lines.append({"label": label, "amount": amount})
