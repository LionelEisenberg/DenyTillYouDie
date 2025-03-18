class_name UpgradeEnums

enum UpgradeID {
	CLAIM_LEVEL_1,
	APPROVAL_LOCKOUT_DECREASE_1,
	DENIAL_LOCKOUT_DECREASE_1,
	CLAIM_LEVEL_2,
	UNLOCK_TRAGIC_CLAIM_TYPE,
	UNLOCK_FRIVOLOUS_CLAIM_TYPE,
	INCREASE_TRAGIC_CLAIM_CHANCE_1,
	INCREASE_FRIVOLOUS_CLAIM_CHANCE_1,
	INCREASE_APPROVAL_MONEY_1,
	INCREASE_APPROVAL_GOODWILL_1,
	INCREASE_DENIAL_MONEY_1,
	DECREASE_DENIAL_GOODWILL_1,
}

static func get_upgrade_object(upgrade_id: UpgradeID) -> Upgrade:
	match upgrade_id:
		UpgradeID.CLAIM_LEVEL_1:
			return Upgrade.new(
				UpgradeID.CLAIM_LEVEL_1,
				"Claim Big or Claim Nothing",
				"Level up your claim game! Bigger claims, bigger headaches, and maybe some actual rewards!",
				Cost.new(1500, GameEnums.ResourceType.MONEY),
				1,
				GameEnums.ConsequenceType.INCREASE_CLAIM_LEVEL,
				1,
				[UpgradeID.DENIAL_LOCKOUT_DECREASE_1, UpgradeID.APPROVAL_LOCKOUT_DECREASE_1, UpgradeID.CLAIM_LEVEL_2]
			)

		UpgradeID.APPROVAL_LOCKOUT_DECREASE_1:
			return Upgrade.new(
				UpgradeID.APPROVAL_LOCKOUT_DECREASE_1,
				"Stamp of Approval Speed Boost",
				"Why wait to say yes? Approve claims faster, and enjoy the sweet sound of money flowing (hopefully).",
				Cost.new(1500, GameEnums.ResourceType.MONEY, 1.18),
				5,
				GameEnums.ConsequenceType.DECREASE_APPROVAL_LOCKOUT,
				0.1
			)

		UpgradeID.DENIAL_LOCKOUT_DECREASE_1:
			return Upgrade.new(
				UpgradeID.DENIAL_LOCKOUT_DECREASE_1,
				"Fast-Track Rejections",
				"Deny faster than ever! Don’t give them time to hope. Perfect for the busy claims officer.",
				Cost.new(1500, GameEnums.ResourceType.MONEY, 1.18),
				5,
				GameEnums.ConsequenceType.DECREASE_DENIAL_LOCKOUT,
				1
			)

		UpgradeID.CLAIM_LEVEL_2:
			return Upgrade.new(
				UpgradeID.CLAIM_LEVEL_2,
				"Top-Shelf Claims Only",
				"You’re moving up in the world. Handle higher-tier claims and pretend you’re important!",
				Cost.new(2000, GameEnums.ResourceType.MONEY),
				1,
				GameEnums.ConsequenceType.INCREASE_CLAIM_LEVEL,
				1,
				[UpgradeID.UNLOCK_TRAGIC_CLAIM_TYPE, UpgradeID.UNLOCK_FRIVOLOUS_CLAIM_TYPE]
			)

		UpgradeID.UNLOCK_TRAGIC_CLAIM_TYPE:
			return Upgrade.new(
				UpgradeID.UNLOCK_TRAGIC_CLAIM_TYPE,
				"Unlock Tears and Profits",
				"Tragic claims are here! Cry your way to the top while the public weeps with you (or at you).",
				Cost.new(2500, GameEnums.ResourceType.MONEY),
				1,
				GameEnums.ConsequenceType.UNLOCK_FEATURE,
				FeatureEnums.Feature.TRAGIC_CLAIM_TYPE
			)

		UpgradeID.UNLOCK_FRIVOLOUS_CLAIM_TYPE:
			return Upgrade.new(
				UpgradeID.UNLOCK_FRIVOLOUS_CLAIM_TYPE,
				"Petty Claims, Big Public Love",
				"Who cares if it’s ridiculous? The public loves drama. Milk it for goodwill points!",
				Cost.new(2500, GameEnums.ResourceType.MONEY),
				1,
				GameEnums.ConsequenceType.UNLOCK_FEATURE,
				FeatureEnums.Feature.FRIVOLOUS_CLAIM_TYPE
			)

		UpgradeID.INCREASE_TRAGIC_CLAIM_CHANCE_1:
			return Upgrade.new(
				UpgradeID.INCREASE_TRAGIC_CLAIM_CHANCE_1,
				"Tragedy Magnet",
				"The sadder the claim, the more it shows up! Make the office tissues tax-deductible.",
				Cost.new(1000, GameEnums.ResourceType.MONEY, 1.18),
				5,
				GameEnums.ConsequenceType.CHANGE_TRAGIC_CLAIM_CHANCE,
				0.01
			)

		UpgradeID.INCREASE_FRIVOLOUS_CLAIM_CHANCE_1:
			return Upgrade.new(
				UpgradeID.INCREASE_FRIVOLOUS_CLAIM_CHANCE_1,
				"Frivolity Frenzy",
				"Turn your claim desk into a circus! Double the laughs, triple the paperwork.",
				Cost.new(1000, GameEnums.ResourceType.MONEY, 1.18),
				5,
				GameEnums.ConsequenceType.CHANGE_FRIVOLOUS_CLAIM_CHANCE,
				0.01
			)

		UpgradeID.INCREASE_APPROVAL_MONEY_1:
			return Upgrade.new(
				UpgradeID.INCREASE_APPROVAL_MONEY_1,
				"Cha-Ching for Approval",
				"Why approve for free when you can approve for a little extra cash? It's business, baby!",
				Cost.new(1000, GameEnums.ResourceType.MONEY, 1.15),
				5,
				GameEnums.ConsequenceType.CHANGE_UPGRADE_APPROVAL_MONEY,
				0.1
			)

		UpgradeID.INCREASE_APPROVAL_GOODWILL_1:
			return Upgrade.new(
				UpgradeID.INCREASE_APPROVAL_GOODWILL_1,
				"Warm Fuzzies for Yeses",
				"Saying yes to claims has never felt so good! Your PR team will thank you.",
				Cost.new(1000, GameEnums.ResourceType.MONEY, 1.15),
				5,
				GameEnums.ConsequenceType.CHANGE_UPGRADE_APPROVAL_GOODWILL,
				0.01
			)

		UpgradeID.INCREASE_DENIAL_MONEY_1:
			return Upgrade.new(
				UpgradeID.INCREASE_DENIAL_MONEY_1,
				"Profitable No’s",
				"Why just say no when you can make it profitable? Cash in on disappointment.",
				Cost.new(1000, GameEnums.ResourceType.MONEY, 1.15),
				5,
				GameEnums.ConsequenceType.CHANGE_UPGRADE_DENIAL_MONEY,
				0.05
			)

		UpgradeID.DECREASE_DENIAL_GOODWILL_1:
			return Upgrade.new(
				UpgradeID.DECREASE_DENIAL_GOODWILL_1,
				"Kindly Crushing Dreams",
				"Softens the blow of a denied claim. Because who said rejecting people couldn’t be polite?",
				Cost.new(1000, GameEnums.ResourceType.MONEY, 1.15),
				5,
				GameEnums.ConsequenceType.CHANGE_UPGRADE_DENIAL_GOODWILL,
				-0.01
			)

	return null
