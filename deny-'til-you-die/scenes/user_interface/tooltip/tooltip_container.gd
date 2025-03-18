class_name TooltipContainer
extends MarginContainer

@onready var label = $PanelContainer/MarginContainer/UpgradeTooltip
@onready var cooldown = $PanelContainer/MarginContainer/Cooldown
@onready var cooldown_label = $PanelContainer/MarginContainer/Cooldown/Label
@export var follow_mouse : bool = true

func _ready() -> void:
	set_process(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if follow_mouse:
		self.position = get_global_mouse_position()
		self.position.y -= 40
