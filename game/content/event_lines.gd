class_name EventLines
## What patients say at the window on event days, and the booth poster's slogan.
##
## Like Lines, nothing here names a diagnosis or says how long anyone has been a
## member: any line can sit next to any card. Patients state what they saw.

## Most visible first: the poster shows the first active one.
const EVENTS: PackedStringArray = ["compassion", "audit", "protest"]

## At least 3 per event.
const ARRIVAL: Dictionary = {
	"protest": [
		"They had signs outside. I came in the side door.",
		"There's a crowd by the front doors. Someone handed me a flyer. I didn't read it.",
		"A man outside asked if I was here about a claim. I said yes. He shook my hand.",
		"You can hear them chanting from the elevator.",
	],
	"audit": [
		"A woman at the door asked how long I'd waited. She wrote it down.",
		"There's a man with a clipboard in the waiting room. He's been watching the line.",
		"Someone from the state asked to see my paperwork. I told them it's all here.",
	],
	"compassion": [
		"There are balloons in the lobby. What's the occasion?",
		"The sign out front says Compassion Day. I figured I'd try again.",
		"Somebody gave me a cookie at the door. It has the company logo on it.",
	],
}

## A parent speaking for a child. {child} is the child's first name. At least 2 per event.
const ARRIVAL_PARENT: Dictionary = {
	"protest": [
		"There were people with signs outside. {child} wanted to know what they were for.",
		"{child} asked why everyone outside was shouting. I didn't have an answer.",
	],
	"audit": [
		"A woman with a clipboard asked how old {child} is. Then she asked who I was.",
		"Someone from the state asked if {child} was seen today. I said that's why we're here.",
	],
	"compassion": [
		"{child} got a balloon at the door. Is today some kind of holiday?",
		"They gave {child} a sticker in the lobby. It says WE CARE.",
	],
}

## The booth poster on an event day. At most 40 characters each.
const POSTERS: Dictionary = {
	"protest": "Please use the side entrance.",
	"audit": "Regulators are our partners.",
	"compassion": "COMPASSION DAY. Approve visibly.*",
}
## The poster on any other day once discontent reaches POSTER_DISCONTENT.
const HIGH_DISCONTENT_POSTER := "We hear you.*"
const POSTER_DISCONTENT := 80.0


## The day's active events, most visible first.
static func active(effects: Dictionary) -> PackedStringArray:
	var on: PackedStringArray = []
	for id in EVENTS:
		if effects.get(id, false):
			on.append(id)
	return on


## The event line `c` opens with, or "" when it opens with its own line: about one
## random patient in three on an event day, never a scripted case or the player.
static func opening(c: Claim, effects: Dictionary) -> String:
	var on := active(effects)
	if on.is_empty() or c.scripted_id != "" or c.is_player or posmod(c.line_seed, 3) != 0:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.line_seed, "event"])
	var id := on[rng.randi_range(0, on.size() - 1)]
	var pool: Array = ARRIVAL_PARENT[id] if c.parent_speaks else ARRIVAL[id]
	var line: String = pool[rng.randi_range(0, pool.size() - 1)]
	if not c.parent_speaks:
		return line
	var who := c.first_name().strip_edges()
	if who.is_empty():
		who = "my kid"
	line = line.replace("{child}", who)
	return line.left(1).to_upper() + line.substr(1)


## The slogan on the booth poster: the event's, or "We hear you.*" at high
## discontent, or `usual` (the day's company slogan).
static func poster(effects: Dictionary, discontent: float, usual: String) -> String:
	var on := active(effects)
	if not on.is_empty():
		return POSTERS[on[0]]
	if discontent >= POSTER_DISCONTENT:
		return HIGH_DISCONTENT_POSTER
	return usual
