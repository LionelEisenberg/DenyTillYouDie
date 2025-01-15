class_name UpgradeData 
extends Resource

@export var upgrade_levels: Dictionary = {}

func _init():
	# Initialize upgrade_levels with all UpgradeIDs as 0 (level 0)
	for upgrade_id in UpgradeEnums.UpgradeID.values():
		upgrade_levels[upgrade_id] = 0

func get_upgrade_level(upgrade_id: UpgradeEnums.UpgradeID) -> int:
	return upgrade_levels.get(upgrade_id, 0)  # Default to 0 if not found

func set_upgrade_level(upgrade_id: UpgradeEnums.UpgradeID, level: int):
	upgrade_levels[upgrade_id] = level
