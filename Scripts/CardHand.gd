extends Button

var card_id: String = ""

func setup(id: String):
	card_id = id
	# El pivote en el centro permite que la animación de escala se vea bien
	pivot_offset = Vector2(45, 65) 
	
	# --- ESTILO BICYCLE BLANCO ---
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(5)
	
	# Aplicamos blanco a todos los estados para evitar el gris de Godot
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
	
	_configurar_identidad(id)

func _configurar_identidad(id: String):
	if "_" in id:
		var parts = id.split("_")
		var suit = parts[0]
		var value = parts[1]
		
		# CORRECCIÓN LÍNEA 41: Comparación correcta de palos
		var es_rojo = (suit == "H" or suit == "D")
		var color_texto = Color.DARK_RED if es_rojo else Color.BLACK
		
		if value == "J1":
			actualizar_ui("J (1 Ojo)", Color.DARK_RED)
		elif value == "J2":
			actualizar_ui("J (2 Ojos)", Color.DARK_BLUE)
		else:
			actualizar_ui(value, color_texto)
	else:
		actualizar_ui(id, Color.DARK_GREEN)

func actualizar_ui(txt: String, color_txt: Color):
	text = txt
	add_theme_color_override("font_color", color_txt)
	add_theme_color_override("font_hover_color", color_txt)
	add_theme_color_override("font_focus_color", color_txt)

# --- ANIMACIONES DE HOVER ---
func _on_mouse_entered():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	z_index = 5

func _on_mouse_exited():
	# Solo vuelve al tamaño original si no está seleccionada
	if self.modulate != Color(0.8, 0.9, 1.0): 
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
		z_index = 1

func set_selected(state: bool):
	var style = get_theme_stylebox("normal").duplicate()
	
	if state:
		style.bg_color = Color(0.85, 0.9, 1.0) # Azul selección
		# CORRECCIÓN: Usar el método set_ en lugar de asignación directa
		style.set_border_width_all(4) 
		style.border_color = Color.GOLD
		scale = Vector2(1.1, 1.1)
		z_index = 10
	else:
		style.bg_color = Color.WHITE
		# CORRECCIÓN: Poner a 0 para quitar el borde
		style.set_border_width_all(0)
		scale = Vector2(1.0, 1.0)
		z_index = 1
	
	add_theme_stylebox_override("normal", style)
