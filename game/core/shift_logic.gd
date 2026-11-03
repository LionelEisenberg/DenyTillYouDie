class_name ShiftLogic
## Applies a stamped decision to the run: pay, discontent, citations, stats.


## `cited_rule` is the rule the player cited ("" for none). A rule the claim does
## not actually break counts as a blind denial; R-07 (DenyBot) always counts.
## Returns {pay, discontent, citation, warning, fine}.
static func apply_decision(run: RunState, c: Claim, approve: bool, cited_rule: String) -> Dictionary:
	var result := {"pay": 0, "discontent": 0.0, "citation": false, "warning": 0, "fine": 0}
	var valid := RuleChecker.has_valid_reason(c, run.day)
	var cited := false
	if approve:
		var compassion: bool = run.effects.get("compassion", false)
		var cost := Economy.approval_cost(c.priority, compassion)
		result["pay"] = -cost
		run.today["deductions"] += cost
		result["discontent"] = -Economy.approval_relief(c, compassion)
		if valid and not c.exempt_from_citation:
			result["citation"] = true
			run.today["warnings"] += 1
			result["warning"] = run.today["warnings"]
			if run.today["warnings"] > Economy.FREE_WARNINGS:
				result["fine"] = Economy.CITATION_FINE
				result["pay"] -= Economy.CITATION_FINE
				run.today["fines"] += Economy.CITATION_FINE
	else:
		var denybot := cited_rule == Rules.R07 and Rules.is_unlocked(Rules.R07, run.day)
		cited = denybot or (cited_rule != "" and _breaks(c, cited_rule, run.day))
		var commission := Economy.commission(c.priority, cited)
		result["pay"] = commission
		run.today["commissions"] += commission
		result["discontent"] = Economy.denial_discontent(c, denybot, run.effects.get("protest", false))

	run.discontent = maxf(0.0, run.discontent + result["discontent"])
	run.stats["earned"] += result["pay"]

	var record := c.summary()
	record["approved"] = approve
	record["cited_rule"] = cited_rule if cited else ""
	record["blind"] = not approve and not cited
	record["valid_reason"] = valid
	record["exempt"] = c.exempt_from_citation
	run.today["decisions"].append(record)

	if c.scripted_id != "" or c.is_player:
		run.scripted_outcomes["player" if c.is_player else c.scripted_id] = "approved" if approve else "denied"
	if not c.is_player:
		run.stats["processed"] += 1
		if approve:
			run.stats["approved"] += 1
		else:
			run.stats["denied"] += 1
			run.stats["cited" if cited else "blind"] += 1
	return result


## Charged for each citation attempt that finds nothing. Returns the fee.
static func compliance_fee(run: RunState) -> int:
	run.today["fees"] += Economy.COMPLIANCE_FEE
	run.stats["earned"] -= Economy.COMPLIANCE_FEE
	return Economy.COMPLIANCE_FEE


## Today's pay so far, including base pay.
static func pay_so_far(run: RunState) -> int:
	var t: Dictionary = run.today
	return Economy.BASE_PAY + int(t["commissions"]) - int(t["deductions"]) - int(t["fines"]) - int(t["fees"])


static func _breaks(c: Claim, rule_id: String, day: int) -> bool:
	for v in RuleChecker.violations(c, day):
		if v["rule"] == rule_id:
			return true
	return false
