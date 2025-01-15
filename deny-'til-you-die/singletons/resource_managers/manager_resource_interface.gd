class_name ManagerResourceInterface
extends Node

func add_resource(quantity : int) -> void :
	pass

func get_resource() -> int:
	return 0  # Default implementation, should be overridden

func can_spend(amount: int) -> bool:
	return get_resource() >= amount

func spend(amount: int) -> Error:
	if !can_spend(amount):
		return Error.FAILED
	return Error.OK
