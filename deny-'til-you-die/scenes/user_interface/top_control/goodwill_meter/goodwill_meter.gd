extends Control

@onready var needle : HBoxContainer = $Needle
@onready var gauge : TextureRect = $Gauge

func _ready():
	await get_tree().process_frame
	
	ManagerGoodwill.ref.goodwill_update.connect(_update_gauge)

	_update_gauge()

func _update_gauge():
	needle.pivot_offset = Vector2(size.x / 2 + 2.5, size.y)
	# Calculate the rotation angle based on goodwill_value (0-100)
	var angle = ManagerGoodwill.ref.get_resource() * 180 / 100  # 180 degrees for full range

	# Rotate the needle
	needle.rotation_degrees = angle
