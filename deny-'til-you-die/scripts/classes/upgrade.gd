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
	_upgrade_id: UpgradeEnums.UpgradeID,
	_name: String,
	_description: String,
	_cost: Cost,
	_max_level,
	_consequence_type: GameEnums.ConsequenceType,
	_consequence_value: Variant,
	_children: Array[UpgradeEnums.UpgradeID] = []):
		self.upgrade_id = _upgrade_id
		self.name = _name
		self.description = _description
		self.cost = _cost
		self.max_level = _max_level
		self.consequence_type = _consequence_type
		self.consequence_value = _consequence_value
		self.children = _children
