class_name RunState
extends RefCounted
## Everything about a run that survives the night. Saved as JSON at each morning.

const FAMILY_TEMPLATE: Array[Dictionary] = [
	{"id": "partner", "name": "Sam", "role": "Partner"},
	{"id": "child", "name": "Riley", "role": "Child"},
	{"id": "mother", "name": "Mom", "role": "Mother"},
]

var player_name: String = "J. Doe"
var run_seed: int = 0
var day: int = 1
var savings: int = Economy.START_SAVINGS
var discontent: float = Economy.START_DISCONTENT
## {id, name, role, hungry, cold, sick, sick_nights, alive}
var family: Array[Dictionary] = []
## processed, denied, approved, cited, blind, deaths, earned
var stats: Dictionary = {}
var events_fired: Array[int] = []
## Today's event effects: protest, audit, compassion.
var effects: Dictionary = {}
## scripted id -> "approved" | "denied"
var scripted_outcomes: Dictionary = {}
## Patients who died after a denial: {name, age, diagnosis, day, scripted_id}.
var deaths: Array[Dictionary] = []
## Per-shift tallies; not saved (a save always starts a fresh morning).
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
	run.stats = {"processed": 0, "denied": 0, "approved": 0, "cited": 0, "blind": 0, "deaths": 0, "earned": 0}
	run.effects = {"protest": false, "audit": false, "compassion": false}
	run.reset_today()
	return run


func reset_today() -> void:
	today = {"commissions": 0, "deductions": 0, "fines": 0, "fees": 0, "warnings": 0, "decisions": []}


func member(id: String) -> Dictionary:
	for m in family:
		if m["id"] == id:
			return m
	return {}


func to_dict() -> Dictionary:
	return {
		"version": 1,
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
		"morning": morning,
		"ending": ending,
	}


## Rebuilds a run from `to_dict()` output, including after a JSON round trip
## (which turns every number into a float).
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
		run.deaths.append(copy)
	run.morning = (d.get("morning", {}) as Dictionary).duplicate(true)
	run.ending = str(d.get("ending", ""))
	run.reset_today()
	return run
