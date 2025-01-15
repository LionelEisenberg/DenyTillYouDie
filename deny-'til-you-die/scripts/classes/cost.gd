class_name Cost 
extends Resource

var base_cost: int
var cost_resource: GameEnums.ResourceType 
var cost_scaling: float = 1.0

func _init(base_cost : int, cost_resource : GameEnums.ResourceType, cost_scaling : float = 1):
	base_cost = base_cost
	cost_resource = cost_resource
	cost_scaling = cost_scaling

func calculate_cost(current_level: int) -> int:
	return int(base_cost * pow(cost_scaling, current_level))
