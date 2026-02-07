extends Button

var card_id: String = ""
var selected:= false

@onready var art: TextureRect = $Art

# --- STATE ---
var base_pos: Vector2
var hover_tween: Tween
var select_tween: Tween

func _ready():
	# Guardar posición base real cuando ya está en escena
	base_pos = position

	# Conexiones de señal seguras
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func setup(id: String):
	card_id = id
	pivot_offset = size / 2
	var tex := CardAssets.get_face(card_id)
	
	if tex:
		art.texture = tex
		text = ""   # Quitamos texto si hay imagen
	else:
		text = id

	# --- ESTILO BICYCLE BLANCO SIMPLE ---
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.WHITE
	normal.set_corner_radius_all(5)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(1, 1)

	var hover = normal.duplicate()
	hover.bg_color = Color(0.97, 0.97, 0.97)

	var pressed_style = normal.duplicate()
	pressed_style.bg_color = Color(0.93, 0.93, 0.93)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", normal)
	
	# Configurar identidad (texto de fallback)
	if "_" in id:
		var parts = id.split("_")
		var suit = parts[0]
		var value = parts[1]
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
	# Solo muestra texto si no hay textura cargada
	if art.texture == null:
		text = txt
		add_theme_color_override("font_color", color_txt)
		add_theme_color_override("font_hover_color", color_txt)
		add_theme_color_override("font_focus_color", color_txt)

# --- ANIMACIONES DE HOVER ---
func _on_mouse_entered():
	if selected: return

	_kill_tweens()
	z_index = 10

	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Pequeña subida
	hover_tween.tween_property(self, "position", base_pos + Vector2(0, -15), 0.12)
	hover_tween.parallel().tween_property(self, "rotation", deg_to_rad(randf_range(-2, 2)), 0.12)
	hover_tween.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.12)

func _on_mouse_exited():
	if selected: return

	_kill_tweens()
	z_index = 1

	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	hover_tween.tween_property(self, "position", base_pos, 0.10)
	hover_tween.parallel().tween_property(self, "rotation", 0.0, 0.10)
	hover_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.10)
	hover_tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.10)

func _kill_tweens():
	if hover_tween: hover_tween.kill()
	if select_tween: select_tween.kill()

# --- SELECCION (ANIMACIÓN DE FLOTACIÓN + BRILLO DINÁMICO) ---
func set_selected(state: bool):
	selected = state
	_kill_tweens()
	
	select_tween = create_tween()

	if state:
		z_index = 20
		select_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		# 1. Movimiento (Pop Arriba)
		select_tween.tween_property(self, "position", base_pos + Vector2(0, -30), 0.2)
		select_tween.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)
		select_tween.parallel().tween_property(self, "rotation", 0.0, 0.1)
		
		# --- CORRECCIÓN AQUÍ: USO DE SKINS DINÁMICAS ---
		var current_team = GameManager.get_current_team_id()
		var base_color = GameManager.get_team_color(current_team)
		
		# Creamos un color "Neon" derivado del color base
		var glow_color = base_color
		glow_color.v = 1.5 # Más brillante (Valor > 1.0 simula HDR/Neon)
		glow_color.s = 0.6 # Menos saturado para que parezca luz blanca teñida
		
		# Aplicamos el color dinámico al modulate
		select_tween.parallel().tween_property(self, "modulate", glow_color, 0.2)
		
		# 2. Iniciar Loop de flotación
		select_tween.tween_callback(_start_floating_loop)
		
	else:
		z_index = 1
		select_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		
		# Regreso a base
		select_tween.tween_property(self, "position", base_pos, 0.15)
		select_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.15)
		select_tween.parallel().tween_property(self, "rotation", 0.0, 0.15)
		
		# Regreso a color normal (Blanco/Neutro)
		select_tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.15)

func _start_floating_loop():
	if not selected: return
	
	if select_tween: select_tween.kill()
	select_tween = create_tween().set_loops()
	select_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Flotar suavemente
	select_tween.tween_property(self, "position:y", base_pos.y - 35, 0.8)
	select_tween.tween_property(self, "position:y", base_pos.y - 25, 0.8)
	
