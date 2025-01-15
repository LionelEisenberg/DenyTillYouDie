extends Label

var current_objective : Objective

func _ready() -> void:
	current_objective = ManagerObjective.ref.current_objective
	_update_text()
	
	ManagerObjective.ref.objective_completed.connect(_on_objective_completed)

func _on_objective_completed(_objective : Objective) -> void:
	current_objective = ManagerObjective.ref.current_objective
	_update_text()

func _update_text() -> void:
	if current_objective == null:
		text = "No more Objectives!"
	else:
		text = current_objective.description
