extends RichTextLabel

func _ready() -> void:
	_update_text()
	ManagerGoodwill.ref.goodwill_update.connect(_update_text)

func _update_text() -> void:
	var goodwill_amount = ManagerGoodwill.ref.get_resource()
	if goodwill_amount < 0:
		text = "[center][img]res://assets/textures/resources/goodwill_resource_negative.png[/img]  [color=red]🙁%.02f[/color][/center]" % goodwill_amount
	else:
		text = "[center][img]res://assets/textures/resources/goodwill_resource.png[/img]  [color=green]😊%.02f[/color][/center]" % goodwill_amount
