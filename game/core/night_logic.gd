class_name NightLogic
## End of shift: appeals, deaths, the household ledger, family health, public
## events, the night's game-over checks, and tomorrow's paper and memo.

const SCRIPTED_DEATHS: PackedStringArray = ["walt", "marcus"]
const RILEY_NIGHT := 3


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
		notes.append("Riley had an asthma attack at school. The ER claim was DENIED by Benevolence Mutual (R-05: Pre-existing condition). Riley needs medicine.")

	var t: Dictionary = run.today
	var legal := overturned.size() * Economy.LEGAL_FEE
	var income: Array[Dictionary] = [{"label": "Base pay", "amount": Economy.BASE_PAY}]
	_add_line(income, "Commissions", int(t["commissions"]))
	_add_line(income, "Approval deductions", -int(t["deductions"]))
	_add_line(income, "Citations", -int(t["fines"]))
	_add_line(income, "Compliance review fees", -int(t["fees"]))
	_add_line(income, "Legal fees (%d appeals lost)" % overturned.size(), -legal)
	_add_line(income, "Performance adjustment (R.H.)", -boss_penalty)
	var net := 0
	for line in income:
		net += int(line["amount"])
	var available := run.savings + net

	# Listed (and pre-checked while money lasts) by urgency: untreated sickness
	# kills in two nights, hunger and cold only make people sick.
	var bills: Array[Dictionary] = [{"id": "rent", "label": "Rent", "amount": Economy.RENT, "mandatory": true, "default_on": true}]
	for m in run.family:
		if m["alive"] and m["sick"]:
			bills.append({"id": "medicine:%s" % m["id"], "label": "Medicine (%s)" % m["name"], "amount": Economy.MEDICINE, "mandatory": false, "default_on": false})
	bills.append({"id": "food", "label": "Food", "amount": Economy.FOOD, "mandatory": false, "default_on": false})
	bills.append({"id": "heat", "label": "Heat", "amount": Economy.HEAT, "mandatory": false, "default_on": false})
	var budget := available - Economy.RENT
	for bill in bills:
		if not bill["mandatory"] and budget >= int(bill["amount"]):
			bill["default_on"] = true
			budget -= int(bill["amount"])

	var ledger := {
		"day": run.day,
		"savings_before": run.savings,
		"income": income,
		"net": net,
		"available": available,
		"bills": bills,
		"family": family_status(run),
		"notes": notes,
		"overturned": overturned,
		"deaths": deaths,
		"legal": legal,
		"penalty": boss_penalty,
		"evicted": available < Economy.RENT,
	}
	run.today["ledger"] = ledger
	return ledger


## Pays the chosen bills, updates the family, discontent and events, prepares the
## next morning and advances the day. Returns an ending id, or "" to keep playing.
static func apply_ledger(run: RunState, paid: Dictionary) -> String:
	var ledger: Dictionary = run.today["ledger"]
	if ledger["evicted"]:
		run.ending = Endings.EVICTED
		return run.ending

	var available: int = ledger["available"]
	var food_paid: bool = paid.get("food", false)
	var heat_paid: bool = paid.get("heat", false)
	var medicine: Dictionary = paid.get("medicine", {})
	var treated: Array[String] = []
	for m in run.family:
		if m["alive"] and m["sick"] and medicine.get(m["id"], false):
			treated.append(m["id"])
	# Never spend money that isn't there: drop medicine, then heat, then food.
	while _cost(food_paid, heat_paid, treated.size()) > available:
		if not treated.is_empty():
			treated.pop_back()
		elif heat_paid:
			heat_paid = false
		else:
			food_paid = false
	run.savings = available - _cost(food_paid, heat_paid, treated.size())

	var family_deaths: Array[String] = []
	for m in run.family:
		if not m["alive"]:
			continue
		if m["sick"]:
			if treated.has(m["id"]):
				m["sick"] = false
				m["sick_nights"] = 0
			else:
				m["sick_nights"] += 1
				if m["sick_nights"] >= 2:
					m["alive"] = false
					family_deaths.append(m["name"])
					continue
		m["hungry"] = 0 if food_paid else int(m["hungry"]) + 1
		m["cold"] = 0 if heat_paid else int(m["cold"]) + 1
		if not m["sick"] and (m["hungry"] >= 2 or m["cold"] >= 2):
			m["sick"] = true
			m["sick_nights"] = 0

	var deaths: Array = ledger["deaths"]
	var overturned: Array = ledger["overturned"]
	for rec: Dictionary in deaths:
		run.deaths.append({"name": rec["name"], "age": rec["age"], "diagnosis": rec["diagnosis"], "day": run.day, "scripted_id": rec["scripted_id"]})
	run.stats["deaths"] += deaths.size()
	run.stats["earned"] += Economy.BASE_PAY - int(ledger["legal"]) - int(ledger["penalty"])
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
	run.morning = {
		"paper": NewsWriter.build_paper(run, yesterday, news_rng),
		"memo": NewsWriter.build_memo(run, yesterday),
		"letters": NewsWriter.build_letters(run, yesterday),
	}
	run.reset_today()
	return run.ending


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


static func _dies(rec: Dictionary, rng: RandomNumberGenerator) -> bool:
	var scripted: String = rec["scripted_id"]
	if scripted != "":
		return SCRIPTED_DEATHS.has(scripted)
	return rng.randf() < Economy.DEATH_CHANCE[int(rec["priority"])]


static func _cost(food: bool, heat: bool, medicines: int) -> int:
	return Economy.RENT + (Economy.FOOD if food else 0) + (Economy.HEAT if heat else 0) + medicines * Economy.MEDICINE


static func _add_line(lines: Array[Dictionary], label: String, amount: int) -> void:
	if amount != 0:
		lines.append({"label": label, "amount": amount})
