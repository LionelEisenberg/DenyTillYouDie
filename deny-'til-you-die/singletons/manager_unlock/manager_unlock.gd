class_name ManagerUnlock
extends Node

static var ref : ManagerUnlock

func _init() -> void:
	if not ref : ref = self
	else : queue_free()

@onready var save_game_data : SaveGameData = Game.ref.save_game_data

signal feature_unlocked(feature : FeatureEnums.Feature)

func is_feature_unlocked(feature : FeatureEnums.Feature) -> bool:
	match feature:
		FeatureEnums.Feature.CLAIM_DENIAL:
			return save_game_data.unlock_data.denial_unlocked
		FeatureEnums.Feature.MONEY_UPGRADES:
			return save_game_data.unlock_data.money_upgrades_unlocked
		FeatureEnums.Feature.FRIVOLOUS_CLAIM_TYPE:
			return save_game_data.unlock_data.frivolous_claim_type_unlocked
		FeatureEnums.Feature.TRAGIC_CLAIM_TYPE:
			return save_game_data.unlock_data.tragic_claim_type_unlocked
		_:
			return false

func unlock_feature(feature: FeatureEnums.Feature) -> void:
	if is_feature_unlocked(feature): return
	match feature:
		FeatureEnums.Feature.CLAIM_DENIAL:
			save_game_data.unlock_data.denial_unlocked = true
		FeatureEnums.Feature.MONEY_UPGRADES:
			save_game_data.unlock_data.money_upgrades_unlocked = true
		FeatureEnums.Feature.FRIVOLOUS_CLAIM_TYPE:
			save_game_data.unlock_data.frivolous_claim_type_unlocked = true
			ManagerClaim.ref.unlock_claim_type(ClaimEnums.ClaimType.FRIVOLOUS)
		FeatureEnums.Feature.TRAGIC_CLAIM_TYPE:
			save_game_data.unlock_data.tragic_claim_type_unlocked = true
			ManagerClaim.ref.unlock_claim_type(ClaimEnums.ClaimType.TRAGIC)
		_:
			pass
	feature_unlocked.emit(feature)

func get_feature_unlock_text(feature : FeatureEnums.Feature) -> String:
	return FeatureEnums.get_unlock_text(feature)
