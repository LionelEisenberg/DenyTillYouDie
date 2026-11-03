class_name Rules
## The denial rulebook. One new rule unlocks each day.

const R01 := "R-01"
const R02 := "R-02"
const R03 := "R-03"
const R04 := "R-04"
const R05 := "R-05"
const R06 := "R-06"
const R07 := "R-07"

const ALL: Array[Dictionary] = [
	{
		"id": R01, "day": 1, "title": "Coverage lapsed",
		"short": "Coverage ended before the date of service.",
		"text": "Deny if the card's COVERAGE THROUGH date is earlier than the claim's DATE OF SERVICE.",
	},
	{
		"id": R02, "day": 2, "title": "Out-of-network provider",
		"short": "Provider is not in the Network Directory.",
		"text": "Deny if the PROVIDER is not listed in the Network Directory. Names must match exactly.",
	},
	{
		"id": R03, "day": 3, "title": "Clerical mismatch",
		"short": "Name, member ID or birth date differ.",
		"text": "Deny if the patient name, member ID or date of birth on the claim differs from the card in any way.",
	},
	{
		"id": R04, "day": 4, "title": "No prior authorization",
		"short": "Listed procedure billed with no prior auth.",
		"text": "Deny if the bill includes a procedure on the Prior Authorization list and the claim's PRIOR AUTH # is blank.",
	},
	{
		"id": R05, "day": 5, "title": "Pre-existing condition",
		"short": "Condition on record before enrollment.",
		"text": "Deny if the medical history shows the claimed condition, or a related one, dated before the card's MEMBER SINCE date.",
	},
	{
		"id": R06, "day": 6, "title": "Excluded service",
		"short": "Bill includes an excluded service.",
		"text": "Deny if any billed line appears on the Exclusions list, regardless of medical opinion.",
	},
	{
		"id": R07, "day": 7, "title": "Algorithmic determination (DenyBot)",
		"short": "DenyBot has reviewed this claim.",
		"text": "DenyBot may be consulted on any claim. Its determinations are final, proprietary and not subject to explanation.",
	},
]


static func unlocked(day: int) -> PackedStringArray:
	var ids: PackedStringArray = []
	for rule in ALL:
		if rule["day"] <= day:
			ids.append(rule["id"])
	return ids


static func is_unlocked(rule_id: String, day: int) -> bool:
	return unlocked(day).has(rule_id)


static func get_rule(rule_id: String) -> Dictionary:
	for rule in ALL:
		if rule["id"] == rule_id:
			return rule
	return {}


## The rule introduced on `day`, or an empty dictionary.
static func new_rule_on(day: int) -> Dictionary:
	for rule in ALL:
		if rule["day"] == day:
			return rule
	return {}
