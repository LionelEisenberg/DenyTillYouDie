class_name CitationText
## What a citation slip says about the rule an approval missed, built from the
## violation's rule and evidence keys (see RuleChecker.violations).


## One line naming the rule and the facts that break it, or "" for a violation
## this can't explain (R-07 is never a violation).
static func explain(c: Claim, violation: Dictionary) -> String:
	var evidence: PackedStringArray = violation.get("evidence", PackedStringArray())
	match String(violation.get("rule", "")):
		Rules.R01:
			return "R-01 COVERAGE LAPSED. Coverage through %s; service %s." % [DateUtil.fmt(c.coverage_through), DateUtil.fmt(c.date_of_service)]
		Rules.R02:
			return "R-02 OUT-OF-NETWORK. %s is not in the Network Directory." % c.provider
		Rules.R03:
			if evidence.has("claim.member_id"):
				return _mismatch(c.member_id, c.card_member_id)
			if evidence.has("claim.dob"):
				return _mismatch(DateUtil.fmt(c.dob), DateUtil.fmt(c.card_dob))
			return _mismatch(c.name, c.card_name)
		Rules.R04:
			return "R-04 NO PRIOR AUTH. %s needs authorization; PRIOR AUTH # is blank." % _bill_line(c, evidence)
		Rules.R05:
			var entry := _history_entry(c, evidence)
			return "R-05 PRE-EXISTING. %s on record %s, before member since %s." % [entry.get("label", c.diagnosis), DateUtil.fmt(int(entry.get("date", 0))), DateUtil.fmt(c.member_since)]
		Rules.R06:
			return "R-06 EXCLUDED SERVICE. %s is on the Exclusions list." % _bill_line(c, evidence)
	return ""


static func _mismatch(on_claim: String, on_card: String) -> String:
	return "R-03 CLERICAL MISMATCH. Claim: %s. Card: %s." % [on_claim, on_card]


## The label of the first bill line among the evidence keys ("bill.line.2").
static func _bill_line(c: Claim, evidence: PackedStringArray) -> String:
	for key in evidence:
		if key.begins_with("bill.line."):
			var i := key.get_slice(".", 2).to_int()
			if i >= 0 and i < c.bill_lines.size():
				return String(c.bill_lines[i]["label"])
	return "A billed procedure"


## The first medical history entry among the evidence keys ("history.entry.0").
static func _history_entry(c: Claim, evidence: PackedStringArray) -> Dictionary:
	for key in evidence:
		if key.begins_with("history.entry."):
			var i := key.get_slice(".", 2).to_int()
			if i >= 0 and i < c.history.size():
				return c.history[i]
	return {}
