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

	# Si no conectas por el editor, conectamos aquí
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
		text = ""   # quitamos texto
	else:
		text = id

	# --- ESTILO BICYCLE BLANCO ---
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.WHITE
	normal.set_corner_radius_all(5)

	var hover = normal.duplicate()
	hover.bg_color = Color(0.97, 0.97, 0.97)

	var pressed_style = normal.duplicate()
	pressed_style.bg_color = Color(0.93, 0.93, 0.93)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", normal)
	
	_configurar_identidad(id)

func _configurar_identidad(id: String):
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
	text = txt
	add_theme_color_override("font_color", color_txt)
	add_theme_color_override("font_hover_color", color_txt)
	add_theme_color_override("font_focus_color", color_txt)

# --- ANIMACIONES DE HOVER ---
func _on_mouse_entered():
	if selected: 
		return

	_kill_hover_tween()
	z_index = 10

	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	hover_tween.tween_property(self, "position", base_pos + Vector2(0, -18), 0.12)
	hover_tween.parallel().tween_property(self, "rotation", deg_to_rad(randf_range(-2, 2)), 0.12)
	hover_tween.parallel().tween_property(self, "scale", Vector2(1.04, 1.04), 0.12)

func _on_mouse_exited():
	if selected:
		return

	_kill_hover_tween()
	z_index = 1

	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	hover_tween.tween_property(self, "position", base_pos, 0.10)
	hover_tween.parallel().tween_property(self, "rotation", 0.0, 0.10)
	hover_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.10)

	# Al terminar, lo devolvemos al control del container
	hover_tween.finished.connect(func ():
		set_as_top_level(false)
	)
func _kill_hover_tween():
	if hover_tween:
		hover_tween.kill()
		hover_tween = null

# --- Seleccion ---
func set_selected(state: bool):
	selected = state
	_kill_hover_tween()

	if select_tween:
		select_tween.kill()
		select_tween = null

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(5)
	
	if state:
		style.bg_color = Color(0.85, 0.90, 1.00)
		style.set_border_width_all(4)
		style.border_color = Color.GOLD

		z_index = 20

		select_tween = create_tween()
		select_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		select_tween.tween_property(self, "position", base_pos + Vector2(0, -22), 0.14)
		select_tween.parallel().tween_property(self, "scale", Vector2(1.10, 1.10), 0.14)
		select_tween.parallel().tween_property(self, "rotation", 0.0, 0.10)
	else:
		style.bg_color = Color.WHITE
		style.set_border_width_all(0)

		z_index = 1

		select_tween = create_tween()
		select_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		select_tween.tween_property(self, "position", base_pos, 0.12)
		select_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.12)
		select_tween.parallel().tween_property(self, "rotation", 0.0, 0.12)

	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style) 
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
