class_name RuleChecker
## Finds rule violations in a claim's paperwork. Pure functions of the claim data,
## so a violation counts whether or not the generator meant to plant it.
##
## Each violation lists the evidence keys a player may click to cite it.

const DENYBOT_KEY := "denybot"


## Violations of rules unlocked on `day`. Never includes R-07, which applies to
## everything and so is not a "reason" in the sense of appeals or citations.
static func violations(c: Claim, day: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var unlocked := Rules.unlocked(day)

	if unlocked.has(Rules.R01) and c.coverage_through < c.date_of_service:
		found.append(_violation(Rules.R01, ["card.coverage_through", "claim.date_of_service"]))

	if unlocked.has(Rules.R02) and not Medical.is_in_network(c.provider):
		found.append(_violation(Rules.R02, ["claim.provider", "bill.provider"]))

	if unlocked.has(Rules.R03):
		if c.name != c.card_name:
			found.append(_violation(Rules.R03, ["claim.name", "card.name"]))
		if c.member_id != c.card_member_id:
			found.append(_violation(Rules.R03, ["claim.member_id", "card.member_id"]))
		if c.dob != c.card_dob:
			found.append(_violation(Rules.R03, ["claim.dob", "card.dob"]))

	if unlocked.has(Rules.R04) and c.prior_auth.strip_edges() == "":
		var keys: PackedStringArray = []
		for i in c.bill_lines.size():
			if c.bill_lines[i]["pa"]:
				keys.append("bill.line.%d" % i)
		if not keys.is_empty():
			keys.append("claim.prior_auth")
			found.append(_violation(Rules.R04, keys))

	if unlocked.has(Rules.R05):
		for i in c.history.size():
			var entry := c.history[i]
			if entry["condition"] == c.condition and int(entry["date"]) < c.member_since:
				found.append(_violation(Rules.R05, ["history.entry.%d" % i]))

	if unlocked.has(Rules.R06):
		for i in c.bill_lines.size():
			if c.bill_lines[i]["excluded"]:
				found.append(_violation(Rules.R06, ["bill.line.%d" % i]))

	return found


static func has_valid_reason(c: Claim, day: int) -> bool:
	return not violations(c, day).is_empty()


## True if citing `rule_id` with `evidence_key` is a correct citation on `day`.
static func check_citation(c: Claim, rule_id: String, evidence_key: String, day: int) -> bool:
	if not Rules.is_unlocked(rule_id, day):
		return false
	if rule_id == Rules.R07:
		return evidence_key == DENYBOT_KEY
	for v in violations(c, day):
		if v["rule"] == rule_id and (v["evidence"] as PackedStringArray).has(evidence_key):
			return true
	return false


static func _violation(rule_id: String, evidence: PackedStringArray) -> Dictionary:
	return {"rule": rule_id, "evidence": evidence}
