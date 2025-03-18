# GameEnums.gd
class_name GameEnums

enum ConsequenceType {
	UNLOCK_FEATURE,
	START_EVENT,
	INCREASE_GOOFINESS_LEVEL,
	UNLOCK_UPGRADE,
	GET_MONEY,
	GET_GOODWILL,
	INCREASE_CLAIM_LEVEL,
	DECREASE_APPROVAL_LOCKOUT,
	DECREASE_DENIAL_LOCKOUT,
	CHANGE_TRAGIC_CLAIM_CHANCE,
	CHANGE_FRIVOLOUS_CLAIM_CHANCE,
	CHANGE_UPGRADE_APPROVAL_MONEY,
	CHANGE_UPGRADE_APPROVAL_GOODWILL,
	CHANGE_UPGRADE_DENIAL_MONEY,
	CHANGE_UPGRADE_DENIAL_GOODWILL,
}

enum ConditionType {
	APPROVE_CLAIMS,
	DENY_CLAIMS,
	REACH_MONEY,
	REACH_GOODWILL,
	REACH_MONEY_AND_GOODWILL,
	TRIGGER_EVENT
}

enum ResourceType {
	MONEY,
	GOODWILL
}
