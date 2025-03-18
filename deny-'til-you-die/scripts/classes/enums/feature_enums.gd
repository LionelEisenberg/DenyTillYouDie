class_name FeatureEnums

enum Feature {
	CLAIM_DENIAL,
	MONEY_UPGRADES,
	FRIVOLOUS_CLAIM_TYPE,
	TRAGIC_CLAIM_TYPE
}

static func get_unlock_text(feature: Feature) -> String:
	match feature:
		Feature.CLAIM_DENIAL:
			return "Congratulations! You've unlocked Denials!"
		Feature.MONEY_UPGRADES:
			return "Congratulations! You've unlocked the Upgrades tab!"
		Feature.FRIVOLOUS_CLAIM_TYPE:
			return "Congratulations! You've unlocked a new Claim Type: Frivolous Claims!"
		Feature.TRAGIC_CLAIM_TYPE:
			return "Congratulations! You've unlocked a new Claim Type: Tragic Claims!"
		_:
			return "Feature unlocked!"  # Default text
