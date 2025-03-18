class_name ManagerMoney
extends ManagerResourceInterface

static var ref : ManagerMoney

signal money_added(quantity : float)
signal money_spent(quantity : float)
signal money_update

func _init() -> void:
	if not ref : ref = self
	else : queue_free()

@onready var save_game_data : SaveGameData = Game.ref.save_game_data

func get_resource() -> float:
	return save_game_data.resource_data.money

func add_resource(quantity : float) -> void :
	if quantity <= 0: return
	save_game_data.resource_data.money += quantity
	
	money_added.emit(quantity)
	money_update.emit()

func can_spend(quantity : float) -> bool:
	if quantity < 0 : return false
	return quantity <= save_game_data.resource_data.money

func spend(quantity : float) -> Error :
	if quantity < 0 : return Error.FAILED
	
	if quantity > save_game_data.resource_data.money : return Error.FAILED
	
	save_game_data.resource_data.money -= quantity
	money_spent.emit(quantity)
	money_update.emit()
	
	return Error.OK
