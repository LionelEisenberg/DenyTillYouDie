class_name ManagerGoodwill
extends ManagerResourceInterface

static var ref : ManagerGoodwill

signal goodwill_added(quantity : int)
signal goodwill_spent(quantity : int)
signal goodwill_update

func _init() -> void:
	if not ref : ref = self
	else : queue_free()
	

@onready var save_game_data : SaveGameData = Game.ref.save_game_data

func get_resource() -> int:
	return save_game_data.resource_data.goodwill

func add_resource(quantity : int) -> void :
	if quantity <= 0: return
	save_game_data.resource_data.goodwill += quantity
	
	goodwill_added.emit(quantity)
	goodwill_update.emit()

func can_spend(quantity : int) -> bool:
	if quantity <= 0 : return false
	return quantity <= save_game_data.resource_data.goodwill

func spend(quantity : int) -> Error :
	if quantity < 0 : return Error.FAILED
	
	if quantity > save_game_data.resource_data.goodwill : return Error.FAILED
	
	save_game_data.resource_data.goodwill -= quantity
	goodwill_spent.emit(quantity)
	goodwill_update.emit()
	
	return Error.OK
