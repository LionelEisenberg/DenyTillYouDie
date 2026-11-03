class_name Lines
## What patients say at the window.
##
## Any line can sit next to any card, so none says how long someone has been a
## member, when they joined, or how long a condition has been around: MEMBER SINCE
## and the medical history would contradict it.

## Indexed by priority: 0 ROUTINE, 1 URGENT, 2 CRITICAL. At least 8 lines per priority.
## No line names an injury or a treatment: any of them can sit next to any diagnosis.
const ARRIVAL: Array = [
	[ # ROUTINE
		"I've never filed a claim before. Not once.",
		"My doctor said this should be simple.",
		"I took the morning off for this. Unpaid.",
		"I called the number on the card. They told me to come in person.",
		"The bill came in the mail. I couldn't make sense of half of it.",
		"I've got a shift at two. Will this take long?",
		"They said to bring everything, so I brought everything.",
		"I waited three weeks for the appointment. I'm hoping this part goes faster.",
		"Third time filing this. First time in person.",
		"I just want to know what I owe before it goes to collections.",
		"Work picked this plan for us. I'm still figuring out how it works.",
		"I only went in because my doctor insisted.",
		"Hi. I think I filled everything out right this time.",
		"Forty-one? That's me. Sorry. I've been here since eight.",
	],
	[ # URGENT
		"The ER said to sort out the insurance afterward. So, this is afterward.",
		"They won't schedule anything until you sign off.",
		"I can't work until this is handled. I've already missed a week.",
		"My doctor marked it urgent. I hope you see it the same way.",
		"I drove myself to the ER. I couldn't afford the ambulance.",
		"The hospital wants a deposit by Friday. I don't have it.",
		"I have to pick up my kids by six. Is this going to be quick?",
		"They gave me something for the pain and a stack of forms. Here are the forms.",
		"My doctor says the longer this waits, the worse it gets.",
		"I came straight from the hospital. They didn't even take the wristband off.",
		"I've been in the waiting room since seven.",
		"My manager says if I miss another week, don't bother coming back.",
		"The ER bill and the doctor's note are both in there. I checked twice.",
	],
	[ # CRITICAL
		"They told me I shouldn't be out of bed. I came anyway.",
		"The doctors want to start tomorrow. If you say yes.",
		"Please. They won't do anything until you approve it.",
		"I signed everything they gave me. I don't remember signing half of it.",
		"My oldest drove me here. They're circling the block.",
		"I've paid in all this time. I need it now.",
		"Sorry. Is there somewhere I can sit?",
		"The hospital sent me here. They said it's the last form.",
		"They're holding a bed for me until four o'clock.",
		"My kids think I'm at work.",
		"Everything's in there. Please don't make me come back.",
		"The doctors are waiting on your answer. So am I.",
	],
]

## A parent speaking for a child patient. {child} is the child's first name. At least 5 per priority.
## {child} only ever opens the line or sits mid-sentence, so the "my kid" fallback reads right.
const ARRIVAL_PARENT: Array = [
	[ # ROUTINE
		"This is for {child}. The pediatrician said it's routine.",
		"{child} missed school for the appointment. I missed work. Here's the claim.",
		"We pay for {child}'s coverage out of every paycheck.",
		"It's for {child}, who's at school right now. I'm on my lunch break.",
		"The doctor wanted {child} seen before it got worse. So we went.",
		"{child} was brave about it. Now it's my turn, I guess.",
		"I'm filing for {child}. I'm the parent on the plan.",
	],
	[ # URGENT
		"{child} is waiting in the car. Can we do this quickly?",
		"The ER took {child} right away. The bill took a little longer.",
		"They want to treat {child} this week, but they need you to approve it first.",
		"{child} hasn't slept in two days. Neither have I.",
		"{child}'s doctor said it couldn't wait. I hope you agree.",
		"{child} keeps asking when we can go home.",
		"I had to leave {child} with a neighbor to come down here.",
	],
	[ # CRITICAL
		"{child} is upstairs at the hospital. I can't be gone long.",
		"The doctors say {child} needs this now. Not next week. Now.",
		"I left {child} with the nurses to come here. Please hurry.",
		"They won't start {child}'s treatment without your stamp.",
		"I told {child} I'd be back before dinner.",
		"Please look at it. It's for {child}.",
		"{child}'s class made cards. They're taped up all over the room.",
	],
]

## After the claim is stamped APPROVED. At least 5 per priority.
const APPROVED: Array = [
	[ # ROUTINE
		"Oh. Okay. Thank you.",
		"That's it? Thank you.",
		"Great. I can still make my shift.",
		"Thanks. Honestly, I didn't expect that.",
		"Okay. Good. One less thing.",
		"Thank you. Really.",
		"That's a relief. Thanks.",
	],
	[ # URGENT
		"Oh, thank God.",
		"Thank you. I'll call the hospital right now.",
		"So I can go back to work. Thank you.",
		"I didn't think you would. Thank you.",
		"Okay. Okay. I can breathe.",
		"Thank you. I mean it.",
		"I'm going to sit in my car for a minute. Thank you.",
	],
	[ # CRITICAL
		"Thank you. Thank you.",
		"I'll tell the doctors. They can start today.",
		"...Thank you.",
		"I'm going to call my kids.",
		"I don't know what to say. Thank you.",
		"So they can start? Okay. Okay.",
		"Okay. I need to get back to the hospital.",
	],
]

## After DENIED. At least 6 per priority. A critical one may be just "...".
const DENIED: Array = [
	[ # ROUTINE
		"Okay. So what do I do now?",
		"I've paid my premiums every month. Every single month.",
		"Is there someone else I can talk to?",
		"Right. I'll just pay it, I guess. Somehow.",
		"Can I appeal? Where do I go to appeal?",
		"I took the day off for this.",
		"So what am I paying you for?",
		"I'll put it on the card with the others.",
		"Okay. I'll skip the follow-up, then.",
	],
	[ # URGENT
		"They won't go ahead without this.",
		"I can't pay this. I don't know what you want me to do.",
		"That's three months of rent.",
		"Can you check again? Please. Just check again.",
		"So I just go home? Like this?",
		"I did everything they told me to.",
		"My doctor said this would be covered.",
		"I'll have to sell the car.",
	],
	[ # CRITICAL
		"...",
		"Okay.",
		"What am I supposed to tell my kids?",
		"Then I don't know what happens now.",
		"I understand.",
		"Can I stay here a minute? I just need a minute.",
		"So that's it.",
		"I'll tell the doctors to stop, then.",
	],
]

## A parent's reaction, for a child patient of any priority. At least 4.
const APPROVED_PARENT: Array[String] = [
	"Thank you. I'm going to go tell my kid.",
	"Oh, thank God. Thank you.",
	"Thank you. We can finally go home.",
	"I'll call the doctor's office from the car. Thank you.",
	"Okay. Okay. I need to sit down for a second.",
	"Thank you. You have no idea.",
]

## At least 5.
const DENIED_PARENT: Array[String] = [
	"How do I explain this to my kid?",
	"I saw the bill. We can't pay that.",
	"I'll pick up extra shifts. I'll figure something out.",
	"Please. Look at it one more time.",
	"I don't know what to tell the doctors.",
	"We'll find the money. We always do.",
	"...",
	"I promised I'd fix this.",
]

## Sometimes said after a denial that cites a rule. {code} like "R-03", {rule} like "Clerical mismatch". At least 6.
const CODE_REACTIONS: Array[String] = [
	"{code}? What's {code}?",
	"{rule}? Nobody told me about that.",
	"What does '{rule}' even mean?",
	"My doctor's office handled all that. {rule}?",
	"Can you write down {code} for me? For the appeal.",
	"I've never heard of {code}.",
	"{rule}. Okay. I'll tell the hospital.",
	"Is {code} written down somewhere? Can I see it?",
]

## Reactions to one rule in particular, keyed by code. code_reaction() uses them half the time.
## They fit an adult patient or a parent.
const CODE_SPECIFIC: Dictionary = {
	"R-01": [
		"It lapsed? The premium comes right out of my paycheck.",
		"I was a few days late on one payment. A few days.",
		"I sent the check. I have the stub somewhere.",
	],
	"R-02": [
		"The ambulance picked the hospital. I didn't.",
		"It was the closest place. Where else were we supposed to go?",
		"Nobody at the front desk said anything about a network.",
	],
	"R-03": [
		"Somebody typed it wrong. That's on me?",
		"It's a typo. Everything else matches.",
		"Can I just fix the form? I'll fix it right here.",
	],
	"R-04": [
		"My doctor's office said they'd handle the authorization.",
		"Nobody told me we needed permission first.",
		"They said it couldn't wait. Was I supposed to wait?",
	],
	"R-05": [
		"That was before we signed up. It was under control.",
		"We knew about it. That's why we got insurance.",
		"So it's not covered because it started before?",
	],
	"R-06": [
		"Excluded? It's what the doctor ordered.",
		"Then what does the plan cover?",
		"It's the only treatment they offered.",
	],
	"R-07": [
		"A computer decided? Can I talk to it?",
		"Did a person even look at this?",
		"It took you two seconds.",
	],
}


## The line a patient (or a child patient's parent) opens with at the window.
## An empty child_name falls back to "my kid".
static func arrival(priority: int, parent: bool, child_name: String, rng: RandomNumberGenerator) -> String:
	var tier := clampi(priority, 0, 2)
	var pool: Array = ARRIVAL_PARENT[tier] if parent else ARRIVAL[tier]
	var line := _pick(pool, rng)
	if not parent:
		return line
	var who := child_name.strip_edges()
	if who.is_empty():
		who = "my kid"
	line = line.replace("{child}", who)
	return line.left(1).to_upper() + line.substr(1)


## What the patient says once the stamp lands. Parent lines ignore priority.
static func reaction(priority: int, approved: bool, parent: bool, rng: RandomNumberGenerator) -> String:
	if parent:
		return _pick(APPROVED_PARENT if approved else DENIED_PARENT, rng)
	var tier := clampi(priority, 0, 2)
	var pool: Array = APPROVED[tier] if approved else DENIED[tier]
	return _pick(pool, rng)


## A reaction to the rule cited on a denial. Half the time it is specific to that rule, when
## CODE_SPECIFIC has lines for the code; otherwise a generic line from CODE_REACTIONS.
static func code_reaction(code: String, rule_title: String, rng: RandomNumberGenerator) -> String:
	var pool: Array = CODE_REACTIONS
	if CODE_SPECIFIC.has(code) and rng.randf() < 0.5:
		pool = CODE_SPECIFIC[code]
	return _pick(pool, rng).format({"code": code, "rule": rule_title})


static func _pick(pool: Array, rng: RandomNumberGenerator) -> String:
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]
