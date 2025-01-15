extends Label

func _ready() -> void:
	_update_text()
	ManagerMoney.ref.money_update.connect(_update_text)

func _update_text() -> void:
	text = "Money: %s" %ManagerMoney.ref.get_resource()
