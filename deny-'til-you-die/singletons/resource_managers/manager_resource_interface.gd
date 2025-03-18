class_name ManagerResourceInterface
extends Node

func add_resource(_quantity : float) -> void :
	pass

func get_resource() -> float:
	return 0  # Default implementation, should be overridden

func can_spend(_amount: float) -> bool:
	return false

func spend(_amount: float) -> Error:
	return Error.OK
