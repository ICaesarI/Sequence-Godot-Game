extends ColorRect

signal slot_clicked(slot_node)

var card_id: String = ""
var occupied_by: String = ""
var highlight_tween: Tween # Variable para controlar la animación
var is_playable: bool = false

# --- Animacion  ---
var base_bg_color: Color          # Color real del slot (FREE o normal)
var base_self_modulate: Color = Color.WHITE  # Multiplicador (para flashes/hover)
var hover_tween: Tween
var base_color: Color
var seq_tween: Tween
var is_free := false



func _ready():
	pivot_offset = custom_minimum_size / 2
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Guardamos el color original del slot (el fondo)
	base_bg_color = color
	self_modulate = base_self_modulate
	base_color = color
	color = Color(base_color.r, base_color.g, base_color.b, 0.75) # alpha 0.75
	
	gui_input.connect(_on_gui_input)
	
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("slot_clicked", self)

# Por si lógica del tablero cambia el color del slot (FREE/normal),
# llama esto para mantener "base" actualizado.
func set_base_bg(new_color: Color) -> void:
	base_bg_color = new_color
	color = new_color

func set_highlight(active: bool):
	# Si ya hay un tween corriendo, lo matamos siempre para resetear
	if highlight_tween:
		highlight_tween.kill()
	
	if active:
		highlight_tween = create_tween().set_loops()
		# Animación de pulso
		highlight_tween.tween_property(self, "self_modulate", Color(1.5, 1.5, 1.5), 0.6)
		highlight_tween.tween_property(self, "self_modulate", Color.WHITE, 0.6)
	else:
		# Reset total al estado original
		self_modulate = Color.WHITE
		z_index = 1

# --- FUNCION PARA COLOCAR FICHA  ---
func colocar_ficha(color_ficha, player_id):
	occupied_by = player_id
	
	# Cambiamos el color del fondo del Slot a un gris oscuro
	color = Color(0.15, 0.15, 0.15, 0.85)
	
	var chip = Panel.new()
	chip.custom_minimum_size = Vector2(60, 60)
	chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	chip.position = -chip.custom_minimum_size / 2
	
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	
	var style = StyleBoxFlat.new()
	style.bg_color = color_ficha
	style.set_corner_radius_all(30)
	style.set_border_width_all(3) 
	style.border_color = Color.WHITE
	
	chip.add_theme_stylebox_override("panel", style)
	add_child(chip)
	
	# Spawn + rebote
	chip.scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(chip, "scale", Vector2.ONE, 0.25)

	# Flash (usamos self_modulate, NO el color base)
	self_modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(self, "self_modulate", Color.WHITE, 0.15)

func set_playable(state: bool) -> void:
	is_playable = state


# --- ANIMACION ---
func _on_mouse_entered():
	_kill_hover_tween()

	# Si NO es jugable, hover muy leve (o nada)
	if not is_playable:
		z_index = 2
		hover_tween = create_tween()
		hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		hover_tween.tween_property(self, "self_modulate", Color(1.05, 1.05, 1.05), 0.08)
		return

	# Si es jugable, hover fuerte
	z_index = 10
	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	hover_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.15)
	hover_tween.parallel().tween_property(self, "self_modulate", Color(1.2, 1.2, 1.2), 0.10)


func _on_mouse_exited():
	_kill_hover_tween()

	z_index = 1
	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	hover_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.10)

func play_sequence_anim() -> void:
	# Evita que se acumulen animaciones
	if seq_tween:
		seq_tween.kill()
		seq_tween = null

	# Subimos prioridad visual momentánea
	z_index = 20

	seq_tween = create_tween()
	seq_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Pulso rápido
	seq_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12)
	seq_tween.parallel().tween_property(self, "self_modulate", Color(1.25, 1.25, 1.25), 0.10)

	seq_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	seq_tween.tween_property(self, "scale", Vector2.ONE, 0.16)
	seq_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.14)

	# Regresa el z_index
	seq_tween.finished.connect(func():
		z_index = 1
	)
	
# --- colores base ---
func set_base_color(c: Color, free := false) -> void:
	base_color = c
	is_free = free
	color = c
	
# --- colores base ---
func restore_base() -> void:
	color = base_color
	self_modulate = Color.WHITE
	scale = Vector2.ONE


func _kill_hover_tween():
	if hover_tween:
		hover_tween.kill()
		hover_tween = null
