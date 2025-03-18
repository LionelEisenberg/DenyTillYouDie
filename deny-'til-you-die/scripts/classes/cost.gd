class_name Cost 
extends Resource

var base_cost: int
var cost_resource: GameEnums.ResourceType 
var cost_scaling: float = 1.0

func _init(_base_cost : int, _cost_resource : GameEnums.ResourceType, _cost_scaling : float = 1):
	base_cost = _base_cost
	cost_resource = _cost_resource
	cost_scaling = _cost_scaling

func calculate_cost(current_level: int) -> int:
	return int(base_cost * pow(cost_scaling, current_level))
