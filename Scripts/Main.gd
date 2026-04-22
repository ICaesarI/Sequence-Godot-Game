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
	# 1. Conexiones de botones y sistema (ESTO LO HACEN TODOS)
	discard_button.pressed.connect(_on_discard_pressed)
	discard_button.disabled = true
	get_tree().get_root().size_changed.connect(_on_screen_resized)
	
	# 2. Configuración del Fondo (ESTO LO HACEN TODOS)
	if GameManager.has_signal("fondo_cambiado"):
		if not GameManager.fondo_cambiado.is_connected(_actualizar_fondo_tablero):
			GameManager.fondo_cambiado.connect(_actualizar_fondo_tablero)
	
	if not GameManager.state_changed.is_connected(_on_game_state_changed):
		GameManager.state_changed.connect(_on_game_state_changed)
		
	if GameManager.background_texture_path != "":
		_actualizar_fondo_tablero(GameManager.background_texture_path)

	# 3. Inicialización Controlada (AQUÍ ESTÁ EL CAMBIO)
	if not multiplayer.has_multiplayer_peer():
		# MODO LOCAL: Si no hay red, iniciamos como siempre
		if GameManager.players.size() == 0:
			GameManager.setup_game(2)
		iniciar_flujo_partida()
	else:
		# MODO RED: No llamamos a setup_game. 
		# Esperamos a que MultiplayerManager llame a preparar_partida_red
		print("Main: Esperando a que el Servidor sincronice la partida...")
		# Conectamos una señal o esperamos un pequeño tiempo para iniciar visualmente
		await get_tree().create_timer(0.5).timeout
		iniciar_flujo_partida()

	# 4. Ajuste final de interfaz visual tipo Photo Roulette
	_setup_photo_roulette_game_ui()
	_on_screen_resized()

func iniciar_flujo_partida():
	setup_board()
	if hud_script.has_method("setup_hud_inicial"):
		hud_script.setup_hud_inicial()
	
	# Solo repartimos manos si somos el Host o si es local
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		repartir_manos_iniciales()
	
	actualizar_ui_turnos()

func _on_game_state_changed(new_state):
	if new_state == GameManager.GameState.PLAYER_TURN:
		actualizar_ui_turnos()
		actualizar_ayuda_visual_tablero()
		
		# CRÍTICO: En modo local (u online si es mi turno), refrescar la mano real!
		# Esto evita el bug donde se veían cartas del jugador anterior y se duplicaban al robar.
		var p_data = GameManager.get_current_player_data()
		if not multiplayer.has_multiplayer_peer() or p_data.net_id == multiplayer.get_unique_id():
			mostrar_mano_jugador_actual()

func _actualizar_fondo_tablero(ruta: String):
	if ruta == "": 
		return
	
	# Buscamos específicamente el TextureRect que es hijo de Background
	var bg_node = find_child("TextureRect", true, false)
	
	if bg_node:
		var tex = load(ruta)
		if tex:
			bg_node.texture = tex
			bg_node.stretch_mode = TextureRect.STRETCH_TILE 
			# Estilo alfombra
			
			# ASEGURAR VISIBILIDAD:
			bg_node.show() 
			# Por si estaba oculto
			
			# Si el nodo "Background" tiene un CanvasItem, forzamos que esté detrás de todo
			if bg_node.get_parent() is Control:
				bg_node.get_parent().z_index = -1 
			
			print("DEBUG: Fondo cambiado a: ", ruta)
		else:
			print("DEBUG ERROR: No se pudo cargar la imagen en: ", ruta)
	else:
		print("DEBUG ERROR: ¡No se encontró el nodo TextureRect! Revisa el nombre en el editor.")

func _setup_photo_roulette_game_ui():
	var f_bold = load("res://Assets/FuentesTexto/PixelOperator-Bold.ttf")
	
	# 1. Panel de Mono estilo Glassmorphism
	if hand_panel:
		var glass = StyleBoxFlat.new()
		glass.bg_color = Color(0.05, 0.05, 0.05, 0.90)
		glass.corner_radius_top_left = 35
		glass.corner_radius_top_right = 35
		glass.border_width_top = 4
		glass.border_color = Color.TRANSPARENT 
		hand_panel.add_theme_stylebox_override("panel", glass)
		
	# 2. Botón Discard píldora
	if discard_button:
		var pill_red = StyleBoxFlat.new()
		pill_red.bg_color = Color("#e63946")
		pill_red.set_corner_radius_all(50)
		
		var pill_red_hover = pill_red.duplicate()
		pill_red_hover.bg_color = Color("#f05a66")
		
		var pill_red_pressed = pill_red.duplicate()
		pill_red_pressed.bg_color = Color("#bc2732")
		
		var pill_disabled = pill_red.duplicate()
		pill_disabled.bg_color = Color(0.3, 0.3, 0.3, 0.5)
		
		discard_button.add_theme_stylebox_override("normal", pill_red)
		discard_button.add_theme_stylebox_override("hover", pill_red_hover)
		discard_button.add_theme_stylebox_override("pressed", pill_red_pressed)
		discard_button.add_theme_stylebox_override("disabled", pill_disabled)
		if f_bold: discard_button.add_theme_font_override("font", f_bold)
		discard_button.add_theme_font_size_override("font_size", 28)
		discard_button.add_theme_color_override("font_color", Color.WHITE)
		discard_button.custom_minimum_size = Vector2(200, 50)
		
	# 3. Base del Tablero oscuro semi-transparente
	if grid and grid.get_parent() is MarginContainer:
		var aspect = grid.get_parent().get_parent()
		if aspect and aspect.name == "BoardAspect":
			var board_bg = StyleBoxFlat.new()
			board_bg.bg_color = Color(0, 0, 0, 0.45)
			board_bg.set_corner_radius_all(15)
			board_bg.content_margin_left = 15
			board_bg.content_margin_right = 15
			board_bg.content_margin_top = 15
			board_bg.content_margin_bottom = 15
			
			var p = PanelContainer.new()
			p.add_theme_stylebox_override("panel", board_bg)
			
			# Envolvemos el grid y no al AspectRatioContainer para que abrace 
			# justa y únicamente a las cartas evitando que crezca de más
			var m_container = grid.get_parent()
			m_container.remove_child(grid)
			p.add_child(grid)
			m_container.add_child(p)
			
			grid.add_theme_constant_override("h_separation", 3)
			grid.add_theme_constant_override("v_separation", 3)

	
# ==============================================================================
# 3. RESPONSIVE DESIGN
# ==============================================================================
func _on_screen_resized():
	await get_tree().process_frame 
	if not is_inside_tree(): return
	
	var viewport_size = get_viewport_rect().size
	var is_portrait = viewport_size.y > viewport_size.x
	
	# --- 1. CONFIGURACIÓN DEL HUD (FLOTANTE) ---
	# Forzamos que sea Top Level para que no empuje al tablero
	info_panel.set_as_top_level(true)
	
	# Decidimos si el HUD se apila vertical u horizontal internamente
	var modo_columna = is_portrait or viewport_size.x < 1000
	info_panel.configurar_layout_responsive(modo_columna)
	
	# --- 2. POSICIONAMIENTO DEL HUD ---
	await get_tree().process_frame
	info_panel.reset_size()
	
	var escala = 0.7 if modo_columna else 0.85
	info_panel.scale = Vector2(escala, escala)
	info_panel.pivot_offset = Vector2(info_panel.size.x, 0)
	
	var margin = 15
	var final_x = viewport_size.x - (info_panel.size.x * escala) - margin
	info_panel.global_position = Vector2(final_x, margin)

	# --- 3. CONFIGURACIÓN DEL TABLERO (OCUPAR TODA LA PANTALLA) ---
	# Como el info_panel ya no "empuja", el right_side_wrapper (o game_zone) 
	# ahora debe expandirse al 100% del espacio disponible.
	
	# Forzamos que el contenedor del juego use todo el espacio
	right_side_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_side_wrapper.size_flags_stretch_ratio = 1.0 
	
	if is_portrait:
		# En móvil: Tablero 75%, Mano 25% del alto
		game_zone.size_flags_stretch_ratio = 0.75
		hand_wrapper.size_flags_stretch_ratio = 0.25
	else:
		# En PC: Tablero 78%, Mano 22% del alto
		game_zone.size_flags_stretch_ratio = 0.78
		hand_wrapper.size_flags_stretch_ratio = 0.22

	# --- 4. ACTUALIZAR CELDAS ---
	_aplicar_flags_expansion()
	await get_tree().process_frame
	_resize_board_cells_by_container()

func _aplicar_flags_expansion():
	# Para que stretch_ratio funcione, las flags deben ser EXPAND_FILL
	info_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	info_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	right_side_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_side_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	game_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Restringir la mano en PC para no solapar botones de los lados
	var screen_size = get_viewport_rect().size
	if screen_size.x > screen_size.y: # Es Landscape (PC)
		hand_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hand_wrapper.custom_minimum_size.x = min(screen_size.x * 0.75, 1200)
	else:
		hand_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hand_wrapper.custom_minimum_size.x = 0
		
	hand_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _posicionar_hud_flotante(hud_node: Control, vertical: bool):
	var screen_size = get_viewport_rect().size
	
	# 1. Definimos un ancho relativo (ej: 40% de la pantalla en PC, 80% en móvil)
	var factor_ancho = 0.35 if not vertical else 0.8
	var ancho_hud = screen_size.x * factor_ancho
	
	hud_node.set_as_top_level(true)
	hud_node.anchor_left = 1.0
	hud_node.anchor_right = 1.0
	hud_node.anchor_top = 0.0
	hud_node.anchor_bottom = 0.0
	
	# 2. Aplicamos el tamaño calculado
	hud_node.offset_left = -ancho_hud - 30 # 30px de margen derecho
	hud_node.offset_right = -30
	hud_node.offset_top = 30 # Margen superior
	
	# 3. Escalado Dinámico
	var base_width = 1280.0
	var scale_factor = clamp(screen_size.x / base_width, 0.7, 1.2)
	hud_node.scale = Vector2(scale_factor, scale_factor)
	
	# Importante: Ajustar el pivote a la derecha para que escale hacia adentro
	hud_node.pivot_offset = Vector2(ancho_hud, 0)

func _cambiar_contenedor_principal(vertical: bool):
	var nuevo_layout: BoxContainer
	if vertical: nuevo_layout = VBoxContainer.new()
	else: nuevo_layout = HBoxContainer.new()
	
	nuevo_layout.name = "MainLayout"
	nuevo_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) 
	# Que ocupe todo
	nuevo_layout.add_theme_constant_override("separation", 0)
	
	var padre = main_layout.get_parent()
	var hijos = main_layout.get_children()
	
	for hijo in hijos:
		main_layout.remove_child(hijo)
		
		# SI EL HIJO ES EL PANEL DE JUGADORES (Cámbiale el nombre en el editor si es necesario)
		if hijo.name == "InfoPanel" or hijo.name == "PanelJugadores":
			# Lo volvemos flotante
			hijo.set_as_top_level(true) 
			padre.add_child(hijo) # Lo movemos al padre directo, fuera del MainLayout
			_posicionar_hud_flotante(hijo, vertical)
		else:
			# El resto (Tablero, Mano) se quedan en el layout normal
			nuevo_layout.add_child(hijo)
			# Aseguramos que el tablero intente usar todo el espacio ahora que el HUD no estorba
			if hijo.name == "TableroContainer": # Ajusta al nombre de tu nodo tablero
				hijo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hijo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
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
	var es_mi_turno = true
	if multiplayer.has_multiplayer_peer():
		es_mi_turno = (p_data.net_id == multiplayer.get_unique_id())
		
	if es_mi_turno:
		_animar_cambio_color_panel(base_color)
	else:
		_animar_cambio_color_panel(Color(0.2, 0.2, 0.2))
	
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
	
	# Usamos un color base fijo translúcido para que no se arruine el efecto Glass
	var base_glass = Color(0.05, 0.05, 0.05, 0.90)
	
	if target_color == Color(0.2, 0.2, 0.2):
		# No es mi turno
		color_tween.tween_property(style_box, "border_color", Color.TRANSPARENT, 0.4)
		color_tween.tween_property(style_box, "bg_color", base_glass, 0.4)
	else:
		# Es mi turno: ilumina sutilmente el borde superior y tienta MUY poco el cristal
		color_tween.tween_property(style_box, "border_color", target_color, 0.4)
		var sutil = target_color
		sutil.a = 0.05
		var mix = base_glass.blend(sutil)
		color_tween.tween_property(style_box, "bg_color", mix, 0.4)

func repartir_manos_iniciales():
	# 1. Si ya hay cartas, no repartimos (evita duplicados al recargar)
	if not GameManager.get_mano_actual().is_empty():
		mostrar_mano_jugador_actual()
		return

	# 2. Solo el Servidor (o el modo Local) decide qué cartas salen
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var num_players = GameManager.players.size()
		var cards_per_hand = 7 
		
		match num_players:
			2: cards_per_hand = 7
			3, 4: cards_per_hand = 6
			6: cards_per_hand = 5
			8, 9: cards_per_hand = 4
			10, 12: cards_per_hand = 3
		
		for i in range(cards_per_hand):
			for p_index in range(num_players):
				var carta = GameManager.draw_card()
				
				if not multiplayer.has_multiplayer_peer():
					# MODO LOCAL: Agregamos directo
					GameManager.agregar_a_mano(p_index, carta)
				else:
					# MODO RED: El servidor le avisa a todos quién recibe qué
					# Usamos 'call_local' para que el Host también ejecute la función
					sincronizar_carta_repartida.rpc(p_index, carta)

	# 3. Actualizamos la vista
	mostrar_mano_jugador_actual()

@rpc("authority", "reliable", "call_local")
func sincronizar_carta_repartida(p_index: int, card_id: String):
	GameManager.agregar_a_mano(p_index, card_id)
	# Si es mi propia mano la que cambió, refresco mi UI
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
	# 1. Validaciones de turno y estado
	if GameManager.current_state != GameManager.GameState.PLAYER_TURN:
		return
	if not carta_seleccionada_actual: 
		return

	# 2. VALIDACIÓN DE RED: ¿Soy yo el que tiene el turno?
	if multiplayer.has_multiplayer_peer():
		var datos_turno = GameManager.get_current_player_data()
		if datos_turno.net_id != multiplayer.get_unique_id():
			print("No es tu turno. Espera a: ", datos_turno.name)
			return

	# 3. Identificamos la jugada
	var hand_id = carta_seleccionada_actual.get_card_id()
	var accion = _obtener_tipo_movimiento(slot, hand_id)	
	
	if accion == "pon":
		# En lugar de ejecutar local, llamamos al RPC
		var slot_index = slot.get_index()
		ejecutar_jugada_sincronizada.rpc(slot_index, hand_id)
	elif accion == "quita":
		var slot_index = slot.get_index()
		ejecutar_quita_sincronizada.rpc(slot_index, hand_id)

@rpc("any_peer", "call_local", "reliable")
func ejecutar_quita_sincronizada(slot_index: int, card_id_usada: String):
	GameManager.change_state(GameManager.GameState.ANIMATING)
	
	var slot = grid.get_child(slot_index)
	
	slot.quitar_ficha()
	
	var es_mi_jugada = false
	if not multiplayer.has_multiplayer_peer():
		es_mi_jugada = true
	else:
		es_mi_jugada = (multiplayer.get_unique_id() == multiplayer.get_remote_sender_id() or (multiplayer.is_server() and multiplayer.get_remote_sender_id() == 0))
		
	if es_mi_jugada:
		var size_antes = GameManager.get_mano_actual().size()
		GameManager.eliminar_de_mano(GameManager.current_player_index, card_id_usada)
		var size_despues = GameManager.get_mano_actual().size()
		
		carta_seleccionada_actual = null
		
		if size_despues < size_antes:
			robar_carta()
		else:
			print("Bug Evitado: Intento de jugar carta ajena interceptado.")
			
		mostrar_mano_jugador_actual()

	if multiplayer.is_server():
		GameManager.cambiar_turno()

@rpc("any_peer", "call_local", "reliable")
func ejecutar_jugada_sincronizada(slot_index: int, card_id_usada: String):
	# 1. Bloqueamos el estado para evitar clics dobles durante la animación
	GameManager.change_state(GameManager.GameState.ANIMATING)
	
	var slot = grid.get_child(slot_index)
	var current_team_id = GameManager.get_current_team_id()
	var color_equipo = GameManager.get_team_color(current_team_id)
	var mark_str = "team_" + str(current_team_id)
	
	# 2. Colocamos la ficha visual en TODOS los peers
	slot.colocar_ficha(color_equipo, mark_str)
	
	# 3. Verificamos secuencia (Importante: todos deben saber si alguien ganó)
	var hubo_secuencia = verificar_secuencia(slot)
	
	# 4. Cada uno limpia su propia mano y roba (si es su turno)
	var es_mi_jugada = false
	if not multiplayer.has_multiplayer_peer():
		es_mi_jugada = true # Modo local, el servidor es la PC actual
	else:
		es_mi_jugada = (multiplayer.get_unique_id() == multiplayer.get_remote_sender_id() or (multiplayer.is_server() and multiplayer.get_remote_sender_id() == 0))
		
	if es_mi_jugada:
		var size_antes = GameManager.get_mano_actual().size()
		GameManager.eliminar_de_mano(GameManager.current_player_index, card_id_usada)
		var size_despues = GameManager.get_mano_actual().size()
		
		carta_seleccionada_actual = null
		
		# Robamos SOLO si la carta física pertenecía a nuestra mano lógica
		if size_despues < size_antes:
			robar_carta()
		else:
			print("Bug Evitado: Intento de jugar carta ajena interceptado.")
			
		mostrar_mano_jugador_actual()

	# 5. Gestión de Victoria
	if hubo_secuencia:
		if _check_is_game_over():
			_finalizar_partida()
			return 
	
	# 6. Solo el servidor ordena el cambio de turno oficial
	if multiplayer.is_server():
		GameManager.cambiar_turno()
	
	# 7. Actualizar UI local se maneja ahora por la señal state_changed

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
	
	# --- SOLUCIÓN: Actualizamos el HUD SIEMPRE, incluso si es la última secuencia ---
	hud_script.actualizar_marcadores(team_sequences)
	
	var color_del_equipo = GameManager.get_team_color(current_team)
	
	# Si no ha ganado, mostramos el popup normal
	if not _check_is_game_over():
		mostrar_popup_sequence(color_del_equipo)
	
	# Animación de las fichas
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
