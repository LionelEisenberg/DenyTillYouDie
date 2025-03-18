extends RichTextLabel

var current_objective : Objective

func _ready() -> void:
	current_objective = ManagerObjective.ref.current_objective
	_update_text(current_objective, 0)
	
	ManagerObjective.ref.objective_completed.connect(_on_objective_completed)
	ManagerObjective.ref.objective_updated.connect(_update_text)

func _on_objective_completed(objective : Objective) -> void:
	current_objective = ManagerObjective.ref.current_objective
	_update_text(objective, 0)

func _update_text(_objective : Objective, progress : int) -> void:
	if current_objective == null:
		text = "No more Objectives!"
	else:
		text = current_objective.get_formatted_description(progress)
