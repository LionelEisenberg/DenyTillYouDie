class_name HomeLines
## One line from home on each night's ledger. NightLogic.home_line() checks the
## situations in the order below and uses the first that fits. Observational:
## the family never judges the job, and nothing here is a joke.

## Anyone in the family has died. {name} is one of them.
const DEAD := "Nobody has moved {name}'s coat from the hook."
## The night before the last shift.
const NIGHT_SIX := "Your head was pounding on the bus home. You took two aspirin and sat down with the bills."
const RILEY_SICK := "Riley's breathing is loud tonight. You counted the puffs left in the old inhaler."
## Someone other than Riley is sick. {name} is one of them.
const SICK := "{name} coughed most of the night. You left the bedroom door open to listen."
const HUNGRY := "Dinner was rice again. Nobody said anything, which was worse."
const COLD := "Everyone slept in their coats. Mom said it was like being a girl again."
## The night of the day you denied Lily Navarro.
const AFTER_LILY := "Riley asked if kids can get cancer. You said hardly ever."
## By discontent band, matching Economy.THRESHOLDS (30, 55, 80).
const DISCONTENT: PackedStringArray = [
	"A neighbor asked where you work. You said downtown.",
	"Riley's teacher asked what you do. Riley said you help people with forms.",
	"Someone left a copy of the Ledger on your doormat, folded to the front page.",
]
const NIGHT_ONE := "Sam asked how the first day went. You said it was mostly paperwork."
## Left out of the ordinary pool while the furnace is broken or out.
const RADIATOR := "The radiator knocked all night."
## Any other night.
const ORDINARY: PackedStringArray = [
	"Sam kept a plate warm for you.",
	"Riley fell asleep on the couch waiting up.",
	"Mom asked if your plan covers dental. You said you'd check.",
	RADIATOR,
]
