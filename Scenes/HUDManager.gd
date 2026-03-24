extends PanelContainer

@onready var h_box = $Margin/HBox 

@onready var panels = {
	0: $Margin/HBox/Panel_Team0 if has_node("Margin/HBox/Panel_Team0") else $Margin/HBox.get_child(0).get_child(0),
	1: $Margin/HBox/Panel_Team1 if has_node("Margin/HBox/Panel_Team1") else $Margin/HBox.get_child(2).get_child(0),
	2: $Margin/HBox/Panel_Team2 if has_node("Margin/HBox/Panel_Team2") else $Margin/HBox.get_child(4).get_child(0)
}

const TEAM_DEFAULT_NAMES = { 0: "AZULES", 1: "ROJOS", 2: "VERDES" }

func _ready():
	self.set_as_top_level(true)
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	setup_hud_inicial()
	configurar_layout_responsive(true)

func actualizar_turno_visual(team_activo_id: int, _nombre_jugador_activo: String = ""):
	for id in panels.keys():
		var panel = panels[id]
		if not panel or not panel.get_parent().visible: continue
		
		# En lugar de usar el nombre del jugador activo para todo el mundo,
		# Extraemos el nombre correspondiente al equipo que este panel representa:
		var nombres_equipo = []
		for p in GameManager.players:
			if p.has("team") and p["team"] == id:
				nombres_equipo.append(p["name"])
		var texto_nombres = " / ".join(nombres_equipo) if nombres_equipo.size() > 0 else "ESPERANDO..."
		
		var color_base = GameManager.get_team_color(id)
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(5)
		
		var lbl_name = _get_label(panel, "Lbl_Name")
		if lbl_name:
			lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl_name.text = TEAM_DEFAULT_NAMES[id] + "\n" + texto_nombres.to_upper()
			lbl_name.clip_text = true
		
		if id == team_activo_id:
			style.bg_color = color_base
			style.border_width_bottom = 4
			style.border_color = Color.WHITE
			if lbl_name: lbl_name.add_theme_color_override("font_color", Color.WHITE)
		else:
			style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
			if lbl_name: lbl_name.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			
		panel.add_theme_stylebox_override("panel", style)
	
	configurar_layout_responsive(true)

func configurar_layout_responsive(_ignorar: bool):
	# Evitamos el error "Can't change orientation" validando el tipo
	if h_box is BoxContainer and not h_box is VBoxContainer:
		h_box.vertical = true 
	
	h_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	h_box.add_theme_constant_override("separation", 10)
	
	var ancho_fijo = 140
	self.custom_minimum_size.x = ancho_fijo
	
	for id in panels.keys():
		var p = panels[id]
		if p:
			var wrapper = p.get_parent()
			wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			
			# Aumentamos un poco el alto para que quepa el punto abajo
			wrapper.custom_minimum_size = Vector2(ancho_fijo, 85)
			p.custom_minimum_size = Vector2(ancho_fijo - 10, 80)
			
			var lbl = _get_label(p, "Lbl_Name")
			if lbl:
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lbl.custom_minimum_size = Vector2(ancho_fijo - 20, 50)

	_posicionar_en_esquina()

func _posicionar_en_esquina():
	await get_tree().process_frame
	self.reset_size()
	
	var screen_size = get_viewport_rect().size
	var escala = 0.85
	if screen_size.x < 1000: escala = 0.7
	
	self.scale = Vector2(escala, escala)
	self.pivot_offset = Vector2(self.size.x, 0)
	
	var margin = 20
	var x_final = screen_size.x - (self.size.x * escala) - margin
	self.global_position = Vector2(x_final, margin)

func actualizar_marcadores(sequences_data: Dictionary):
	for id in panels.keys():
		var panel = panels[id]
		if not panel or not panel.get_parent().visible: continue
		
		var num_sequences = sequences_data.get(id, 0)
		var color_equipo = GameManager.get_team_color(id)
		
		# Actualizamos los círculos inmediatamente
		_gestionar_puntos_secuencia(panel, num_sequences, color_equipo)
			
	configurar_layout_responsive(true)
	

func _gestionar_puntos_secuencia(panel: PanelContainer, cantidad: int, color: Color):
	# 1. Buscamos o creamos el contenedor para los círculos
	var container = panel.get_node_or_null("SequenceContainer")
	if not container:
		container = HBoxContainer.new()
		container.name = "SequenceContainer"
		container.alignment = BoxContainer.ALIGNMENT_CENTER
		# Separación entre los círculos
		container.add_theme_constant_override("separation", 6)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Bloqueamos para que no se estire y se mantenga abajo
		container.size_flags_vertical = Control.SIZE_SHRINK_END 
		
		panel.add_child(container)
		container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		container.position.y -= 5 

	# 2. Limpiamos los puntos anteriores antes de redibujar la nueva cantidad
	for child in container.get_children():
		child.queue_free()

	# 3. Creamos un círculo por cada secuencia (cantidad)
	for i in range(cantidad):
		var punto = Panel.new()
		var tamano = 12.0 # Usamos float para evitar el error de INTEGER_DIVISION
		
		# Forzamos tamaño cuadrado para evitar la forma de cápsula
		punto.custom_minimum_size = Vector2(tamano, tamano)
		
		# Evitamos que el HBoxContainer lo deforme
		punto.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		punto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var style = StyleBoxFlat.new()
		style.bg_color = color
		
		# Círculo perfecto: radio es la mitad del tamaño
		style.set_corner_radius_all(tamano / 2.0) 
		
		# Borde para que resalte
		style.set_border_width_all(1) 
		style.border_color = Color.WHITE
		style.anti_aliasing = true # Para bordes suaves
		
		punto.add_theme_stylebox_override("panel", style)
		container.add_child(punto)

func _get_label(root_node, label_name):
	return root_node.find_child(label_name, true, false)

func setup_hud_inicial():
	var total_equipos = GameManager.total_teams_in_play
	for i in range(3):
		if panels.has(i) and panels[i]:
			panels[i].get_parent().visible = (i < total_equipos)
