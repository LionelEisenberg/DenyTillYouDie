class_name Lines
## What patients say at the window.
##
## Any line can sit next to any card, so none says how long someone has been a
## member, when they joined, or how long a condition has been around: MEMBER SINCE
## and the medical history would contradict it.
##
## ClaimGenerator deals these from per-run shuffled decks (one per pool), so a
## line comes round again only once its whole deck has been used that week.

## Indexed by priority: 0 ROUTINE, 1 URGENT, 2 CRITICAL. At least 16 lines per priority.
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
		"That's my number? Sorry. I've been here since eight.",
		"The copay already went on my credit card. I'm hoping this covers the rest.",
		"I had to take two buses to get here.",
		"The receptionist said you'd sort it out.",
		"I filled this out in the waiting room. I hope you can read it.",
		"I'm not here to argue. I just want it processed.",
		"They sent me a bill, then a letter saying not to pay the bill yet.",
		"I don't usually go to the doctor. This time I didn't have a choice.",
		"Do I sign here, or did I already sign?",
		"I'd like a copy of whatever you decide, please.",
		"My doctor's office said someone would call. Nobody called.",
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
		"I'm still in a lot of pain, so I'll be quick.",
		"The hospital wants to know by tomorrow. So do I.",
		"Sorry. I came straight here. I haven't been home yet.",
		"They're holding the date for me. I need to know if I can keep it.",
		"I had to borrow money for the parking.",
		"This is the second shift I've missed to be here.",
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
		"My doctor wrote 'urgent' on every page.",
		"They told me plainly I don't have a lot of time.",
		"Please. I've done everything they asked.",
		"They want an answer today. They said today.",
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

## Arrival lines for one diagnosis, used for some patients instead of the
## priority deck. "adult" lines are the patient's own; "parent" lines speak for
## a child, with {child} as in ARRIVAL_PARENT. They name symptoms and moments,
## never a treatment the bill might not show, and never how long anything has
## been going on.
const DX_ARRIVAL: Dictionary = {
	"migraine": {"adult": [
		"Sorry. The light in here.",
		"Could we keep this quiet? Every sound goes right through my head.",
	]},
	"back_strain": {"adult": [
		"I'll stand, if that's all right. Sitting is worse.",
		"I bent down to pick up a laundry basket. That's the whole story.",
	]},
	"wrist_fx": {
		"adult": [
			"It's my left hand, at least. I can still sign.",
			"I fell on the steps at work. I heard it go.",
		],
		"parent": [
			"{child} fell off the monkey bars. The school called me at work.",
			"{child} didn't cry. I think that scared me more.",
		],
	},
	"ankle_sprain": {
		"adult": [
			"I stepped off a curb wrong. That's all it took.",
			"I can't drive like this. A neighbor brought me.",
		],
		"parent": [
			"{child} came down wrong at practice and couldn't stand up.",
			"I had to carry {child} up the stairs to get here.",
		],
	},
	"strep": {
		"adult": [
			"Sorry, it hurts to talk. I'll keep this short.",
			"I can barely swallow. Even water.",
		],
		"parent": [
			"{child} couldn't swallow anything. Not even ice cream.",
			"Half of {child}'s class is out with the same thing.",
		],
	},
	"ear_infection": {"parent": [
		"{child} was up all night holding one ear and crying.",
		"{child} keeps pulling at that ear. The doctor took one look.",
	]},
	"asthma_flare": {
		"adult": [
			"Sorry. I'm still a little short of breath.",
			"I couldn't get a full breath. I still can't, quite.",
		],
		"parent": [
			"{child} couldn't catch a breath. I've never driven so fast.",
			"{child}'s chest was whistling. The nurse heard it from the door.",
		],
	},
	"croup": {"parent": [
		"{child} sounded like a seal. The doctor said that's the word for it.",
		"{child} woke up barking and fighting for air. I didn't know what to do.",
	]},
	"appendicitis": {
		"adult": [
			"I thought it was something I ate. It wasn't.",
			"They said a few more hours and it would have burst.",
		],
		"parent": [
			"{child} said it hurt low on the right side. I didn't listen at first.",
			"{child} couldn't stand up straight. That's when I knew it was serious.",
		],
	},
	"kidney_stone": {"adult": [
		"I've never felt pain like that. I thought I was dying.",
		"I couldn't sit still in the car. I couldn't sit still anywhere.",
	]},
	"concussion": {
		"adult": [
			"Sorry. Could you say that again? Things keep slipping.",
			"I don't remember the fall. Just the floor, and then bright lights.",
		],
		"parent": [
			"{child} took a ball to the head and didn't know where they were.",
			"{child} keeps asking the same questions. The doctor says that's normal for now.",
		],
	},
	"hip_fx": {"adult": [
		"I fell in the bathroom. I lay there until a neighbor heard me.",
		"They say I'll walk again. They say it like a question.",
	]},
	"heart_attack": {"adult": [
		"It felt like someone was standing on my chest.",
		"I thought it was heartburn. I almost didn't go in.",
	]},
	"stroke": {"adult": [
		"Sorry. My words come out slow now.",
		"My left hand still won't do what I tell it.",
	]},
	"breast_cancer": {"adult": [
		"I found the lump myself. In the shower.",
		"They caught it. Everyone keeps saying that. They caught it.",
	]},
	"sepsis": {
		"adult": [
			"They said it got into my blood. That's all I understood.",
			"It started with a small cut. A small cut.",
		],
		"parent": [
			"{child} had a small cut on one knee. That's how it started.",
			"{child} had a fever and then wouldn't wake up properly.",
		],
	},
}

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

## After DENIED. At least 13 per priority. A critical one may be just "...".
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
		"Fine. I'll call the number on the card again.",
		"So I came down here for nothing.",
		"I'll have to set up a payment plan, then.",
		"Can I get that in writing?",
		"Okay. I guess I'll wait until it gets worse.",
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
		"I'll have to cancel it, then.",
		"I don't have that kind of money. Nobody does.",
		"Then I'll go back to work like this.",
		"So it's this or rent. That's the choice.",
		"Please don't say that. Please.",
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
		"I'll tell my family.",
		"Then there's nothing left to try.",
		"I don't think I can come back here again.",
		"I don't know how I'm going to tell them.",
		"Is there anything I can do? Anything at all?",
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
	var line := _pick(arrival_pool(priority, parent), rng)
	return fill_child(line, child_name) if parent else line


## What the patient says once the stamp lands. Parent lines ignore priority.
static func reaction(priority: int, approved: bool, parent: bool, rng: RandomNumberGenerator) -> String:
	return _pick(reaction_pool(priority, approved, parent), rng)


## The pool arrival lines come from for a priority and voice.
static func arrival_pool(priority: int, parent: bool) -> Array:
	var tier := clampi(priority, 0, 2)
	return ARRIVAL_PARENT[tier] if parent else ARRIVAL[tier]


## The pool reactions come from. Parent pools ignore priority.
static func reaction_pool(priority: int, approved: bool, parent: bool) -> Array:
	if parent:
		return APPROVED_PARENT if approved else DENIED_PARENT
	var tier := clampi(priority, 0, 2)
	return APPROVED[tier] if approved else DENIED[tier]


## DX_ARRIVAL lines for a diagnosis in one voice, or an empty array.
static func dx_pool(diagnosis_id: String, parent: bool) -> Array:
	var voices: Dictionary = DX_ARRIVAL.get(diagnosis_id, {})
	return voices.get("parent" if parent else "adult", [])


## Puts the child's first name into a parent line; an empty name reads "my kid".
static func fill_child(line: String, child_name: String) -> String:
	var who := child_name.strip_edges()
	if who.is_empty():
		who = "my kid"
	line = line.replace("{child}", who)
	return line.left(1).to_upper() + line.substr(1)


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
