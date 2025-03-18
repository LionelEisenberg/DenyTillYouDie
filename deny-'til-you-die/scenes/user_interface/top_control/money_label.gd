extends RichTextLabel

func _ready() -> void:
	_update_text()
	ManagerMoney.ref.money_update.connect(_update_text)

func _update_text() -> void:
	var money_amount = ManagerMoney.ref.get_resource()
	text = "[center][img]res://assets/textures/resources/money_resource.png[/img]  [color=green]$%.02f[/color][/center]" % money_amount
