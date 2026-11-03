class_name Economy
## Every tunable number in the game. Arrays are indexed by Claim.Priority
## (ROUTINE, URGENT, CRITICAL). Tuned with tests/balance_sim.gd.

# Pay
const BASE_PAY := 30
const COMMISSION: Array[int] = [15, 25, 40]
const BLIND_COMMISSION: Array[int] = [7, 12, 20]
const APPROVAL_COST: Array[int] = [5, 10, 15]
const COMPLIANCE_FEE := 2
const FREE_WARNINGS := 2
const CITATION_FINE := 10
const LEGAL_FEE := 20
const BOSS_PENALTY := 40

# Public discontent, in percentage points
const START_DISCONTENT := 10.0
const DISCONTENT_DENY: Array[float] = [2.0, 4.0, 7.0]
const DISCONTENT_APPROVE: Array[float] = [1.0, 2.0, 3.0]
const CHILD_MULT := 1.5
const DENYBOT_MULT := 2.0
const PROTEST_EXTRA := 1.0
const COMPASSION_RELIEF_MULT := 2.0
const APPEAL_CHANCE := 0.5
const APPEAL_DISCONTENT := 2.0
const DEATH_CHANCE: Array[float] = [0.0, 0.10, 0.40]
const DEATH_DISCONTENT := 4.0
const NIGHT_DECAY := 2.0
const THRESHOLDS: Array[int] = [30, 55, 80]
const SCAPEGOAT_AT := 100.0

# Household
const START_SAVINGS := 50
const RENT := 30
const FOOD := 15
const HEAT := 10
const MEDICINE := 25

# Endings
const PROMOTION_RATE := 0.6


static func commission(priority: int, cited: bool) -> int:
	return COMMISSION[priority] if cited else BLIND_COMMISSION[priority]


static func approval_cost(priority: int, compassion_day: bool) -> int:
	return 0 if compassion_day else APPROVAL_COST[priority]


static func denial_discontent(c: Claim, denybot: bool, protest: bool) -> float:
	var amount := DISCONTENT_DENY[c.priority]
	if c.is_child():
		amount *= CHILD_MULT
	if denybot:
		amount *= DENYBOT_MULT
	if protest:
		amount += PROTEST_EXTRA
	return amount


## How much an approval lowers discontent (a positive number).
static func approval_relief(c: Claim, compassion_day: bool) -> float:
	var amount := DISCONTENT_APPROVE[c.priority]
	if compassion_day:
		amount *= COMPASSION_RELIEF_MULT
	return amount
