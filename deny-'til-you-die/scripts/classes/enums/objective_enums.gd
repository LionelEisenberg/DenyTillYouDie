# ObjectiveEnums.gd
class_name ObjectiveEnums

enum ObjectiveID {
	APPROVE_5_CLAIMS,
	DENY_5_CLAIMS,
	REACH_5000_MONEY,
	REACH_100_GOODWILL,
	REACH_25000_MONEY_250_GOODWILL,
	REACH_500_GOODWILL,
	REACH_100000_MONEY,
	REACH_1000000_MONEY,
	TRIGGER_PUBLIC_OUTRAGE,
	REACH_5000000_MONEY_5_AI,
	REACH_25000000_MONEY
}

static func get_objective_object(objective_id: ObjectiveID) -> Objective:
	match objective_id:
		ObjectiveID.APPROVE_5_CLAIMS:
			return Objective.new(
				objective_id,
				"Approve 5 claims",
				GameEnums.ConditionType.APPROVE_CLAIMS,
				5,
				GameEnums.ConsequenceType.UNLOCK_FEATURE,
				FeatureEnums.Feature.CLAIM_DENIAL
			)
		ObjectiveID.DENY_5_CLAIMS:
			return Objective.new(
				objective_id,
				"Deny 3 claims",
				GameEnums.ConditionType.DENY_CLAIMS,
				3,
				GameEnums.ConsequenceType.UNLOCK_FEATURE,
				FeatureEnums.Feature.MONEY_UPGRADES
			)
		# ... other objectives
		_:
			return null  # Or handle invalid objective ID differently
