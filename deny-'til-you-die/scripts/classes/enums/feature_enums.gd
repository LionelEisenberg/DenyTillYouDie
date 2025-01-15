class_name FeatureEnums

enum Feature {
	CLAIM_DENIAL,
	MONEY_UPGRADES
}

static func get_unlock_text(feature: Feature) -> String:
	match feature:
		Feature.CLAIM_DENIAL:
			return "Congratulations! You've unlocked Denials!"
		Feature.MONEY_UPGRADES:
			return "Congratulations! You've unlocked the Upgrades tab!"
		_:
			return "Feature unlocked!"  # Default text
