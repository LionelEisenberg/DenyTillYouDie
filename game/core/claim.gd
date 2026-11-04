class_name Claim
extends RefCounted
## One patient's paperwork: claim form, member card, itemized bill and medical history.
##
## The card holds the truth about the member; the claim form is what the provider
## filed, so clerical mismatches (R-03) live on the claim side.

enum Priority { ROUTINE, URGENT, CRITICAL }

const PRIORITY_NAMES: PackedStringArray = ["ROUTINE", "URGENT", "CRITICAL"]
const CHILD_AGE := 16
const BILL_FROM_DAY := 4
const HISTORY_FROM_DAY := 5

var claim_no: String = ""
var day: int = 1
var scripted_id: String = ""
var is_player: bool = false
var portrait_seed: int = 0
var line_seed: int = 0
var age: int = 30

# Claim form (BM-1500)
var name: String = ""
var dob: int = 0
var member_id: String = ""
var provider: String = ""
var date_of_service: int = 0
var diagnosis: String = ""
## The Medical.DIAGNOSES id behind `diagnosis` (a scripted case may reword the label).
var diagnosis_id: String = ""
var condition: String = ""
var amount: int = 0
var priority: int = Priority.ROUTINE
var prior_auth: String = ""

# Member card
var card_name: String = ""
var card_dob: int = 0
var card_member_id: String = ""
var plan: String = ""
var member_since: int = 0
var coverage_through: int = 0

## Itemized bill lines: {id, label, cost, pa, excluded}.
var bill_lines: Array[Dictionary] = []
## Medical history entries: {date, label, condition}, oldest first.
var history: Array[Dictionary] = []

# Booth
## What the patient opens with. The generator deals one to every random patient;
## a scripted case brings its own.
var arrival_line: String = ""
## Dealt reactions for after the stamp. Empty for scripted cases and the player,
## whose Scripted.reaction lines win.
var reaction_approved: String = ""
var reaction_denied: String = ""
var parent_speaks: bool = false
var sticky_note: String = ""
var exempt_from_citation: bool = false
## The one personal paper a scripted patient brings (see Scripted.CASES):
## {kind, title, subtitle, rows: [[caption, value], ...], body, signature}.
## Empty for everyone else. Never evidence for any rule.
var exhibit: Dictionary = {}


static func make_line(proc_id: String) -> Dictionary:
	var p: Dictionary = Medical.PROCEDURES[proc_id]
	return {"id": proc_id, "label": p["label"], "cost": p["cost"], "pa": p["pa"], "excluded": p["excluded"]}


func is_child() -> bool:
	return age < CHILD_AGE


func shows_bill() -> bool:
	return day >= BILL_FROM_DAY


func shows_history() -> bool:
	return day >= HISTORY_FROM_DAY


func bill_total() -> int:
	var total := 0
	for line in bill_lines:
		total += int(line["cost"])
	return total


func first_name() -> String:
	return card_name.get_slice(" ", 0)


func priority_name() -> String:
	return PRIORITY_NAMES[priority]


## A short treatment line for the claim form on days without an itemized bill.
## Labels stay as authored ("CT SCAN, HEAD", "tPA"), the way the bill prints them.
func treatment_summary() -> String:
	var parts: PackedStringArray = []
	for line in bill_lines:
		parts.append(String(line["label"]))
	return " / ".join(parts)


## Whether the diagnosis can kill if it goes untreated. Unknown ids count as fatal.
func is_fatal() -> bool:
	return bool(Medical.diagnosis(diagnosis_id).get("fatal", true))


## The facts the newspaper, memos and endings need after the shift.
func summary() -> Dictionary:
	return {
		"claim_no": claim_no,
		"name": card_name,
		"age": age,
		"diagnosis": diagnosis,
		"priority": priority,
		"scripted_id": scripted_id,
		"child": is_child(),
		"is_player": is_player,
		"fatal": is_fatal(),
	}
