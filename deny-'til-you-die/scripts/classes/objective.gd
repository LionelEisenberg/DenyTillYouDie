class_name Objective 
extends Resource

var objective_id: ObjectiveEnums.ObjectiveID
var description: String
var condition_type: GameEnums.ConditionType
var condition_value: Variant
var consequence_type: GameEnums.ConsequenceType
var consequence_value: Variant
var is_achieved: bool = false

func _init(
	_objective_id: ObjectiveEnums.ObjectiveID,
	_description: String, 
	_condition_type: GameEnums.ConditionType,
	_condition_value: Variant,
	_consequence_type: GameEnums.ConsequenceType, 
	_consequence_value: Variant):
		self.objective_id = _objective_id
		self.description = _description
		self.condition_type = _condition_type
		self.condition_value = _condition_value
		self.consequence_type = _consequence_type
		self.consequence_value = _consequence_value
