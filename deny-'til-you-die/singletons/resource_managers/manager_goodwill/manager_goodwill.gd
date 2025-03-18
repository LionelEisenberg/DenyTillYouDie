class_name ManagerGoodwill
extends ManagerResourceInterface

static var ref : ManagerGoodwill

signal goodwill_added(quantity : float)
signal goodwill_spent(quantity : float)
signal goodwill_update

func _init() -> void:
	if not ref : ref = self
	else : queue_free()
	

@onready var save_game_data : SaveGameData = Game.ref.save_game_data

func get_resource() -> float:
	return save_game_data.resource_data.goodwill

func add_resource(quantity : float) -> void :
	if quantity <= 0: return
	save_game_data.resource_data.goodwill += quantity
	
	goodwill_added.emit(quantity)
	goodwill_update.emit()

func can_spend(quantity : float) -> bool:
	if quantity <= 0 : 
		return save_game_data.resource_data.goodwill
	return save_game_data.resource_data.goodwill - quantity >= - save_game_data.resource_data.goodwill_max

func spend(quantity : float) -> Error :
	if quantity < 0 : return Error.FAILED
	
	if not can_spend(quantity) : return Error.FAILED
	
	save_game_data.resource_data.goodwill -= quantity
	goodwill_spent.emit(quantity)
	goodwill_update.emit()
	
	return Error.OK
