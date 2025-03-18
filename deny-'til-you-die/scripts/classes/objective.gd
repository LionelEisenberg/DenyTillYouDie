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

func get_formatted_description(current_progress: int) -> String:
	var formatted_description = ""
	match condition_type:
		GameEnums.ConditionType.APPROVE_CLAIMS:
			formatted_description = "[center][img=48x48]res://assets/textures/claims/approve.png[/img] [font=res://assets/fonts/objective_font.tres] %d / %d[/font][/center]" % [current_progress, condition_value]
		GameEnums.ConditionType.DENY_CLAIMS:
			formatted_description = "[center][img=48x48]res://assets/textures/claims/deny.png[/img] [font=res://assets/fonts/objective_font.tres] %d / %d[/font][/center]" % [current_progress, condition_value]
		# Add other condition types as needed...
	return formatted_description
