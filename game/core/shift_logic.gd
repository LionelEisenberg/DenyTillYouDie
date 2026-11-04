class_name ShiftLogic
## Applies a stamped decision to the run: pay, discontent, citations, stats.


## `cited_rule` is the rule the player cited ("" for none). A rule the claim does
## not actually break counts as a blind denial; R-07 (DenyBot) always counts.
## Returns {pay, discontent, citation, warning, fine}.
##
## The decision record kept for the night is the claim's summary() plus:
## approved, cited_rule, blind, valid_reason, exempt, amount, pay, fine,
## portrait_seed, missed_rule (the first rule an approval let through, else "")
## and citation (whether that approval drew a citation).
static func apply_decision(run: RunState, c: Claim, approve: bool, cited_rule: String) -> Dictionary:
	var result := {"pay": 0, "discontent": 0.0, "citation": false, "warning": 0, "fine": 0}
	var found := RuleChecker.violations(c, run.day)
	var valid := not found.is_empty()
	var cited := false
	if approve:
		var compassion: bool = run.effects.get("compassion", false)
		var cost := Economy.approval_cost(c.priority, compassion)
		result["pay"] = -cost
		run.today["deductions"] += cost
		result["discontent"] = -Economy.approval_relief(c, compassion)
		# No citations for the boss's mother, or on Compassion Day (PR wants approvals).
		if valid and not c.exempt_from_citation and not compassion:
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
	record["amount"] = c.amount
	record["pay"] = result["pay"]
	record["fine"] = result["fine"]
	record["portrait_seed"] = c.portrait_seed
	record["missed_rule"] = String(found[0]["rule"]) if approve and valid else ""
	record["citation"] = result["citation"]
	run.today["decisions"].append(record)

	if c.scripted_id != "" or c.is_player:
		run.scripted_outcomes["player" if c.is_player else c.scripted_id] = "approved" if approve else "denied"
	if not c.is_player:
		run.stats["processed"] += 1
		if approve:
			run.stats["approved"] += 1
			run.stats["paid_out"] = int(run.stats.get("paid_out", 0)) + c.amount
		else:
			run.stats["denied"] += 1
			run.stats["cited" if cited else "blind"] += 1
			run.stats["saved"] = int(run.stats.get("saved", 0)) + c.amount
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


## Today's denials over today's decisions, leaving out the player's own claim.
static func today_denial_rate(run: RunState) -> float:
	var processed := 0
	var denied := 0
	for rec: Dictionary in run.today.get("decisions", []):
		if rec.get("is_player", false):
			continue
		processed += 1
		if not rec["approved"]:
			denied += 1
	return 0.0 if processed == 0 else float(denied) / processed


## today_denial_rate() in whole percent, rounded down the way every page shows
## rates (see Endings.rate_percent).
static func today_denial_percent(run: RunState) -> int:
	return floori(today_denial_rate(run) * 100.0 + 0.000001)


## Whether today's denial rate meets today's target. Never on a day without one.
static func target_met(run: RunState) -> bool:
	var target := Economy.target_for(run.day)
	return target > 0 and today_denial_percent(run) >= target


static func _breaks(c: Claim, rule_id: String, day: int) -> bool:
	for v in RuleChecker.violations(c, day):
		if v["rule"] == rule_id:
			return true
	return false
