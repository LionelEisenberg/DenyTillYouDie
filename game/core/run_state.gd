class_name RunState
extends RefCounted
## Everything about a run that survives the night. Saved as JSON at each morning.

const SAVE_VERSION := 2
const FAMILY_TEMPLATE: Array[Dictionary] = [
	{"id": "partner", "name": "Sam", "role": "Partner"},
	{"id": "child", "name": "Riley", "role": "Child"},
	{"id": "mother", "name": "Mom", "role": "Mother"},
]
## Every stat a run keeps. `saved` and `paid_out` are claim amounts denied and
## approved (the player's own claim excluded); a lost appeal moves its amount
## from saved to paid_out at night.
const STAT_KEYS: PackedStringArray = ["processed", "denied", "approved", "cited", "blind", "deaths", "earned", "saved", "paid_out"]

var player_name: String = "J. Doe"
var run_seed: int = 0
var day: int = 1
var savings: int = Economy.START_SAVINGS
var discontent: float = Economy.START_DISCONTENT
## {id, name, role, hungry, cold, sick, sick_nights, alive}
var family: Array[Dictionary] = []
## See STAT_KEYS.
var stats: Dictionary = {}
var events_fired: Array[int] = []
## Today's event effects: protest, audit, compassion.
var effects: Dictionary = {}
## scripted id -> "approved" | "denied"
var scripted_outcomes: Dictionary = {}
## Patients who died after a denial: {name, age, diagnosis, day, scripted_id,
## portrait_seed}. Deaths from saves older than portrait seeds have no seed.
var deaths: Array[Dictionary] = []
## The household's needs (see Household): {missed: {pills, inhaler}, nights each
## prescription has gone unpaid in a row; events: [{id, night, paid}], the
## household events seen so far; no_heat_through: the last night the furnace is out}.
var household: Dictionary = {}
## Per-shift tallies; not saved (a save always starts a fresh morning).
## target_pct is the day's denial target (Economy.DAILY_TARGET).
var today: Dictionary = {}
## Prepared at night for the next morning: {paper, memo, letters}.
var morning: Dictionary = {}
## Set when the run is over.
var ending: String = ""


static func create(player: String, seed_value: int) -> RunState:
	var run := RunState.new()
	run.player_name = player
	run.run_seed = seed_value
	for member in FAMILY_TEMPLATE:
		run.family.append({
			"id": member["id"], "name": member["name"], "role": member["role"],
			"hungry": 0, "cold": 0, "sick": false, "sick_nights": 0, "alive": true,
		})
	for key in STAT_KEYS:
		run.stats[key] = 0
	run.effects = {"protest": false, "audit": false, "compassion": false}
	run.household = default_household()
	run.reset_today()
	return run


static func default_household() -> Dictionary:
	return {"missed": {"pills": 0, "inhaler": 0}, "events": [], "no_heat_through": 0}


func reset_today() -> void:
	today = {
		"commissions": 0, "deductions": 0, "fines": 0, "fees": 0, "warnings": 0, "decisions": [],
		"target_pct": Economy.target_for(day),
	}


func member(id: String) -> Dictionary:
	for m in family:
		if m["id"] == id:
			return m
	return {}


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_name": player_name,
		"run_seed": run_seed,
		"day": day,
		"savings": savings,
		"discontent": discontent,
		"family": family,
		"stats": stats,
		"events_fired": events_fired,
		"effects": effects,
		"scripted_outcomes": scripted_outcomes,
		"deaths": deaths,
		"household": household,
		"morning": morning,
		"ending": ending,
	}


## Rebuilds a run from `to_dict()` output, including after a JSON round trip
## (which turns every number into a float). Keys a version 1 save lacks get
## their defaults.
static func from_dict(d: Dictionary) -> RunState:
	var run := RunState.new()
	run.player_name = str(d.get("player_name", "J. Doe"))
	run.run_seed = int(d.get("run_seed", 0))
	run.day = int(d.get("day", 1))
	run.savings = int(d.get("savings", Economy.START_SAVINGS))
	run.discontent = float(d.get("discontent", Economy.START_DISCONTENT))
	for m: Dictionary in d.get("family", []):
		run.family.append({
			"id": str(m["id"]), "name": str(m["name"]), "role": str(m["role"]),
			"hungry": int(m["hungry"]), "cold": int(m["cold"]), "sick": bool(m["sick"]),
			"sick_nights": int(m["sick_nights"]), "alive": bool(m["alive"]),
		})
	var saved_stats: Dictionary = d.get("stats", {})
	for key in STAT_KEYS:
		run.stats[key] = int(saved_stats.get(key, 0))
	for key: String in saved_stats:
		run.stats[key] = int(saved_stats[key])
	for threshold in d.get("events_fired", []):
		run.events_fired.append(int(threshold))
	var saved_effects: Dictionary = d.get("effects", {})
	run.effects = {
		"protest": bool(saved_effects.get("protest", false)),
		"audit": bool(saved_effects.get("audit", false)),
		"compassion": bool(saved_effects.get("compassion", false)),
	}
	run.scripted_outcomes = (d.get("scripted_outcomes", {}) as Dictionary).duplicate(true)
	for death: Dictionary in d.get("deaths", []):
		var copy := death.duplicate(true)
		copy["age"] = int(copy.get("age", 0))
		copy["day"] = int(copy.get("day", 0))
		if copy.has("portrait_seed"):
			copy["portrait_seed"] = int(copy["portrait_seed"])
		run.deaths.append(copy)
	run.household = _household_from(d.get("household", {}))
	run.morning = _morning_from(d.get("morning", {}))
	run.ending = str(d.get("ending", ""))
	run.reset_today()
	return run


## The saved morning, with the photos' seeds and ages whole numbers again: the
## paper's lead and items carry portrait_seed and age, letters photo_seed and
## photo_age.
static func _morning_from(saved: Dictionary) -> Dictionary:
	var morning := saved.duplicate(true)
	var paper: Variant = morning.get("paper", {})
	if paper is Dictionary:
		if paper.get("lead") is Dictionary:
			_whole(paper["lead"], ["portrait_seed", "age"])
		for item in paper.get("items", []):
			if item is Dictionary:
				_whole(item, ["portrait_seed", "age"])
	for letter in morning.get("letters", []):
		if letter is Dictionary:
			_whole(letter, ["photo_seed", "photo_age"])
	return morning


static func _whole(d: Dictionary, keys: PackedStringArray) -> void:
	for key in keys:
		if d.has(key):
			d[key] = int(d[key])


static func _household_from(saved: Dictionary) -> Dictionary:
	var h := default_household()
	var missed: Dictionary = saved.get("missed", {})
	for key: String in h["missed"]:
		h["missed"][key] = int(missed.get(key, 0))
	for e: Dictionary in saved.get("events", []):
		(h["events"] as Array).append({"id": str(e.get("id", "")), "night": int(e.get("night", 0)), "paid": bool(e.get("paid", false))})
	h["no_heat_through"] = int(saved.get("no_heat_through", 0))
	return h
