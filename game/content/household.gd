class_name Household
## What the family needs beyond rent, food and heat: two prescriptions the plan
## won't cover, and on some nights one thing going wrong at home. Prices are in
## Economy; NightLogic applies the consequences.
##
## A "night" is the evening after that day's shift (night 2 follows day 2).

## Nights that bring a household event, one each.
const EVENT_NIGHTS: Array[int] = [2, 4, 5, 6]

## Billed every night from `from_night` while `member` is alive. Two unpaid
## nights in a row make them sick, the same rule as hunger. `key` indexes
## RunState.household["missed"]; `missing` names it in the family row's warning.
const PRESCRIPTIONS: Array[Dictionary] = [
	{
		"id": "rx:pills", "key": "pills", "member": "mother", "from_night": 2,
		"label": "Mom's heart pills", "note": "(not covered: R-06)",
		"status": "NO PILLS", "missing": "pills",
	},
	{
		"id": "rx:inhaler", "key": "inhaler", "member": "child", "from_night": 4,
		"label": "Riley's controller inhaler", "note": "(not covered: R-05, pre-existing)",
		"status": "NO INHALER", "missing": "the inhaler",
	},
]

## The event pool, drawn without repeats in an order fixed by the run seed.
## `who` is the family member it concerns ("" for the household): an event whose
## subject has died is passed over. `skip` is what an unpaid bill does:
##   none      nothing, beyond the line itself
##   no_heat   no heat tonight or tomorrow night
##   sick      `who` falls sick tonight
##   discount  not a bill: every pharmacy bill tonight (medicine, prescriptions)
##             costs Economy.COUPON_OFF less. Passed over on a night with no
##             pharmacy bill, so it never turns up with nothing to take off.
## `text` is the night's line on the ledger; {cost} is the price (the discount).
const EVENTS: Array[Dictionary] = [
	{
		"id": "furnace", "who": "", "skip": "no_heat", "label": "Furnace repair",
		"text": "The furnace quit. Repair {cost}.", "note": "(skip: no heat tonight or tomorrow)",
	},
	{
		"id": "dentist", "who": "partner", "skip": "sick", "label": "Dentist (Sam)",
		"text": "Sam's tooth abscess. Benevolence Mutual: DENIED (R-04, no prior authorization). Dentist {cost}.",
		"note": "(skip: Sam gets sick)",
	},
	{
		"id": "class_trip", "who": "child", "skip": "none", "label": "Class trip (Riley)",
		"text": "Riley's class trip to the science museum, {cost}.", "note": "(skip: Riley stays home)",
	},
	{
		"id": "collection", "who": "mother", "skip": "none", "label": "Collection agency",
		"text": "A collection agency called about Mom's ER visit from last fall. {cost} stops the calls.",
		"note": "(skip: the calls continue)",
	},
	{
		"id": "coupon", "who": "partner", "skip": "discount", "label": "",
		"text": "Sam found a pharmacy coupon: {cost} off medicine and prescriptions tonight.", "note": "",
	},
	{
		"id": "glasses", "who": "mother", "skip": "none", "label": "Reading glasses (Mom)",
		"text": "Mom's reading glasses broke. A drugstore pair is {cost}.", "note": "(skip: Mom goes without)",
	},
	{
		"id": "bus_pass", "who": "partner", "skip": "none", "label": "Bus pass (Sam)",
		"text": "Sam's bus pass ran out. A weekly pass is {cost}.", "note": "(skip: Sam walks)",
	},
]


## Every event id, shuffled once from the run seed: the order the week draws them in.
static func event_order(run_seed: int) -> PackedStringArray:
	var ids: PackedStringArray = []
	for e in EVENTS:
		ids.append(e["id"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "household"])
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	return ids


## Tonight's event, or {} on a quiet night: the first event in the run's order
## not yet `seen` whose subject is in `alive_ids` (household events always qualify).
## `pharmacy` says whether tonight's ledger bills medicine or a prescription;
## without one the coupon is passed over and keeps its place for a later night.
## Returns a copy with `cost`, the formatted `text` and its ledger `bill_id`.
static func event_for(run_seed: int, night: int, seen: PackedStringArray, alive_ids: PackedStringArray, pharmacy: bool = true) -> Dictionary:
	if not EVENT_NIGHTS.has(night):
		return {}
	for id in event_order(run_seed):
		if seen.has(id):
			continue
		var e := event(id)
		var who: String = e["who"]
		if who != "" and not alive_ids.has(who):
			continue
		if e["skip"] == "discount" and not pharmacy:
			continue
		return e
	return {}


## One event by id with its price filled in, or {}.
static func event(id: String) -> Dictionary:
	for e: Dictionary in EVENTS:
		if e["id"] == id:
			var copy := e.duplicate(true)
			var discount: bool = e["skip"] == "discount"
			copy["cost"] = 0 if discount else int(Economy.HOUSEHOLD_EVENT_COST.get(id, 0))
			var shown: int = Economy.COUPON_OFF if discount else int(copy["cost"])
			copy["text"] = String(e["text"]).format({"cost": Fmt.money(shown)})
			copy["bill_id"] = "" if discount else "event:%s" % id
			return copy
	return {}


## The prescription billed under `bill_id`, or {}.
static func prescription(bill_id: String) -> Dictionary:
	for rx: Dictionary in PRESCRIPTIONS:
		if rx["id"] == bill_id:
			return rx
	return {}


## The prescription `member_id` takes, or {}.
static func prescription_for(member_id: String) -> Dictionary:
	for rx: Dictionary in PRESCRIPTIONS:
		if rx["member"] == member_id:
			return rx
	return {}
