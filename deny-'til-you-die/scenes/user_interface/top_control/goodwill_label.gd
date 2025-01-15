extends Label

func _ready() -> void:
	_update_text()
	ManagerGoodwill.ref.goodwill_update.connect(_update_text)

func _update_text() -> void:
	text = "Goodwill: %s" %ManagerGoodwill.ref.get_resource()
