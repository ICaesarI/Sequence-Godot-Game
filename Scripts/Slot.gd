extends ColorRect

signal slot_clicked(slot_node)

var card_id: String = ""
var occupied_by: String = ""
var highlight_tween: Tween # Variable para controlar la animación

func _ready():
	pivot_offset = custom_minimum_size / 2
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("slot_clicked", self)

func set_highlight(active: bool):
	# Si ya hay un tween corriendo, lo matamos siempre para resetear
	if highlight_tween:
		highlight_tween.kill()
	
	if active:
		highlight_tween = create_tween().set_loops()
		# Animación de pulso
		highlight_tween.tween_property(self, "self_modulate", Color(1.5, 1.5, 1.5), 0.6)
		highlight_tween.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.6)
		highlight_tween.tween_property(self, "self_modulate", Color.WHITE, 0.6)
		highlight_tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.6)
	else:
		# Reset total al estado original
		self_modulate = Color.WHITE
		scale = Vector2(1.0, 1.0)
		z_index = 1

# --- FUNCION PARA COLOCAR FICHA  ---
func colocar_ficha(color_ficha, player_id):
	occupied_by = player_id
	
	# Cambiamos el color del fondo del Slot a un gris oscuro
	color = Color(0.15, 0.15, 0.15) 
	
	var chip = Panel.new()
	chip.custom_minimum_size = Vector2(60, 60)
	chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color_ficha
	style.set_corner_radius_all(30)
	style.set_border_width_all(3) 
	style.border_color = Color.WHITE
	
	chip.add_theme_stylebox_override("panel", style)
	add_child(chip)
