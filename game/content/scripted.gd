class_name Scripted
## Hand-written moral cases, one per day, each deniable under that day's new
## rule, plus the player's own claim on day 7.
##
## Optional keys: "diagnosis" rewords the claim's diagnosis label; "member_years"
## puts MEMBER SINCE that many years before the date of service, for stories that
## say how long someone paid in.
##
## "exhibit" is the one personal paper a patient brings (Claim.exhibit, drawn by
## Paperwork.exhibit): kind "log", "letter" or "badge"; title, subtitle, rows of
## [caption, value] ("{date}" prints the date of service), body, signature. A
## "log" lists [days before the date of service, entry] pairs as dated rows.
## "image": "ultrasound" adds a printed scan. None of it is ever evidence.

const CASES: Array[Dictionary] = [
	{
		"id": "walt", "day": 1, "slot": 2, "name": "Walt Brennan", "age": 58,
		"dx": "heart_attack", "rule": "R-01", "provider": "St. Agnes Medical Center",
		"member_years": 19,
		"line": "My premium payment bounced while I was in the ICU. I wasn't awake to fix it.",
		"exhibit": {
			"kind": "log", "title": "ST. AGNES MEDICAL CENTER - ICU NURSING LOG",
			"subtitle": "Patient: BRENNAN, WALTER  -  Bed 4",
			"log": [
				[-5, "Admitted. Intubated, sedated."],
				[-4, "Sedated. Daughter at bedside."],
				[-3, "Sedated. No response to voice."],
				[-2, "Sedation lowered. Opens eyes."],
				[-1, "Extubated. Alert. Asked what day it was."],
			],
		},
	},
	{
		"id": "lily", "day": 2, "slot": 3, "name": "Lily Navarro", "age": 7,
		"dx": "leukemia", "rule": "R-02", "provider": "University Children's Hospital",
		"line": "It's the only children's cancer center in the state. Where else could we take her?",
		"exhibit": {
			"kind": "letter", "title": "UNIVERSITY CHILDREN'S HOSPITAL",
			"subtitle": "Division of Pediatric Oncology",
			"rows": [["DATE", "{date}"], ["RE", "Lily Navarro, age 7"]],
			"body": "To whom it may concern: Lily is being treated for acute leukemia. Ours is the only pediatric oncology program in the state. No hospital in your network offers this care. Her treatment should not be interrupted.",
			"signature": "Dr. M. Adeyemi",
		},
	},
	{
		"id": "dale", "day": 3, "slot": 4, "name": "Dale Pruitt", "age": 44,
		"dx": "appendicitis", "rule": "R-03", "provider": "Mercer County Hospital",
		"claim_name": "Dail Pruitt",
		"line": "Hey. Dale, from Desk 12. Small world, huh?",
		"exhibit": {
			"kind": "badge", "title": "BENEVOLENCE MUTUAL  -  STAFF",
			"rows": [["NAME", "DALE PRUITT"], ["POSITION", "CLAIMS ADJUSTER #4470"], ["DESK", "12"]],
		},
	},
	{
		"id": "eleanor", "day": 4, "slot": 3, "name": "Eleanor Hargrove", "age": 79,
		"dx": "hip_fx", "rule": "R-04", "provider": "Lakeside Orthopedics",
		"sticky_note": "Handle this one personally.\n-R.H.", "exempt": true,
		"line": "My son works upstairs. He said you'd take good care of me.",
	},
	{
		"id": "priya", "day": 5, "slot": 5, "name": "Priya Raman", "age": 31,
		"dx": "pregnancy", "rule": "R-05", "provider": "St. Agnes Medical Center",
		"line": "The baby's okay. They just wanted to monitor overnight. That's all this is.",
		"exhibit": {
			"kind": "log", "image": "ultrasound",
			"title": "ST. AGNES MEDICAL CENTER - OBSTETRIC ULTRASOUND",
			"rows": [["PATIENT", "RAMAN, PRIYA"], ["FETAL HEART RATE", "142 BPM"], ["DUE DATE", "03/19/2026"]],
			"body": "Everything looks good. Rest.",
		},
	},
	{
		"id": "marcus", "day": 6, "slot": 4, "name": "Marcus Bell", "age": 52,
		"dx": "colon_cancer", "diagnosis": "Colon cancer, stage IV", "rule": "R-06", "provider": "Westbrook Cancer Institute",
		"addon": "immunotherapy_exp",
		"line": "It's the only thing left. The trial numbers are good.",
		"exhibit": {
			"kind": "letter", "title": "WESTBROOK CANCER INSTITUTE",
			"subtitle": "Department of Medical Oncology",
			"rows": [["DATE", "{date}"], ["RE", "Marcus Bell"]],
			"body": "Mr. Bell's cancer has progressed through standard treatment. He qualifies for our immunotherapy trial, and in my judgment it is his last reasonable option. I recommend it without reservation.",
			"signature": "Dr. K. Lindgren",
		},
	},
]

## The player's claim on day 7: rushed to the nearest ER (out of network), with
## hypertension noted at the pre-employment physical, before coverage began.
const PLAYER := {
	"age": 41,
	"dx": "hypertensive_crisis",
	"provider": "Harbor Point Medical Center",
	"line": "...",
}


## What scripted patients say after the stamp, instead of a generic line.
const REACTIONS: Dictionary = {
	"walt": {"approved": "Thank you. I didn't think anyone would read it.", "denied": "I was unconscious. What was I supposed to do?"},
	"lily": {"approved": "Thank you. Thank you. I have to call her mother.", "denied": "She's seven."},
	"dale": {"approved": "I owe you one. Lunch is on me.", "denied": "It's one letter. It's my name. You know my name."},
	"eleanor": {"approved": "Such a polite young person. I'll tell my son.", "denied": "My son will hear about this."},
	"priya": {"approved": "Oh. Okay. Okay, good.", "denied": "...okay."},
	"marcus": {"approved": "...really? I'll call the trial coordinator.", "denied": "Okay. Thank you for your time."},
	"player": {"approved": "...", "denied": "..."},
}


static func reaction(id: String, approved: bool) -> String:
	if not REACTIONS.has(id):
		return ""
	return REACTIONS[id]["approved" if approved else "denied"]


static func for_day(day: int) -> Dictionary:
	for case_data in CASES:
		if case_data["day"] == day:
			return case_data
	return {}


static func get_case(id: String) -> Dictionary:
	for case_data in CASES:
		if case_data["id"] == id:
			return case_data
	return {}
