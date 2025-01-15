class_name ObjectiveData 
extends Resource

@export var completed_objectives: Dictionary = {}

func _init():
	# Initialize completed_objectives with all ObjectiveIDs as false
	for objective_id in ObjectiveEnums.ObjectiveID.values():
		completed_objectives[objective_id] = false

func is_objective_completed(objective_id: ObjectiveEnums.ObjectiveID) -> bool:
	return completed_objectives.get(objective_id, false)

func complete_objective(objective_id: ObjectiveEnums.ObjectiveID):
	completed_objectives[objective_id] = true
