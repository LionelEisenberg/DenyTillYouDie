extends Control
var dragging = false
var drag_start_pos = Vector2.ZERO


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start_pos = get_local_mouse_position()
			else:
				dragging = false

	if event is InputEventMouseMotion and dragging:
		var offset = get_local_mouse_position() - drag_start_pos
		global_position += offset
		drag_start_pos = get_local_mouse_position()
