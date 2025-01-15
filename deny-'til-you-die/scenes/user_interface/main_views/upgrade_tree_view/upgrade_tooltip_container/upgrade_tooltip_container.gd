class_name UpgradeTooltipContainer
extends MarginContainer

@onready var label = $PanelContainer/MarginContainer/UpgradeTooltip

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	self.position = get_global_mouse_position()
	self.position.y -= 40
