extends Control

# ==============================================================================
# 1. REFERENCIAS Y CONFIGURACIÓN
# ==============================================================================

# --- Referencias a Nodos UI ---
@onready var grid = $RootMargin/VBoxContainer/BoardAspect/MarginContainer/GridContainer
@onready var hand_container = $RootMargin/VBoxContainer/HandWrapper/HandPanel/MarginContainer/HandRow/HandContainer
@onready var board_aspect = $RootMargin/VBoxContainer/BoardAspect
@onready var discard_button: Button = $RootMargin/VBoxContainer/HandWrapper/HandPanel/MarginContainer/HandRow/DiscardButton
@onready var hand_panel = $RootMargin/VBoxContainer/HandWrapper/HandPanel

# --- Escenas y Rutas ---
var slot_scene = preload("res://Scenes/Slot.tscn")
var card_hand_scene = preload("res://Scenes/CardHand.tscn")
const MENU_SCENE_PATH = "res://Scenes/MainMenu.tscn"

# --- Variables de Estado del Juego ---
var fichas_en_secuencia: Array = []       # Registro de fichas que ya forman parte de una secuencia
var carta_seleccionada_actual = null      # Carta que el jugador tiene clicada en su mano
var color_tween: Tween                    # Animación del panel de turno

# Contador de secuencias POR EQUIPO (0: Azul, 1: Rojo, 2: Verde)
var team_sequences = {
	0: 0,
	1: 0,
	2: 0
}

# --- Constantes Visuales ---
const TEAM_COLORS = {
	0: Color.DODGER_BLUE, # Equipo BLUE
	1: Color.INDIAN_RED,  # Equipo RED
	2: Color.FOREST_GREEN # Equipo GREEN
}

const COLOR_SLOT_FREE = Color(0.2, 0.5, 0.2)
const COLOR_SLOT_NORMAL = Color(0.4, 0.4, 0.4)


# ==============================================================================
# 2. INICIALIZACIÓN (_READY)
# ==============================================================================
func _ready():
	# Conexiones de señales
	discard_button.pressed.connect(_on_discard_pressed)
	discard_button.disabled = true
	# Redimensionar si la ventana cambia
	get_tree().get_root().size_changed.connect(_resize_board_slots)

	# Inicializar lógica de juego si no existe (Singleton GameManager)
	if GameManager.players.size() == 0:
		GameManager.setup_game(2)
		
	# Configuración inicial
	setup_board()
	repartir_manos_iniciales()
	actualizar_ui_turnos()


# ==============================================================================
# 3. LÓGICA DEL TABLERO (SETUP Y RESPONSIVE)
# ==============================================================================
func setup_board():
	grid.columns = 10
	
	# Limpieza previa
	for child in grid.get_children():
		child.queue_free()

	# Generación de slots según el mapa de datos (BoardData)
	for row in BoardData.BOARD_MAP:
		for id in row:
			var new_slot = slot_scene.instantiate()
			grid.add_child(new_slot)
			new_slot.setup(id)
			new_slot.slot_clicked.connect(_on_slot_clicked)
			
			# Color base para diferenciar las esquinas (FREE)
			var base_c = COLOR_SLOT_FREE if id == "FREE" else COLOR_SLOT_NORMAL
			new_slot.set_base_color(base_c, id == "FREE")

	# Llamada inicial al redimensionado
	_resize_board_slots()


func _resize_board_slots():
	# Esperamos un frame para asegurar que la UI ha calculado sus márgenes
	await get_tree().process_frame
	if not is_inside_tree(): return
	
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0: return

	# --- CONFIGURACIÓN MATEMÁTICA ---
	# Reservamos espacio para la mano (mínimo 200px para que no se vea apretada)
	var altura_mano_segura = max(hand_panel.size.y, 200.0) 
	
	var available_h = viewport_size.y - altura_mano_segura - 60
	var available_w = viewport_size.x - 40
	
	if available_w <= 0 or available_h <= 0: return

	var cols := 10.0
	var rows := 10.0
	var card_ratio := 0.85 

	# Cálculo de celda base
	var cell_w = floor(available_w / cols)
	var cell_h = floor(cell_w / card_ratio)

	# Ajuste si nos pasamos de altura
	if (cell_h * rows) > available_h:
		cell_h = floor(available_h / rows)
		cell_w = floor(cell_h * card_ratio)
		
	# Límite máximo para pantallas muy grandes (evita cartas gigantes)
	var min_screen_dim = min(viewport_size.x, viewport_size.y)
	var max_dynamic_w = floor(min_screen_dim / 12.0)
	
	if cell_w > max_dynamic_w:
		cell_w = max_dynamic_w
		cell_h = floor(cell_w / card_ratio)

	# Aplicar tamaño al tablero
	for slot in grid.get_children():
		slot.custom_minimum_size = Vector2(cell_w, cell_h)
	
	# Forzar actualización de layout
	grid.queue_sort()


# ==============================================================================
# 4. GESTIÓN DE TURNOS Y MANOS
# ==============================================================================
func actualizar_ui_turnos():
	var p_data = GameManager.get_current_player_data()
	var team_id = p_data["team"]
	
	var base_color = Color.WHITE
	if TEAM_COLORS.has(team_id):
		base_color = TEAM_COLORS[team_id]
	
	_animar_cambio_color_panel(base_color)

func _animar_cambio_color_panel(target_color: Color):
	# Animación suave del color del panel inferior según el turno
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
	
	# Reglas oficiales de Sequence según número de jugadores
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
		# Conectamos la selección de carta
		new_card.connect_pressed(func(): gestionar_seleccion_mano(new_card))
		
	actualizar_jerarquia_visual_mano()

func gestionar_seleccion_mano(nueva_carta):
	# Lógica de toggle (seleccionar/deseleccionar)
	if carta_seleccionada_actual == nueva_carta:
		carta_seleccionada_actual.set_selected(false)
		carta_seleccionada_actual = null
	else:
		if carta_seleccionada_actual:
			carta_seleccionada_actual.set_selected(false)
		carta_seleccionada_actual = nueva_carta
		carta_seleccionada_actual.set_selected(true)
		print("Seleccion: ", carta_seleccionada_actual.get_card_id())
	
	# Actualizar visuales
	actualizar_jerarquia_visual_mano()
	actualizar_ayuda_visual_tablero()
	actualizar_estado_descartar()

func actualizar_jerarquia_visual_mano():
	# Oscurece las cartas no seleccionadas para resaltar la elegida
	var hay_seleccion = carta_seleccionada_actual != null
	for wrapper in hand_container.get_children():
		var btn = wrapper.get_node("CardHand") as Button
		if not btn: continue
		
		if not hay_seleccion or wrapper == carta_seleccionada_actual:
			btn.self_modulate = Color.WHITE
		else:
			btn.self_modulate = Color(0.55, 0.55, 0.55)


# ==============================================================================
# 5. LÓGICA DE JUEGO (MOVIMIENTOS)
# ==============================================================================
func _obtener_tipo_movimiento(slot, hand_id: String) -> String:
	# Retorna qué acción se puede realizar en un slot: "pon", "quita" o ""
	if slot.card_id == "FREE": return ""
	
	var current_team_id = GameManager.get_current_team_id()
	var current_team_str = "team_" + str(current_team_id)
	
	# Jota de 1 ojo (Quitar ficha oponente)
	if hand_id.ends_with("_J1"):
		if slot.occupied_by != "" and slot.occupied_by != current_team_str:
			# No se puede quitar una ficha que ya es parte de una secuencia
			if not (slot in fichas_en_secuencia):
				return "quita"
	
	# Jota de 2 ojos (Comodín)
	elif hand_id.ends_with("_J2"):
		if slot.occupied_by == "":
			return "pon"
			
	# Carta Normal
	else:
		if slot.card_id == hand_id and slot.occupied_by == "":
			return "pon"
			
	return ""

func _on_slot_clicked(slot):
	if not carta_seleccionada_actual: return
	
	var hand_id = carta_seleccionada_actual.get_card_id()
	var accion = _obtener_tipo_movimiento(slot, hand_id)	
	
	if accion == "pon":
		# 1. Colocar ficha
		var current_team_id = GameManager.get_current_team_id()
		var color_equipo = TEAM_COLORS[current_team_id]
		var mark_str = "team_" + str(current_team_id)
		slot.colocar_ficha(color_equipo, mark_str)
		
		# 2. Verificar secuencias
		var hubo_secuencia = verificar_secuencia(slot)
		
		# 3. Eliminar carta usada y robar (Limpieza de datos del jugador ACTUAL)
		if carta_seleccionada_actual:
			GameManager.eliminar_de_mano(GameManager.current_player_index, carta_seleccionada_actual.get_card_id())
			carta_seleccionada_actual = null
		robar_carta()
		
		# 4. CHEQUEO DE VICTORIA (Prioritario)
		if hubo_secuencia:
			if _check_is_game_over():
				_finalizar_partida()
				mostrar_mano_jugador_actual() # Refrescar para ver la mano final
				return # DETIENE EL JUEGO, no cambia turno
		
		# 5. Si sigue el juego, CAMBIO DE TURNO
		GameManager.cambiar_turno()
		
		# 6. ACTUALIZAR INTERFAZ (Después del cambio de turno para mostrar la mano NUEVA)
		actualizar_ui_turnos()
		mostrar_mano_jugador_actual()
		actualizar_ayuda_visual_tablero()
		
	elif accion == "quita":
		slot.quitar_ficha()
		
		# Misma lógica: Borrar -> Robar -> Cambiar -> Mostrar Nuevo
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


# ==============================================================================
# 6. DESCARTAR (DEAD CARD) Y AYUDAS
# ==============================================================================
func _on_discard_pressed():
	if not carta_seleccionada_actual: return
	
	# Doble validación: No permitir descarte si hay jugada posible
	if _carta_tiene_jugada_posible(carta_seleccionada_actual.get_card_id()):
		return 

	var hand_id = carta_seleccionada_actual.get_card_id()
	GameManager.eliminar_de_mano(GameManager.turno_actual, hand_id)
	
	# Espera breve para animación si existiera
	if carta_seleccionada_actual.has_method("play_discard_anim"):
		await carta_seleccionada_actual.play_discard_anim()
	else:
		carta_seleccionada_actual.queue_free()
		await get_tree().process_frame

	carta_seleccionada_actual = null
	robar_carta() 
	
	# Cambio de turno tras descartar
	GameManager.cambiar_turno()
	actualizar_ui_turnos()
	mostrar_mano_jugador_actual()

func actualizar_estado_descartar():
	if not carta_seleccionada_actual:
		discard_button.disabled = true
		return
	# Activar botón solo si la carta está "muerta" (sin jugadas)
	var tiene_jugada = _carta_tiene_jugada_posible(carta_seleccionada_actual.get_card_id())
	discard_button.disabled = tiene_jugada

func _carta_tiene_jugada_posible(hand_id: String) -> bool:
	for slot in grid.get_children():
		if _obtener_tipo_movimiento(slot, hand_id) != "":
			return true
	return false

func actualizar_ayuda_visual_tablero():
	# Ilumina los slots donde se puede jugar la carta seleccionada
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
# 7. LÓGICA DE SECUENCIA Y VICTORIA
# ==============================================================================
func _check_is_game_over() -> bool:
	var current_team = GameManager.get_current_team_id()
	var total_equipos = GameManager.total_teams_in_play
	# Meta: 2 secuencias (o 1 si hay 3 equipos)
	var meta = 1 if total_equipos == 3 else 2
	return team_sequences[current_team] >= meta
	
func _finalizar_partida():
	var win_team_id = GameManager.get_current_team_id()
	var nombre_ganador = "EQUIPO " + str(win_team_id + 1)
	
	var color_ganador = TEAM_COLORS[win_team_id]
	if win_team_id == 0: nombre_ganador += " (AZUL)"
	elif win_team_id == 1: nombre_ganador += " (ROJO)"
	else: nombre_ganador += " (VERDE)"
	
	# Bloquear interacciones
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
				# Slot del MISMO EQUIPO o Comodín (Free)
				if s.occupied_by == id_dueno or s.card_id == "FREE":
					if d == dir: linea.append(s)
					else: linea.insert(0, s)
					pos += d
				else:
					break
		
		# Si la línea tiene 5 o más, procesamos
		if linea.size() >= 5:
			for i in range(linea.size() - 4):
				var bloque = linea.slice(i, i + 5)
				if _procesar_secuencia_encontrada(bloque):
					encontro_algo = true
	
	return encontro_algo

func _procesar_secuencia_encontrada(slots) -> bool:
	# Verificamos que no estemos reutilizando más de 1 ficha de otra secuencia
	var fichas_reutilizadas_count = 0
	for s in slots:
		if s in fichas_en_secuencia:
			fichas_reutilizadas_count += 1
	
	if fichas_reutilizadas_count > 1: return false
	
	# Registrar secuencia
	var current_team = GameManager.get_current_team_id()
	team_sequences[current_team] += 1
	
	# Marcar fichas como usadas
	for s in slots:
		if not s in fichas_en_secuencia:
			fichas_en_secuencia.append(s)
	
	# Mostrar popup "SEQUENCE!" SOLO SI NO HA GANADO
	# (Si ganó, queremos que salga directo el de Victoria)
	if not _check_is_game_over():
		var color_del_equipo = TEAM_COLORS[current_team]
		mostrar_popup_sequence(color_del_equipo)
	
	# Animación de brillo en fichas (Siempre)
	var delay_step = 0.1
	var current_delay = 0.0
	for s in slots:
		if s.has_method("play_sequence_anim"):
			s.play_sequence_anim(current_delay)
			current_delay += delay_step
			
	return true


# ==============================================================================
# 8. VISUALES Y HELPERS (Popups, Math)
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
	
	# --- Título ---
	var lbl_victoria = Label.new()
	lbl_victoria.text = "¡VICTORIA!"
	lbl_victoria.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_victoria.add_theme_font_size_override("font_size", 130)
	lbl_victoria.add_theme_color_override("font_color", color_equipo)
	lbl_victoria.add_theme_constant_override("outline_size", 30)
	lbl_victoria.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_victoria.add_theme_constant_override("shadow_offset_x", 12)
	lbl_victoria.add_theme_constant_override("shadow_offset_y", 12)
	lbl_victoria.add_theme_color_override("font_shadow_color", color_equipo.darkened(0.6))
	center_box.add_child(lbl_victoria)
	
	# --- Nombre Equipo ---
	var lbl_equipo = Label.new()
	lbl_equipo.text = nombre_ganador
	lbl_equipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_equipo.add_theme_font_size_override("font_size", 40)
	lbl_equipo.add_theme_color_override("font_color", Color.WHITE)
	center_box.add_child(lbl_equipo)
	
	# Espaciador
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	center_box.add_child(spacer)
	
	# --- Botón Volver ---
	var btn = Button.new()
	btn.text = "VOLVER AL MENÚ"
	btn.add_theme_font_size_override("font_size", 28)
	btn.custom_minimum_size = Vector2(300, 70)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER 
	
	var style_btn = StyleBoxFlat.new()
	style_btn.bg_color = color_equipo.darkened(0.2)
	style_btn.set_corner_radius_all(10)
	style_btn.border_width_bottom = 5
	style_btn.border_color = color_equipo.darkened(0.5)
	
	btn.add_theme_stylebox_override("normal", style_btn)
	btn.add_theme_stylebox_override("hover", style_btn)
	btn.add_theme_stylebox_override("pressed", style_btn)
	center_box.add_child(btn)
	
	# --- CORRECCIÓN DE CENTRADO ---
	center_box.modulate.a = 0 
	await get_tree().process_frame # Esperar a que Godot calcule el tamaño
	
	center_box.pivot_offset = center_box.size / 2
	center_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	center_box.scale = Vector2.ZERO
	center_box.modulate.a = 1.0
	
	var t = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(center_box, "scale", Vector2.ONE, 0.7)
	
	btn.pressed.connect(func():
		get_tree().change_scene_to_file(MENU_SCENE_PATH)
	)

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
	
	# Esperar frame para centrar pivote
	await get_tree().process_frame
	popup.pivot_offset = popup.size / 2
	
	# Animación Entrada/Salida
	popup.scale = Vector2.ZERO
	var t = create_tween().set_parallel(false)
	
	t.tween_property(popup, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.0)
	t.tween_property(popup, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(popup, "modulate:a", 0.0, 0.3)
	
	t.finished.connect(popup.queue_free)

# --- Helpers de Coordenadas ---
func _get_slot_coords(slot) -> Vector2i:
	var idx = slot.get_index()
	return Vector2i(idx % 10, idx / 10)

func _get_slot_at(pos: Vector2i):
	return grid.get_child(pos.y * 10 + pos.x)

func _pos_valida(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 10 and pos.y >= 0 and pos.y < 10
