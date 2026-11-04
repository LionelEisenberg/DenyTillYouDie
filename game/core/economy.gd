class_name Economy
## Every tunable number in the game. Arrays are indexed by Claim.Priority
## (ROUTINE, URGENT, CRITICAL). Tuned with tests/balance_sim.gd.

# Pay
const BASE_PAY := 45
const COMMISSION: Array[int] = [8, 15, 25]
const BLIND_COMMISSION: Array[int] = [4, 7, 12]
const APPROVAL_COST: Array[int] = [3, 6, 10]
const COMPLIANCE_FEE := 2
const FREE_WARNINGS := 2
const CITATION_FINE := 5
const LEGAL_FEE := 15
const BOSS_PENALTY := 30

# Claims Integrity's daily denial target, in whole percent, by day (1-7). Meeting
# it pays TARGET_BONUS on that night's ledger; day 1 has no target and day 7 no night.
const DAILY_TARGET: Array[int] = [0, 55, 60, 60, 65, 65, 67]
const TARGET_BONUS := 10

# Public discontent, in percentage points
const START_DISCONTENT := 10.0
const DISCONTENT_DENY: Array[float] = [1.5, 3.0, 5.0]
const DISCONTENT_APPROVE: Array[float] = [1.0, 2.0, 3.0]
const CHILD_MULT := 1.5
const DENYBOT_MULT := 2.0
const PROTEST_EXTRA := 1.0
const COMPASSION_RELIEF_MULT := 2.0
const APPEAL_CHANCE := 0.5
const APPEAL_DISCONTENT := 2.0
const DEATH_CHANCE: Array[float] = [0.0, 0.10, 0.40]
const DEATH_DISCONTENT := 3.0
const NIGHT_DECAY := 3.0
const THRESHOLDS: Array[int] = [30, 55, 80]
const SCAPEGOAT_AT := 100.0

# Household
const START_SAVINGS := 40
const RENT := 25
const FOOD := 15
const HEAT := 10
const MEDICINE := 20
## Mom's heart pills and Riley's controller inhaler, each per night.
const PRESCRIPTION := 10
## What Sam's pharmacy coupon takes off each pharmacy bill (medicine for the
## sick and both prescriptions) on the night it turns up.
const COUPON_OFF := 5
## The household events' bills, by Household.EVENTS id. The coupon is a discount.
const HOUSEHOLD_EVENT_COST: Dictionary = {
	"furnace": 30,
	"dentist": 35,
	"class_trip": 8,
	"collection": 15,
	"coupon": 0,
	"glasses": 6,
	"bus_pass": 10,
}

# Endings
const PROMOTION_RATE := 0.67


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


## The denial target for `day` in whole percent (0 when there is none).
static func target_for(day: int) -> int:
	if day < 1 or day > DAILY_TARGET.size():
		return 0
	return DAILY_TARGET[day - 1]
