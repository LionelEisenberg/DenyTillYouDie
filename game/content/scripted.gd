class_name Scripted
## Hand-written moral cases, one per day, each deniable under that day's new
## rule, plus the player's own claim on day 7.

const CASES: Array[Dictionary] = [
	{
		"id": "walt", "day": 1, "slot": 2, "name": "Walt Brennan", "age": 58,
		"dx": "heart_attack", "rule": "R-01", "provider": "St. Agnes Medical Center",
		"line": "My premium payment bounced while I was in the ICU. I wasn't awake to fix it.",
	},
	{
		"id": "lily", "day": 2, "slot": 3, "name": "Lily Navarro", "age": 7,
		"dx": "leukemia", "rule": "R-02", "provider": "University Children's Hospital",
		"line": "It's the only children's cancer center in the state. Where else could we take her?",
	},
	{
		"id": "dale", "day": 3, "slot": 4, "name": "Dale Pruitt", "age": 44,
		"dx": "appendicitis", "rule": "R-03", "provider": "Mercer County Hospital",
		"claim_name": "Dail Pruitt",
		"line": "Hey. Dale, from Desk 12. Small world, huh?",
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
	},
	{
		"id": "marcus", "day": 6, "slot": 4, "name": "Marcus Bell", "age": 52,
		"dx": "colon_cancer", "rule": "R-06", "provider": "Westbrook Cancer Institute",
		"addon": "immunotherapy_exp",
		"line": "It's the only thing left. The trial numbers are good.",
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
