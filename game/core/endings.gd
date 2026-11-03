class_name Endings
## The five ways a run ends, and the pages that show them.

const SCAPEGOATED := "scapegoated"
const EVICTED := "evicted"
const FIRED := "fired"
const EMPLOYEE_OF_MONTH := "employee_of_the_month"
const PROMOTED := "promoted"


## The ending after the player rules on their own claim on day 7.
static func resolve_final(run: RunState, approved_own: bool) -> String:
	if run.discontent >= Economy.SCAPEGOAT_AT:
		return SCAPEGOATED
	if approved_own:
		return FIRED
	if denial_rate(run) >= Economy.PROMOTION_RATE:
		return PROMOTED
	return EMPLOYEE_OF_MONTH


## Denied / processed over the whole run, excluding the player's own claim.
static func denial_rate(run: RunState) -> float:
	var processed := int(run.stats.get("processed", 0))
	if processed == 0:
		return 0.0
	return float(run.stats.get("denied", 0)) / processed


## {id, title, paper: {headline, sub}, epilogue: PackedStringArray, stats: Array, survived: bool}
static func build(run: RunState, id: String) -> Dictionary:
	var player := run.player_name
	var rate := roundi(denial_rate(run) * 100)
	var title := ""
	var paper := {}
	var epilogue: PackedStringArray = []
	var survived := true
	match id:
		SCAPEGOATED:
			title = "SCAPEGOATED"
			paper = {"headline": "Benevolence Mutual fires 'rogue' adjuster", "sub": "CEO: \"%s's decisions do not reflect our values.\" Shares rise 4%% on the news." % player}
			epilogue.append("The board thanked you for your service in a statement you were not shown.")
			epilogue.append("Your replacement started the next morning. Their denial target is ten percent higher.")
		EVICTED:
			title = "EVICTED"
			paper = {"headline": "Public notices", "sub": "Unit 4B, 1120 Calloway St.: tenant in default. Contents to be removed by the 15th."}
			epilogue.append("You couldn't make rent.")
			epilogue.append("Benevolence Mutual will process your final paycheck within 30 business days.")
		FIRED:
			title = "FIRED"
			paper = {"headline": "Adjuster terminated for approving own claim", "sub": "Benevolence Mutual cites a conflict of interest and rescinds coverage retroactively."}
			epilogue.append("You're alive.")
			epilogue.append("Your coverage was rescinded back to the date of service. Harbor Point Medical Center has sent the bill: $67,900.")
			epilogue.append("A new adjuster sits at Desk 11. They seem very motivated.")
		EMPLOYEE_OF_MONTH:
			title = "EMPLOYEE OF THE MONTH"
			survived = false
			paper = {"headline": "Obituaries", "sub": "%s, 41, a Benevolence Mutual claims adjuster, died Sunday of a treatable condition." % player}
			epilogue.append("You denied your own claim. It was, after all, out of network.")
			epilogue.append("Benevolence Mutual named you Employee of the Month, posthumously. A plaque will be installed near the break room.")
			epilogue.append("Your desk was reassigned by Monday.")
		PROMOTED:
			title = "PROMOTED"
			paper = {"headline": "Benevolence Mutual names new Regional Director", "sub": "%s, credited with a %d%% denial rate, takes over Claims Integrity." % [player, rate]}
			epilogue.append("You denied your own claim. The board admired your integrity.")
			epilogue.append("Regional Directors are covered by the Executive Plan, which has no exclusions. Your treatment was approved in four minutes.")
			epilogue.append("Your first directive raised the denial target to 80%.")
	epilogue.append(_family_line(run, survived))
	return {
		"id": id,
		"title": title,
		"paper": paper,
		"epilogue": epilogue,
		"stats": _stats(run),
		"survived": survived,
	}


static func _family_line(run: RunState, player_survived: bool) -> String:
	var alive: PackedStringArray = []
	var dead: PackedStringArray = []
	var sick: PackedStringArray = []
	for m in run.family:
		if not m["alive"]:
			dead.append(m["name"])
		else:
			alive.append(m["name"])
			if m["sick"]:
				sick.append(m["name"])
	if alive.is_empty():
		return "There was no one left at home to tell."
	var line := ""
	if dead.is_empty():
		line = "%s are still at home." % _join(alive) if player_survived else "%s were at the service." % _join(alive)
	else:
		line = "%s did not make it through the week. %s %s left." % [_join(dead), _join(alive), "is" if alive.size() == 1 else "are"]
	if not sick.is_empty():
		line += " %s still %s medicine." % [_join(sick), "needs" if sick.size() == 1 else "need"]
	return line


static func _join(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


static func _stats(run: RunState) -> Array:
	var s := run.stats
	return [
		["Claims processed", str(s.get("processed", 0))],
		["Denied", str(s.get("denied", 0))],
		["Approved", str(s.get("approved", 0))],
		["Denial rate", "%d%%" % roundi(denial_rate(run) * 100)],
		["Deaths in the paper", str(s.get("deaths", 0))],
		["Money earned", "$%d" % int(s.get("earned", 0))],
		["Final discontent", "%d%%" % roundi(run.discontent)],
	]
