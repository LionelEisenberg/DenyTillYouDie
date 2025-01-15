extends Control

@onready var timer : Timer = %PopupTimer

@onready var label : RichTextLabel = %PopupLabel
@onready var close_button : TextureButton = %PopupCloseButton

func _ready() -> void:
	timer.timeout.connect(_close_popup)
	timer.wait_time = 10
	timer.start()
	
	close_button.pressed.connect(_close_popup)

func _close_popup() -> void:
	timer.stop()
	self.get_parent().remove_child(self)
	self.queue_free()

func set_popup_text(text : String) -> void:
	if label == null: label = %PopupLabel
	label.text = text
