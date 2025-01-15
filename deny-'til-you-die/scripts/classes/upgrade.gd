class_name Upgrade 
extends Resource

var upgrade_id: UpgradeEnums.UpgradeID
var name: String
var description: String
var cost: Cost
var children: Array[UpgradeEnums.UpgradeID] = []
var max_level: int = 1
var consequence_type: GameEnums.ConsequenceType
var consequence_value: Variant


func _init(
	upgrade_id: UpgradeEnums.UpgradeID,
	name: String,
	description: String,
	cost: Cost,
	max_level,
	consequence_type: GameEnums.ConsequenceType,
	consequence_value: Variant,
	children: Array[UpgradeEnums.UpgradeID] = []):
		self.upgrade_id = upgrade_id
		self.name = name
		self.description = description
		self.cost = cost
		self.max_level = max_level
		self.consequence_type = consequence_type
		self.consequence_value = consequence_value
		self.children = children
