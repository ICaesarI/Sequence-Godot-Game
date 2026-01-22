extends ColorRect

func _on_mouse_entered():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	color = Color(0.2, 0.2, 0.5)
	z_index = 1

func _on_mouse_exited():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	z_index = 0
	
	if get_node("Label").text == "FREE":
		color = Color(0.15, 0.45, 0.15)
	else:
		color = Color(0.1, 0.1, 0.1)
