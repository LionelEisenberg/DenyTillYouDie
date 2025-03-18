extends HBoxContainer

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var num_buttons_visible = 0
	for nav_button : Button in get_child(1).get_child(0).get_children():
		if nav_button.visible:
			num_buttons_visible += 1
	
	if num_buttons_visible > 1:
		self.visible = true
	else:
		self.visible = false
