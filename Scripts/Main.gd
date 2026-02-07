extends Control

# ==============================================================================
# 1. REFERENCIAS
# ==============================================================================
@onready var main_layout = $RootMargin/MainLayout
@onready var info_panel = $RootMargin/MainLayout/InfoPanel

@onready var right_side_wrapper = $RootMargin/MainLayout/RightSideWrapper

@onready var game_zone = $RootMargin/MainLayout/RightSideWrapper/GameZone
@onready var grid = $RootMargin/MainLayout/RightSideWrapper/GameZone/BoardAspect/MarginContainer/GridContainer
@onready var hand_wrapper = $RootMargin/MainLayout/RightSideWrapper/HandWrapper
@onready var hand_panel = $RootMargin/MainLayout/RightSideWrapper/HandWrapper/HandPanel
@onready var hand_container = $RootMargin/MainLayout/RightSideWrapper/HandWrapper/HandPanel/MarginContainer/HandRow/HandContainer
@onready var discard_button = $RootMargin/MainLayout/RightSideWrapper/HandWrapper/HandPanel/MarginContainer/HandRow/DiscardButton

@onready var hud_script = info_panel 

var slot_scene = preload("res://Scenes/Slot.tscn")
var card_hand_scene = preload("res://Scenes/CardHand.tscn")
const MENU_SCENE_PATH = "res://Scenes/MainMenu.tscn"

var fichas_en_secuencia: Array = []
var carta_seleccionada_actual = null
var color_tween: Tween
var team_sequences = { 0: 0, 1: 0, 2: 0 }

# Colores fijos para slots (no dependen de skins)
const COLOR_SLOT_FREE = Color(0.2, 0.5, 0.2)
const COLOR_SLOT_NORMAL = Color(0.4, 0.4, 0.4)

# ==============================================================================
# 2. INICIALIZACIÓN
# ==============================================================================
func _ready():
	discard_button.pressed.connect(_on_discard_pressed)
	discard_button.disabled = true
	
	# Conexión Responsive
	get_tree().get_root().size_changed.connect(_on_screen_resized)

	if GameManager.players.size() == 0:
		GameManager.setup_game(2)
		
	setup_board()
	
	# Configuración inicial del HUD
	if hud_script.has_method("setup_hud_inicial"):
		hud_script.setup_hud_inicial()
	
	repartir_manos_iniciales()
	actualizar_ui_turnos()
	
	# Ajuste inicial de pantalla
	await get_tree().process_frame
	_on_screen_resized()

# ==============================================================================
# 3. RESPONSIVE DESIGN
# ==============================================================================
func _on_screen_resized():
	await get_tree().process_frame 
	if not is_inside_tree(): return
	
	var viewport_size = get_viewport_rect().size
	var is_portrait = viewport_size.y > viewport_size.x
	
	# --- A. DEFINIR ESTRUCTURA GENERAL ---
	if is_portrait:
		# MODO VERTICAL (Móvil) -> Header Arriba
		if main_layout is HBoxContainer: _cambiar_contenedor_principal(true)
		
		# --- PORCENTAJES VERTICALES ---
		# Header Info: 15% del alto total
		info_panel.size_flags_stretch_ratio = 0.15
		# Área de Juego (Tablero + Mano): 85% del alto total
		right_side_wrapper.size_flags_stretch_ratio = 0.85
		game_zone.size_flags_stretch_ratio = 0.70  # 70% Tablero
		hand_wrapper.size_flags_stretch_ratio = 0.30 # 30% Mano
	else:
		# MODO HORIZONTAL (PC) -> Sidebar Izquierda
		if main_layout is VBoxContainer: _cambiar_contenedor_principal(false)
		
		# --- PORCENTAJES HORIZONTALES ---
		# Sidebar Info: 20% del ancho total
		info_panel.size_flags_stretch_ratio = 0.20
		# Área de Juego (Tablero + Mano): 80% del ancho total
		right_side_wrapper.size_flags_stretch_ratio = 0.80
		game_zone.size_flags_stretch_ratio = 0.75  # 75% Tablero
		hand_wrapper.size_flags_stretch_ratio = 0.25 # 25% Mano

	# --- B. DEFINIR PROPORCIONES INTERNAS (TABLERO vs MANO) ---
	# Esto aplica al 'right_side_wrapper' que es siempre vertical
	
	if is_portrait:
		# En móvil, el tablero necesita más espacio proporcionalmente
		# Tablero: 75% del espacio disponible en game_wrapper
		game_zone.size_flags_stretch_ratio = 0.75
		# Mano: 25% del espacio disponible
		hand_wrapper.size_flags_stretch_ratio = 0.25
	else:
		# En PC, la mano puede ser un poco más pequeña
		# Tablero: 78%
		game_zone.size_flags_stretch_ratio = 0.78
		# Mano: 22%
		hand_wrapper.size_flags_stretch_ratio = 0.22

	# Aplicar configuración de flags para asegurar que obedezcan los ratios
	_aplicar_flags_expansion()
	
	# --- C. CALCULAR TAMAÑO DE CELDAS ---
	# Esperamos un frame para que los contenedores tomen su nuevo tamaño
	await get_tree().process_frame
	_resize_board_cells_by_container()
	

func _aplicar_flags_expansion():
	# Para que stretch_ratio funcione, las flags deben ser EXPAND_FILL
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	right_side_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_side_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	game_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _cambiar_contenedor_principal(vertical: bool):
	var nuevo_layout: BoxContainer
	if vertical: nuevo_layout = VBoxContainer.new()
	else: nuevo_layout = HBoxContainer.new()
	
	nuevo_layout.name = "MainLayout"
	nuevo_layout.add_theme_constant_override("separation", 0) # Sin espacios muertos
	
	# Intercambio estándar de hijos
	var padre = main_layout.get_parent()
	var hijos = main_layout.get_children()
	for hijo in hijos:
		main_layout.remove_child(hijo)
		nuevo_layout.add_child(hijo)
	padre.remove_child(main_layout)
	main_layout.queue_free()
	padre.add_child(nuevo_layout)
	main_layout = nuevo_layout
	padre.move_child(main_layout, 1)

func _resize_board_cells_by_container():
	# Esperar un momento para que el motor actualice la ventana
	await get_tree().process_frame

	# 1. OBTENER LA VERDAD ABSOLUTA (Tamaño de Pantalla)
	var screen_size = get_viewport_rect().size
	var is_portrait = screen_size.y > screen_size.x
	
	# 2. CALCULAR EL ESPACIO MÁXIMO PERMITIDO (Matemática Pura)
	# Aquí definimos "a mano" cuánto espacio le toca al tablero según los ratios que decidimos.
	
	var max_w_disponible
	var max_h_disponible
	
	if is_portrait:
		# MODO MÓVIL:
		# Ancho: Todo el ancho menos márgenes
		# Alto: (Alto Total - Header) * 70%
		var header_h = 110.0
		var zona_juego_h = screen_size.y - header_h
		
		max_w_disponible = screen_size.x - 40.0 # Margen lateral
		max_h_disponible = (zona_juego_h * 0.70) - 20.0 # El 70% estricto para tablero
	else:
		# MODO PC:
		# Ancho: (Ancho Total - Sidebar)
		# Alto: Alto Total * 75% (Dejamos 25% para la mano)
		var sidebar_w = 280.0
		
		max_w_disponible = (screen_size.x - sidebar_w) - 40.0
		max_h_disponible = (screen_size.y * 0.75) - 20.0 # El 75% estricto para tablero

	# Seguridad por si la pantalla es muy pequeña
	if max_w_disponible < 100 or max_h_disponible < 100: return

	# 3. CÁLCULO DEL TAMAÑO DE LA CARTA
	# Grid de 10x10
	var columnas = 10.0
	var filas = 10.0
	var card_ratio = 0.85 # Relación de aspecto
	
	# ¿Qué tamaño tendría la carta si usamos todo el ANCHO?
	var cell_w_by_width = floor(max_w_disponible / columnas)
	var cell_h_by_width = floor(cell_w_by_width / card_ratio)
	
	# ¿Qué tamaño tendría la carta si usamos todo el ALTO?
	var cell_h_by_height = floor(max_h_disponible / filas)
	var cell_w_by_height = floor(cell_h_by_height * card_ratio)
	
	# ELEGIR EL MENOR (El que cabe seguro)
	var final_w
	var final_h
	
	# Si usando el ancho nos salimos de alto, entonces estamos limitados por altura
	if (cell_h_by_width * filas) > max_h_disponible:
		final_h = cell_h_by_height
		final_w = cell_w_by_height
	else:
		final_w = cell_w_by_width
		final_h = cell_h_by_width

	# 4. APLICAR TAMAÑO (Restamos 1px para evitar redondeos que rompan el layout)
	var size_vector = Vector2(final_w - 1, final_h - 1)
	
	for slot in grid.get_children():
		slot.custom_minimum_size = size_vector
		
	# Forzar actualización
	grid.queue_sort()

# ==============================================================================
# 4. TABLERO Y TURNOS
# ==============================================================================
func setup_board():
	grid.columns = 10
	for child in grid.get_children(): child.queue_free()
	for row in BoardData.BOARD_MAP:
		for id in row:
			var new_slot = slot_scene.instantiate()
			grid.add_child(new_slot)
			new_slot.setup(id)
			new_slot.slot_clicked.connect(_on_slot_clicked)
			var base_c = COLOR_SLOT_FREE if id == "FREE" else COLOR_SLOT_NORMAL
			new_slot.set_base_color(base_c, id == "FREE")

func actualizar_ui_turnos():
	var p_data = GameManager.get_current_player_data()
	var team_id = p_data["team"]
	
	# Nombre del JUGADOR (ej: "JUGADOR 3")
	var nombre_jugador = p_data.get("name", "JUGADOR " + str(GameManager.current_player_index + 1))
	
	# Color del EQUIPO (Skin Dinámica)
	var base_color = GameManager.get_team_color(team_id)
	
	# 1. Panel Inferior (Mano)
	_animar_cambio_color_panel(base_color)
	
	# 2. Panel Superior (HUD)
	if hud_script.has_method("actualizar_turno_visual"):
		hud_script.actualizar_turno_visual(team_id, nombre_jugador)

func _animar_cambio_color_panel(target_color: Color):
	var style_box = hand_panel.get_theme_stylebox("panel")
	if not style_box is StyleBoxFlat: return

	if not style_box.resource_local_to_scene:
		style_box = style_box.duplicate()
		hand_panel.add_theme_stylebox_override("panel", style_box)
		style_box.resource_local_to_scene = true
	
	if color_tween: color_tween.kill()
	color_tween = create_tween().set_parallel(true)
	
	color_tween.tween_property(style_box, "border_color", target_color, 0.4)
	var dark_bg = target_color.darkened(0.8) 
	dark_bg.a = 0.8 
	color_tween.tween_property(style_box, "bg_color", dark_bg, 0.4)

func repartir_manos_iniciales():
	var num_players = GameManager.players.size()
	var cards_per_hand = 7 
	match num_players:
		2: cards_per_hand = 7
		3, 4: cards_per_hand = 6
		6: cards_per_hand = 5
		8, 9: cards_per_hand = 4
		10, 12: cards_per_hand = 3
	
	var needs_deal = true
	if not GameManager.players[0]["hand"].is_empty():
		needs_deal = false
		
	if needs_deal:
		for i in range(cards_per_hand):
			for p_index in range(num_players):
				GameManager.agregar_a_mano(p_index, GameManager.draw_card())

	mostrar_mano_jugador_actual()

func mostrar_mano_jugador_actual():
	for child in hand_container.get_children():
		child.queue_free()
	
	var mano_datos = GameManager.get_mano_actual()
	for id_carta in mano_datos:
		var new_card = card_hand_scene.instantiate()
		hand_container.add_child(new_card)
		new_card.setup(id_carta)
		new_card.connect_pressed(func(): gestionar_seleccion_mano(new_card))
		
	actualizar_jerarquia_visual_mano()

func gestionar_seleccion_mano(nueva_carta):
	if carta_seleccionada_actual == nueva_carta:
		carta_seleccionada_actual.set_selected(false)
		carta_seleccionada_actual = null
	else:
		if carta_seleccionada_actual:
			carta_seleccionada_actual.set_selected(false)
		carta_seleccionada_actual = nueva_carta
		carta_seleccionada_actual.set_selected(true)
	
	actualizar_jerarquia_visual_mano()
	actualizar_ayuda_visual_tablero()
	actualizar_estado_descartar()

func actualizar_jerarquia_visual_mano():
	var hay_seleccion = carta_seleccionada_actual != null
	for wrapper in hand_container.get_children():
		var btn = wrapper.get_node("CardHand") as Button
		if not btn: continue
		if not hay_seleccion or wrapper == carta_seleccionada_actual:
			btn.self_modulate = Color.WHITE
		else:
			btn.self_modulate = Color(0.55, 0.55, 0.55)

# ==============================================================================
# 5. JUGABILIDAD
# ==============================================================================
func _obtener_tipo_movimiento(slot, hand_id: String) -> String:
	if slot.card_id == "FREE": return ""
	var current_team_id = GameManager.get_current_team_id()
	var current_team_str = "team_" + str(current_team_id)
	
	if hand_id.ends_with("_J1"):
		if slot.occupied_by != "" and slot.occupied_by != current_team_str:
			if not (slot in fichas_en_secuencia):
				return "quita"
	elif hand_id.ends_with("_J2"):
		if slot.occupied_by == "":
			return "pon"
	else:
		if slot.card_id == hand_id and slot.occupied_by == "":
			return "pon"
	return ""

func _on_slot_clicked(slot):
	if not carta_seleccionada_actual: return
	
	var hand_id = carta_seleccionada_actual.get_card_id()
	var accion = _obtener_tipo_movimiento(slot, hand_id)	
	
	if accion == "pon":
		# Colocar ficha (Color dinámico)
		var current_team_id = GameManager.get_current_team_id()
		var color_equipo = GameManager.get_team_color(current_team_id)
		var mark_str = "team_" + str(current_team_id)
		slot.colocar_ficha(color_equipo, mark_str)
		
		var hubo_secuencia = verificar_secuencia(slot)
		
		if carta_seleccionada_actual:
			GameManager.eliminar_de_mano(GameManager.current_player_index, carta_seleccionada_actual.get_card_id())
			carta_seleccionada_actual = null
		robar_carta()
		
		if hubo_secuencia:
			if _check_is_game_over():
				_finalizar_partida()
				mostrar_mano_jugador_actual()
				return 
		
		GameManager.cambiar_turno()
		actualizar_ui_turnos()
		mostrar_mano_jugador_actual()
		actualizar_ayuda_visual_tablero()
		
	elif accion == "quita":
		slot.quitar_ficha()
		
		if carta_seleccionada_actual:
			GameManager.eliminar_de_mano(GameManager.current_player_index, carta_seleccionada_actual.get_card_id())
			carta_seleccionada_actual = null
		robar_carta()
		
		GameManager.cambiar_turno()
		actualizar_ui_turnos()
		mostrar_mano_jugador_actual()
		actualizar_ayuda_visual_tablero()

func robar_carta():
	var id = GameManager.draw_card()
	if id != "":
		GameManager.agregar_a_mano(GameManager.current_player_index, id)

func _on_discard_pressed():
	if not carta_seleccionada_actual: return
	if _carta_tiene_jugada_posible(carta_seleccionada_actual.get_card_id()):
		return 

	var hand_id = carta_seleccionada_actual.get_card_id()
	GameManager.eliminar_de_mano(GameManager.current_player_index, hand_id)
	
	if carta_seleccionada_actual.has_method("play_discard_anim"):
		await carta_seleccionada_actual.play_discard_anim()
	else:
		carta_seleccionada_actual.queue_free()
		await get_tree().process_frame

	carta_seleccionada_actual = null
	robar_carta() 
	
	GameManager.cambiar_turno()
	actualizar_ui_turnos()
	mostrar_mano_jugador_actual()

func actualizar_estado_descartar():
	if not carta_seleccionada_actual:
		discard_button.disabled = true
		return
	var tiene_jugada = _carta_tiene_jugada_posible(carta_seleccionada_actual.get_card_id())
	discard_button.disabled = tiene_jugada

func _carta_tiene_jugada_posible(hand_id: String) -> bool:
	for slot in grid.get_children():
		if _obtener_tipo_movimiento(slot, hand_id) != "":
			return true
	return false

func actualizar_ayuda_visual_tablero():
	for slot in grid.get_children():
		slot.set_highlight(false)
		slot.set_playable(false)
	
	if not carta_seleccionada_actual: return
	var hand_id = carta_seleccionada_actual.get_card_id()
	
	for slot in grid.get_children():
		if _obtener_tipo_movimiento(slot, hand_id) != "":
			slot.set_highlight(true)
			slot.set_playable(true)

# ==============================================================================
# 6. VICTORIA
# ==============================================================================
func _check_is_game_over() -> bool:
	var current_team = GameManager.get_current_team_id()
	var total_equipos = GameManager.total_teams_in_play
	var meta = 2 if total_equipos == 3 else 2
	return team_sequences[current_team] >= meta
	
func _finalizar_partida():
	var win_team_id = GameManager.get_current_team_id()
	var nombre_ganador = "EQUIPO " + str(win_team_id + 1)
	
	var color_ganador = GameManager.get_team_color(win_team_id)
	
	if win_team_id == 0: nombre_ganador += " (AZUL)"
	elif win_team_id == 1: nombre_ganador += " (ROJO)"
	else: nombre_ganador += " (VERDE)"
	
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_button.disabled = true
	
	mostrar_popup_victoria(nombre_ganador, color_ganador)

func verificar_secuencia(slot_central) -> bool:
	var encontro_algo = false
	var direcciones = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	var centro = _get_slot_coords(slot_central)
	var id_dueno = slot_central.occupied_by
	
	for dir in direcciones:
		var linea: Array = [slot_central]
		for d in [dir, -dir]:
			var pos = centro + d
			while _pos_valida(pos):
				var s = _get_slot_at(pos)
				if s.occupied_by == id_dueno or s.card_id == "FREE":
					if d == dir: linea.append(s)
					else: linea.insert(0, s)
					pos += d
				else:
					break
		
		if linea.size() >= 5:
			for i in range(linea.size() - 4):
				var bloque = linea.slice(i, i + 5)
				if _procesar_secuencia_encontrada(bloque):
					encontro_algo = true
	
	return encontro_algo

func _procesar_secuencia_encontrada(slots) -> bool:
	var fichas_reutilizadas_count = 0
	for s in slots:
		if s in fichas_en_secuencia:
			fichas_reutilizadas_count += 1
	
	if fichas_reutilizadas_count > 1: return false
	
	var current_team = GameManager.get_current_team_id()
	team_sequences[current_team] += 1
	
	for s in slots:
		if not s in fichas_en_secuencia:
			fichas_en_secuencia.append(s)
	
	if not _check_is_game_over():
		var color_del_equipo = GameManager.get_team_color(current_team)
		
		# Actualizar marcadores en HUD
		hud_script.actualizar_marcadores(team_sequences)
		
		mostrar_popup_sequence(color_del_equipo)
	
	var delay_step = 0.1
	var current_delay = 0.0
	for s in slots:
		if s.has_method("play_sequence_anim"):
			s.play_sequence_anim(current_delay)
			current_delay += delay_step
			
	return true

# ==============================================================================
# 7. POPUPS Y HELPERS
# ==============================================================================
func mostrar_popup_victoria(nombre_ganador: String, color_equipo: Color):
	var layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	
	var center_box = VBoxContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(center_box)
	
	var lbl_victoria = Label.new()
	lbl_victoria.text = "¡VICTORIA!"
	lbl_victoria.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_victoria.add_theme_font_size_override("font_size", 130)
	lbl_victoria.add_theme_color_override("font_color", color_equipo)
	lbl_victoria.add_theme_constant_override("outline_size", 30)
	lbl_victoria.add_theme_color_override("font_outline_color", Color.BLACK)
	center_box.add_child(lbl_victoria)
	
	var lbl_equipo = Label.new()
	lbl_equipo.text = nombre_ganador
	lbl_equipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_equipo.add_theme_font_size_override("font_size", 40)
	lbl_equipo.add_theme_color_override("font_color", Color.WHITE)
	center_box.add_child(lbl_equipo)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	center_box.add_child(spacer)
	
	var btn = Button.new()
	btn.text = "VOLVER AL MENÚ"
	btn.add_theme_font_size_override("font_size", 28)
	btn.custom_minimum_size = Vector2(300, 70)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER 
	
	var style_btn = StyleBoxFlat.new()
	style_btn.bg_color = color_equipo.darkened(0.2)
	style_btn.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style_btn)
	btn.add_theme_stylebox_override("hover", style_btn)
	btn.add_theme_stylebox_override("pressed", style_btn)
	center_box.add_child(btn)
	
	center_box.modulate.a = 0 
	await get_tree().process_frame
	center_box.pivot_offset = center_box.size / 2
	center_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_box.scale = Vector2.ZERO
	center_box.modulate.a = 1.0
	
	var t = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(center_box, "scale", Vector2.ONE, 0.7)
	
	btn.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE_PATH))

func mostrar_popup_sequence(color_equipo: Color):
	var popup := Label.new()
	popup.text = "SEQUENCE!"
	popup.add_theme_font_size_override("font_size", 120)
	popup.add_theme_color_override("font_color", color_equipo)
	popup.add_theme_constant_override("outline_size", 25)
	popup.add_theme_color_override("font_outline_color", Color.BLACK)
	popup.add_theme_constant_override("shadow_offset_x", 10)
	popup.add_theme_constant_override("shadow_offset_y", 10)
	popup.add_theme_color_override("font_shadow_color", color_equipo.darkened(0.5))

	add_child(popup)
	popup.top_level = true 
	popup.z_index = 100 
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	await get_tree().process_frame
	popup.pivot_offset = popup.size / 2
	
	popup.scale = Vector2.ZERO
	var t = create_tween().set_parallel(false)
	t.tween_property(popup, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.0)
	t.tween_property(popup, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(popup, "modulate:a", 0.0, 0.3)
	t.finished.connect(popup.queue_free)

func _get_slot_coords(slot) -> Vector2i:
	var idx = slot.get_index()
	return Vector2i(idx % 10, idx / 10)

func _get_slot_at(pos: Vector2i):
	return grid.get_child(pos.y * 10 + pos.x)

func _pos_valida(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 10 and pos.y >= 0 and pos.y < 10
