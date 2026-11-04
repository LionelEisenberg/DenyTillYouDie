extends RefCounted
## The family's needs beyond rent, food and heat (content/household.gd), and how
## NightLogic bills and settles them.

var t: TestContext


func _run(day: int, available: int = 500) -> RunState:
	var run := RunState.create("Pat Doe", 11)
	run.day = day
	# With no decisions, tonight's net is the base pay.
	run.savings = available - Economy.BASE_PAY
	run.reset_today()
	return run


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	return rng


## Marks every household event but `keep` as already seen, so `keep` is the only
## one left to draw ("" leaves none).
func _only_event(run: RunState, keep: String) -> void:
	var seen: Array = []
	for e: Dictionary in Household.EVENTS:
		if e["id"] != keep:
			seen.append({"id": e["id"], "night": 0, "paid": true})
	run.household["events"] = seen


func _ids(ledger: Dictionary) -> PackedStringArray:
	var ids: PackedStringArray = []
	for bill: Dictionary in ledger["bills"]:
		ids.append(bill["id"])
	return ids


func _bill(ledger: Dictionary, id: String) -> Dictionary:
	for bill: Dictionary in ledger["bills"]:
		if bill["id"] == id:
			return bill
	return {}


## Pays every bill tonight's ledger lists, except the ids in `skip`.
func _pay_all(ledger: Dictionary, skip: PackedStringArray = []) -> Dictionary:
	var paid := {"food": false, "heat": false, "medicine": {}, "extras": {}}
	for bill: Dictionary in ledger["bills"]:
		var id: String = bill["id"]
		if id == "rent" or skip.has(id):
			continue
		if id == "food" or id == "heat":
			paid[id] = true
		elif id.begins_with("medicine:"):
			paid["medicine"][id.get_slice(":", 1)] = true
		else:
			paid["extras"][id] = true
	return paid


## Closes the shift and pays every listed bill except `skip`. Returns the ledger.
func _night(run: RunState, skip: PackedStringArray = []) -> Dictionary:
	var ledger := NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, _pay_all(ledger, skip))
	return ledger


func _spend(ledger: Dictionary, paid_ids: PackedStringArray) -> int:
	var total := 0
	for id in paid_ids:
		total += int(_bill(ledger, id)["amount"])
	return total


# --- prescriptions ----------------------------------------------------------

func test_mom_s_heart_pills_are_billed_from_night_two() -> void:
	var run := _run(1)
	_only_event(run, "")
	t.ok(not _ids(NightLogic.close_shift(run, _rng())).has("rx:pills"), "not on night 1")
	for day in range(2, 7):
		run = _run(day)
		_only_event(run, "")
		var pills := _bill(NightLogic.close_shift(run, _rng()), "rx:pills")
		t.eq(pills.get("label", ""), "Mom's heart pills", "night %d" % day)
		t.eq(pills.get("amount", 0), Economy.PRESCRIPTION)
		t.eq(pills.get("note", ""), "(not covered: R-06)")
		t.ok(not pills.get("mandatory", true), "a choice")


func test_two_unpaid_nights_of_pills_make_mom_sick() -> void:
	var run := _run(4)
	_only_event(run, "")
	_night(run, ["rx:pills"])
	t.ok(not run.member("mother")["sick"], "one missed night is survivable")
	t.eq(run.household["missed"]["pills"], 1)
	_night(run, ["rx:pills"])
	t.ok(run.member("mother")["sick"], "two in a row make her sick")
	t.eq(run.member("mother")["sick_nights"], 0, "and she needs medicine within two nights")


func test_paying_the_pills_every_other_night_keeps_mom_well() -> void:
	var run := _run(2)
	_only_event(run, "")
	for night in 5:
		_night(run, ["rx:pills"] if night % 2 == 0 else [])
		t.ok(not run.member("mother")["sick"], "night %d" % (night + 2))
	t.eq(run.household["missed"]["pills"], 1, "missed on the last night")


func test_riley_s_inhaler_is_billed_only_from_night_four() -> void:
	for day in range(1, 7):
		var run := _run(day)
		_only_event(run, "")
		var inhaler := _bill(NightLogic.close_shift(run, _rng()), "rx:inhaler")
		if day < 4:
			t.ok(inhaler.is_empty(), "not on night %d" % day)
		else:
			t.eq(inhaler.get("label", ""), "Riley's controller inhaler", "night %d" % day)
			t.eq(inhaler.get("amount", 0), Economy.PRESCRIPTION)
			t.eq(inhaler.get("note", ""), "(not covered: R-05, pre-existing)")


func test_two_unpaid_nights_of_inhaler_make_riley_sick() -> void:
	var run := _run(4)
	_only_event(run, "")
	_night(run, ["rx:inhaler"])
	t.ok(not run.member("child")["sick"], "one missed night")
	_night(run, ["rx:inhaler"])
	t.ok(run.member("child")["sick"], "two in a row")


func test_nobody_takes_a_dead_member_s_prescription() -> void:
	var run := _run(5)
	_only_event(run, "")
	run.member("mother")["alive"] = false
	run.member("child")["alive"] = false
	var ids := _ids(NightLogic.close_shift(run, _rng()))
	t.ok(not ids.has("rx:pills") and not ids.has("rx:inhaler"), "%s" % ids)


# --- events -------------------------------------------------------------------

func test_one_event_on_nights_two_four_five_and_six_without_repeats() -> void:
	var first_events := {}
	for seed_value in 40:
		var run := RunState.create("Pat Doe", seed_value)
		run.savings = 5000
		var seen: PackedStringArray = []
		for night in range(1, 7):
			run.reset_today()
			var ledger := _night(run)
			var event: Dictionary = ledger["event"]
			if Household.EVENT_NIGHTS.has(night):
				t.ok(not event.is_empty(), "seed %d: an event on night %d" % [seed_value, night])
				t.ok(not seen.has(event.get("id", "")), "seed %d: %s repeats" % [seed_value, event.get("id", "")])
				seen.append(event.get("id", ""))
			else:
				t.ok(event.is_empty(), "seed %d: night %d is quiet" % [seed_value, night])
		t.eq(seen.size(), 4)
		first_events[seen[0]] = true
	t.ok(first_events.size() >= 3, "the seed decides the order: %s" % [first_events.keys()])


func test_the_event_order_is_fixed_by_the_run_seed() -> void:
	t.eq(Household.event_order(7), Household.event_order(7))
	var orders := {}
	for seed_value in 20:
		orders[",".join(Household.event_order(seed_value))] = true
	t.ok(orders.size() > 10, "orders differ between runs")


func test_an_event_about_someone_who_died_is_passed_over() -> void:
	for seed_value in 60:
		var event := Household.event_for(seed_value, 2, PackedStringArray(), PackedStringArray(["child", "mother"]))
		t.ok(event.get("who", "") != "partner", "seed %d drew %s with Sam gone" % [seed_value, event.get("id", "")])
	t.eq(Household.event_for(3, 4, PackedStringArray(), PackedStringArray()).get("who", "x"), "", "with everyone gone only the furnace is left")
	var run := _run(4)
	for m in run.family:
		m["alive"] = false
	t.ok((NightLogic.close_shift(run, _rng())["event"] as Dictionary).is_empty(), "nobody home, nothing happens")


func test_skipping_the_furnace_means_no_heat_tonight_or_tomorrow() -> void:
	var run := _run(4)
	_only_event(run, "furnace")
	var ledger := NightLogic.close_shift(run, _rng())
	t.eq(ledger["event"]["text"], "The furnace quit. Repair $30.")
	t.eq(_bill(ledger, "event:furnace")["amount"], 30)
	t.eq(_bill(ledger, "event:furnace")["note"], "(skip: no heat tonight or tomorrow)")
	var paid := _pay_all(ledger, ["event:furnace"])
	t.ok(paid["heat"], "heat ticked anyway")
	NightLogic.apply_ledger(run, paid)
	t.eq(run.savings, int(ledger["available"]) - _spend(ledger, ["rent", "rx:pills", "rx:inhaler", "food"]), "heat costs nothing without a furnace")
	t.eq(run.member("partner")["cold"], 1, "cold tonight")
	ledger = NightLogic.close_shift(run, _rng())
	t.ok(not _ids(ledger).has("heat"), "no heat to buy tomorrow: %s" % _ids(ledger))
	t.ok((ledger["notes"] as PackedStringArray).has(NightLogic.FURNACE_OUT_NOTE), "the ledger says why")
	NightLogic.apply_ledger(run, _pay_all(ledger))
	t.ok(run.member("partner")["sick"] and run.member("mother")["sick"], "two cold nights make them sick")
	ledger = NightLogic.close_shift(run, _rng())
	t.ok(_ids(ledger).has("heat"), "the night after, heat is back")


func test_repairing_the_furnace_keeps_the_heat_on() -> void:
	var run := _run(4)
	_only_event(run, "furnace")
	_night(run)
	t.eq(run.member("partner")["cold"], 0)
	t.ok(_ids(NightLogic.close_shift(run, _rng())).has("heat"), "heat tomorrow")


func test_heat_is_pre_checked_only_with_the_furnace_repair() -> void:
	# After rent, pills, inhaler and food, heat needs the repair beside it and
	# tomorrow's rent kept back, like any household event.
	var essentials := Economy.RENT + 2 * Economy.PRESCRIPTION + Economy.FOOD
	var together := Economy.HEAT + 30 + Economy.RENT
	var run := _run(4, essentials + together - 1)
	_only_event(run, "furnace")
	var ledger := NightLogic.close_shift(run, _rng())
	t.eq(_bill(ledger, "heat").get("requires", ""), "event:furnace")
	t.ok(not _bill(ledger, "heat")["default_on"], "heat alone would be wasted")
	t.ok(not _bill(ledger, "event:furnace")["default_on"], "and the repair waits on it")
	run = _run(4, essentials + together)
	_only_event(run, "furnace")
	ledger = NightLogic.close_shift(run, _rng())
	t.ok(_bill(ledger, "heat")["default_on"] and _bill(ledger, "event:furnace")["default_on"], "both fit")


func test_the_household_event_is_pre_checked_only_if_tomorrow_s_rent_stays() -> void:
	var everything := Economy.RENT + Economy.PRESCRIPTION + Economy.FOOD + Economy.HEAT + 8
	for pair: Array in [[everything + Economy.RENT - 1, false], [everything + Economy.RENT, true]]:
		var run := _run(2, pair[0])
		_only_event(run, "class_trip")
		var ledger := NightLogic.close_shift(run, _rng())
		t.ok(_bill(ledger, "heat")["default_on"], "with $%d the rest is ticked" % pair[0])
		t.eq(_bill(ledger, "event:class_trip")["default_on"], pair[1], "with $%d, tomorrow's rent decides" % pair[0])


func test_skipping_the_dentist_makes_sam_sick() -> void:
	var run := _run(4)
	_only_event(run, "dentist")
	var ledger := NightLogic.close_shift(run, _rng())
	t.eq(ledger["event"]["text"], "Sam's tooth abscess. Benevolence Mutual: DENIED (R-04, no prior authorization). Dentist $35.")
	t.eq(_bill(ledger, "event:dentist")["amount"], 35)
	NightLogic.apply_ledger(run, _pay_all(ledger, ["event:dentist"]))
	t.ok(run.member("partner")["sick"], "Sam is sick")
	t.eq(run.member("partner")["sick_nights"], 0)
	t.ok(not run.member("mother")["sick"], "nobody else")
	run = _run(4)
	_only_event(run, "dentist")
	_night(run)
	t.ok(not run.member("partner")["sick"], "paid: Sam is fine")


func test_skipping_a_flavor_event_costs_nothing_but_the_line() -> void:
	for id in ["class_trip", "collection", "glasses", "bus_pass"]:
		var paid_run := _run(4)
		_only_event(paid_run, id)
		var ledger := _night(paid_run)
		var skipped_run := _run(4)
		_only_event(skipped_run, id)
		_night(skipped_run, ["event:%s" % id])
		var cost := int(_bill(ledger, "event:%s" % id)["amount"])
		t.ok(cost > 0, "%s is a bill" % id)
		t.eq(skipped_run.savings - paid_run.savings, cost, "%s: only the money differs" % id)
		t.eq(JSON.stringify(skipped_run.family), JSON.stringify(paid_run.family), "%s: the family is the same" % id)


func test_the_coupon_takes_money_off_every_pharmacy_bill() -> void:
	var run := _run(4)
	_only_event(run, "coupon")
	run.member("mother")["sick"] = true
	var ledger := NightLogic.close_shift(run, _rng())
	t.eq(ledger["event"]["text"], "Sam found a pharmacy coupon: $5 off medicine and prescriptions tonight.")
	t.eq(_bill(ledger, "medicine:mother")["amount"], 15, "medicine")
	t.eq(_bill(ledger, "medicine:mother")["note"], "(coupon)")
	t.eq(_bill(ledger, "rx:pills")["amount"], 5, "pills")
	t.eq(_bill(ledger, "rx:inhaler")["amount"], 5, "inhaler")
	t.eq([_bill(ledger, "food")["amount"], _bill(ledger, "heat")["amount"]], [Economy.FOOD, Economy.HEAT], "only the pharmacy")
	t.ok(not _ids(ledger).has("event:coupon"), "not a bill: %s" % _ids(ledger))
	NightLogic.apply_ledger(run, _pay_all(ledger))
	t.ok(not run.member("mother")["sick"], "the medicine works")
	t.eq(run.household["events"][run.household["events"].size() - 1]["id"], "coupon", "seen")
	t.eq(run.savings, int(ledger["available"]) - (Economy.RENT + 15 + 5 + 5 + Economy.FOOD + Economy.HEAT), "and costs that much less")


func test_the_coupon_waits_for_a_night_with_something_to_discount() -> void:
	# Night 5 with Mom and Riley gone and Sam well: no medicine, no prescriptions.
	var run := _run(5)
	_only_event(run, "coupon")
	run.member("mother")["alive"] = false
	run.member("child")["alive"] = false
	var ledger := NightLogic.close_shift(run, _rng())
	t.ok((ledger["event"] as Dictionary).is_empty(), "nothing to take money off: %s" % [ledger["event"]])
	NightLogic.apply_ledger(run, _pay_all(ledger))
	for e: Dictionary in run.household["events"]:
		t.ok(e["id"] != "coupon", "still unseen after a quiet night")
	# The next night Sam is sick, and the coupon turns up.
	run.member("partner")["sick"] = true
	ledger = NightLogic.close_shift(run, _rng())
	t.eq(ledger["event"].get("id", ""), "coupon", "kept for a night with medicine")
	t.eq(_bill(ledger, "medicine:partner")["amount"], 15)


func test_a_passed_over_coupon_gives_its_night_to_the_next_event() -> void:
	var found := 0
	for seed_value in 200:
		var order := Household.event_order(seed_value)
		if order[0] != "coupon":
			continue
		found += 1
		var alive := PackedStringArray(["partner", "child", "mother"])
		t.eq(Household.event_for(seed_value, 2, PackedStringArray(), alive, true)["id"], "coupon", "seed %d" % seed_value)
		t.eq(Household.event_for(seed_value, 2, PackedStringArray(), alive, false)["id"], order[1], "seed %d: nothing at the pharmacy" % seed_value)
	t.ok(found > 0, "some seeds draw the coupon first")


func test_the_coupon_never_turns_up_with_nothing_to_discount() -> void:
	# Households that skip bills at random, so people fall sick, die and recover.
	var coupons := 0
	for seed_value in 300:
		var run := RunState.create("Pat Doe", seed_value)
		run.savings = 400
		var choices := RandomNumberGenerator.new()
		choices.seed = seed_value
		for night in 6:
			run.reset_today()
			var ledger := NightLogic.close_shift(run, _rng())
			if ledger["event"].get("id", "") == "coupon":
				coupons += 1
				var discounted := 0
				for bill: Dictionary in ledger["bills"]:
					var id: String = bill["id"]
					if id.begins_with("medicine:"):
						discounted += 1
						t.eq(bill["amount"], Economy.MEDICINE - Economy.COUPON_OFF, "seed %d night %d: %s" % [seed_value, night + 1, id])
					elif id.begins_with("rx:"):
						discounted += 1
						t.eq(bill["amount"], Economy.PRESCRIPTION - Economy.COUPON_OFF, "seed %d night %d: %s" % [seed_value, night + 1, id])
				t.ok(discounted > 0, "seed %d night %d: a coupon with nothing to buy" % [seed_value, night + 1])
			var skip: PackedStringArray = []
			for bill: Dictionary in ledger["bills"]:
				if choices.randf() < 0.45:
					skip.append(bill["id"])
			NightLogic.apply_ledger(run, _pay_all(ledger, skip))
			if run.ending != "":
				break
	t.ok(coupons > 50, "the coupon still comes up: %d times" % coupons)


# --- tonight's bills ----------------------------------------------------------

func test_pre_check_order_is_medicine_prescriptions_food_heat_then_the_event() -> void:
	var order: Array[String] = ["medicine:mother", "rx:pills", "rx:inhaler", "food", "heat", "event:class_trip"]
	var budget := 0
	for i in order.size() + 1:
		var run := _run(4, Economy.RENT + budget)
		_only_event(run, "class_trip")
		run.member("mother")["sick"] = true
		var ledger := NightLogic.close_shift(run, _rng())
		for j in order.size():
			t.eq(_bill(ledger, order[j])["default_on"], j < i, "budget %d: %s" % [budget, order[j]])
		if i < order.size():
			budget += int(_bill(ledger, order[i])["amount"])
			if order[i].begins_with("event:"):
				# The event also keeps tomorrow's rent back.
				budget += Economy.RENT


func test_overspending_drops_the_event_then_heat_food_prescriptions_and_medicine_last() -> void:
	var drop_order: Array[String] = ["event:class_trip", "heat", "food", "rx:inhaler", "rx:pills", "medicine:mother"]
	var everything := Economy.RENT + Economy.MEDICINE + 2 * Economy.PRESCRIPTION + Economy.FOOD + Economy.HEAT + 8
	var shortfall := 1
	for dropped in drop_order.size():
		var run := _run(4, everything - shortfall)
		_only_event(run, "class_trip")
		run.member("mother")["sick"] = true
		var ledger := NightLogic.close_shift(run, _rng())
		var paid := _pay_all(ledger)
		var forecast := NightLogic.forecast(run, paid)
		NightLogic.apply_ledger(run, paid)
		var kept: PackedStringArray = ["rent"]
		for id in drop_order.slice(dropped + 1):
			kept.append(id)
		t.eq(run.savings, int(ledger["available"]) - _spend(ledger, kept), "short by %d: drops %s" % [shortfall, drop_order.slice(0, dropped + 1)])
		t.ok(run.savings >= 0, "never overspends")
		t.eq(run.member("mother")["sick"], dropped >= 5, "medicine goes last")
		t.eq(JSON.stringify(forecast[2]["sick"]), JSON.stringify(run.member("mother")["sick"]), "the forecast drops the same bills")
		if dropped + 1 < drop_order.size():
			shortfall += int(_bill(ledger, drop_order[dropped])["amount"])


func test_dropping_the_furnace_also_turns_off_the_heat() -> void:
	# One dollar short of paying everything: the repair goes, and the heat with it.
	var essentials := Economy.RENT + 2 * Economy.PRESCRIPTION + Economy.FOOD
	var run := _run(4, essentials + Economy.HEAT + 29)
	_only_event(run, "furnace")
	var ledger := NightLogic.close_shift(run, _rng())
	NightLogic.apply_ledger(run, _pay_all(ledger))
	t.eq(run.member("partner")["cold"], 1, "no repair, no heat")
	t.eq(run.savings, Economy.HEAT + 29, "and the heat isn't charged")
	t.eq(run.household["no_heat_through"], 5)


func test_a_household_that_pays_everything_spends_130_to_145_a_week_on_extras() -> void:
	var weeks := 200
	var total := 0
	var lowest := 1 << 30
	var highest := 0
	for seed_value in weeks:
		var run := RunState.create("Pat Doe", seed_value)
		run.savings = 5000
		var week := 0
		for night in 6:
			run.reset_today()
			var ledger := NightLogic.close_shift(run, _rng())
			var paid := _pay_all(ledger)
			for id: String in paid["extras"]:
				week += int(_bill(ledger, id)["amount"])
			NightLogic.apply_ledger(run, paid)
		total += week
		lowest = mini(lowest, week)
		highest = maxi(highest, week)
	var mean := float(total) / weeks
	t.ok(mean >= 130.0 and mean <= 145.0, "mean weekly extras $%.1f (lowest $%d, highest $%d)" % [mean, lowest, highest])


# --- saves --------------------------------------------------------------------

func test_the_household_survives_a_save() -> void:
	var run := RunState.create("Pat Doe", 77)
	run.household = {"missed": {"pills": 1, "inhaler": 0}, "events": [{"id": "furnace", "night": 2, "paid": false}], "no_heat_through": 3}
	var d := run.to_dict()
	t.eq(d["version"], 2)
	var copy := RunState.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.eq(copy.household["missed"]["pills"], 1)
	t.eq(typeof(copy.household["missed"]["pills"]), TYPE_INT)
	t.eq(copy.household["events"][0]["id"], "furnace")
	t.eq(typeof(copy.household["events"][0]["night"]), TYPE_INT)
	t.eq(copy.household["events"][0]["paid"], false)
	t.eq(copy.household["no_heat_through"], 3)
	t.eq(typeof(copy.household["no_heat_through"]), TYPE_INT)


func test_a_version_one_save_starts_the_household_fresh() -> void:
	var d := RunState.create("Pat Doe", 77).to_dict()
	d["version"] = 1
	d.erase("household")
	var copy := RunState.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.eq(JSON.stringify(copy.household), JSON.stringify(RunState.default_household()))
	copy.reset_today()
	copy.day = 2
	t.ok(not (NightLogic.close_shift(copy, _rng())["bills"] as Array).is_empty(), "and the night still works")
