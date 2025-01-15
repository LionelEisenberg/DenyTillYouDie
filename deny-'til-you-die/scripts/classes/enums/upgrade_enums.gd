class_name UpgradeEnums

enum UpgradeID {
	CLAIM_LEVEL_1, # = 0 | 0, 0
	APPROVAL_LOCKOUT_DECREASE_1, # 1 | 1, 0
	DENIAL_LOCKOUT_DECREASE_1, # 2 | 1, 1
	TEST_3, # 3 | 2, 1
	TEST_4, # 4 | 2, 2
}

static func get_upgrade_object(upgrade_id: UpgradeID) -> Upgrade:
	match upgrade_id:
		UpgradeID.CLAIM_LEVEL_1:
			return Upgrade.new(
				UpgradeID.CLAIM_LEVEL_1,
				"Claim Level Increase 1",
				"Increase you're claim level by 1! The higher the claim level, the bigger the rewards for processing claims!",
				Cost.new(0, GameEnums.ResourceType.MONEY),
				1,
				GameEnums.ConsequenceType.INCREASE_CLAIM_LEVEL,
				1,
				[UpgradeID.DENIAL_LOCKOUT_DECREASE_1, UpgradeID.APPROVAL_LOCKOUT_DECREASE_1]
			)
		UpgradeID.APPROVAL_LOCKOUT_DECREASE_1:
			return Upgrade.new(
				UpgradeID.APPROVAL_LOCKOUT_DECREASE_1,
				"Approval Lockout Decrease 1",
				"Decreases approval lockout time by 0.1s!",
				Cost.new(0, GameEnums.ResourceType.MONEY),
				3,
				GameEnums.ConsequenceType.DECREASE_APPROVAL_LOCKOUT,
				0.1,
				[UpgradeID.TEST_3, UpgradeID.TEST_4],
			)
		UpgradeID.DENIAL_LOCKOUT_DECREASE_1:
			return Upgrade.new(
				UpgradeID.DENIAL_LOCKOUT_DECREASE_1,
				"Denial Lockout Decrease 1",
				"Decreases denial lockout time by 0.5s!",
				Cost.new(0, GameEnums.ResourceType.MONEY),
				3,
				GameEnums.ConsequenceType.DECREASE_DENIAL_LOCKOUT,
				0.5,
			)
		UpgradeID.TEST_3:
			return Upgrade.new(
				UpgradeID.TEST_3,
				"Root",
				"TEST_3",
				Cost.new(0, GameEnums.ResourceType.MONEY),
				5,
				GameEnums.ConsequenceType.INCREASE_CLAIM_LEVEL,
				1
			)
		UpgradeID.TEST_4:
			return Upgrade.new(
				UpgradeID.TEST_4,
				"Root",
				"TEST_4",
				Cost.new(0, GameEnums.ResourceType.MONEY),
				5,
				GameEnums.ConsequenceType.INCREASE_CLAIM_LEVEL,
				1
			)
	return null
