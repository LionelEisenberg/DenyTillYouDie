class_name SignalBus
extends Node

static var ref : SignalBus

func _init() -> void:
	if not ref : ref = self
	else : queue_free()
