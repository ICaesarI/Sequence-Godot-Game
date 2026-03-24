extends Button

var card_id: String = ""
var selected:= false

@onready var art: TextureRect = $Art

var base_pos: Vector2
var hover_tween: Tween
var select_tween: Tween

func _ready():
	base_pos = position

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
	else:
		text = id

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
	if art.texture == null:
		text = txt
		add_theme_color_override("font_color", color_txt)
		add_theme_color_override("font_hover_color", color_txt)
		add_theme_color_override("font_focus_color", color_txt)

func _on_mouse_entered():
	if selected: return

	_kill_tweens()
	z_index = 10

	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	hover_tween.tween_property(self, "position", base_pos + Vector2(0, -25), 0.15)
	hover_tween.parallel().tween_property(self, "rotation", deg_to_rad(randf_range(-4, 4)), 0.15)
	hover_tween.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), 0.15)

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

func set_selected(state: bool):
	selected = state
	_kill_tweens()
	
	select_tween = create_tween()

	if state:
		z_index = 20
		select_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		select_tween.tween_property(self, "position", base_pos + Vector2(0, -20), 0.2)
		select_tween.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)
		select_tween.parallel().tween_property(self, "rotation", 0.0, 0.1)
		
		var current_team = GameManager.get_current_team_id()
		var base_color = GameManager.get_team_color(current_team)
		
		var glow_color = base_color
		
		select_tween.parallel().tween_property(self, "modulate", glow_color, 0.2)
		
		select_tween.tween_callback(_start_floating_loop)
		
	else:
		z_index = 1
		select_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		
		select_tween.tween_property(self, "position", base_pos, 0.15)
		select_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.15)
		select_tween.parallel().tween_property(self, "rotation", 0.0, 0.15)
		
		select_tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.15)

func _start_floating_loop():
	if not selected: return
	
	if select_tween: select_tween.kill()
	select_tween = create_tween().set_loops()
	select_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	select_tween.tween_property(self, "position:y", base_pos.y - 25, 0.8)
	select_tween.tween_property(self, "position:y", base_pos.y - 15, 0.8)
	
