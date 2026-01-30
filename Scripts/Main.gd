extends Control

@onready var grid = $RootMargin/VBoxContainer/CenterContainer/BoardAspect/BoardPanel/MarginContainer/GridContainer
@onready var hand_container = $RootMargin/VBoxContainer/HandPanel/MarginContainer/HandRow/HandContainer
@onready var center_container = $RootMargin/VBoxContainer/CenterContainer
@onready var label_turno = $RootMargin/VBoxContainer/HeaderBar/LabelTurno
@onready var discard_button: Button= $RootMargin/VBoxContainer/HandPanel/MarginContainer/HandRow/DiscardButton
@onready var header_bar = $RootMargin/VBoxContainer/HeaderBar
@onready var hand_panel = $RootMargin/VBoxContainer/HandPanel


var slot_scene = preload("res://Scenes/Slot.tscn")
var card_hand_scene = preload("res://Scenes/CardHand.tscn")

const MENU_SCENE_PATH = "res://Scenes/MainMenu.tscn"


var fichas_en_secuencia: Array = []
var carta_seleccionada_actual = null
var turn_tween: Tween
var color_tween: Tween

# Contador de secuencias POR EQUIPO (Team ID -> Cantidad)
# 0: Azul, 1: Rojo, 2: Verde
var team_sequences = {
	0: 0,
	1: 0,
	2: 0
}

# --- CONFIGURACIÓN VISUAL ---
# Mapeamos los IDs de equipo del GameManager a Colores Visuales
const TEAM_COLORS = {
	0: Color.DODGER_BLUE,# Equipo BLUE
	1: Color.INDIAN_RED,# Equipo RED
	2: Color.FOREST_GREEN# Equipo GREEN
}

# Colores del Tablero
const COLOR_SLOT_FREE = Color(0.2, 0.5, 0.2)
const COLOR_SLOT_NORMAL = Color(0.4, 0.4, 0.4)

# ===============================
# READY
# ===============================
func _ready():
	discard_button.pressed.connect(_on_discard_pressed)
	discard_button.disabled = true
	get_viewport().size_changed.connect(_resize_board_slots)

	if GameManager.players.size() == 0:
		GameManager.setup_game(2)
		
	setup_board()
	repartir_manos_iniciales()
	actualizar_ui_turnos()

# ===============================
# TABLERO
# ===============================
func setup_board():
	grid.columns = 10
	for child in grid.get_children():
		child.queue_free()

	for row in BoardData.BOARD_MAP:
		for id in row:
			var new_slot = slot_scene.instantiate()
			grid.add_child(new_slot)
			new_slot.setup(id)
			new_slot.slot_clicked.connect(_on_slot_clicked)
			var base_c = COLOR_SLOT_FREE if id == "FREE" else COLOR_SLOT_NORMAL
			new_slot.set_base_color(base_c, id == "FREE")

	_resize_board_slots()


func _resize_board_slots():
	await get_tree().process_frame
	if not is_inside_tree(): return

	var available_w = grid.size.x
	var available_h = grid.size.y
	if available_w <= 0 or available_h <= 0:
		return

	# Lógica para mantener celdas rectangulares 
	var ratio := 75.0 / 110.0
	var cols := 10.0
	var cell_w = available_w / cols
	var cell_h = cell_w / ratio

	if cell_h * 10 > available_h and available_h > 0:
		cell_h = available_h / 10.0
		cell_w = cell_h * ratio

	for slot in grid.get_children():
		slot.custom_minimum_size = Vector2(cell_w, cell_h)

# ===============================
# GESTIÓN DE TURNOS Y UI
# ===============================

func actualizar_ui_turnos():
	var p_data = GameManager.get_current_player_data()
	var team_id = p_data["team"]
	
	# Texto dinámico: "TURNO: JUGADOR 1 (EQUIPO 0)"
	label_turno.text = "TURNO: " + p_data["name"]
	
	# Color del texto según el equipo
	var base_color = Color.WHITE
	if TEAM_COLORS.has(team_id):
		base_color = TEAM_COLORS[team_id]
	
	label_turno.add_theme_color_override("font_color", base_color)
	
	_animar_cambio_color_panel(base_color)
	_animar_header_turno()

func _animar_cambio_color_panel(target_color: Color):
	# Obtenemos el StyleBox actual del panel (o creamos uno si no tiene override)
	var style_box = hand_panel.get_theme_stylebox("panel")
	
	# Importante: Duplicar el estilo la primera vez para no afectar a otros nodos
	# que compartan el mismo recurso, o si es la primera vez que lo tocamos.
	if not style_box.resource_local_to_scene:
		style_box = style_box.duplicate()
		hand_panel.add_theme_stylebox_override("panel", style_box)
		style_box.resource_local_to_scene = true
	
	# Si ya existe una animación de color corriendo, la matamos para empezar la nueva
	if color_tween:
		color_tween.kill()
		
	color_tween = create_tween().set_parallel(true) # Parallel para animar fondo y borde a la vez
	
	# 1. Color del BORDE (Intenso, el color real del equipo)
	# Asegúrate de haber puesto Border Width > 0 en el editor para que se vea
	style_box.border_color = target_color # Valor inicial brusco si no tiene
	# Pero mejor lo animamos desde el color actual (godot lo maneja auto con tween_property)
	color_tween.tween_property(style_box, "border_color", target_color, 0.4)
	
	# 2. Color del FONDO (Oscuro, para que las cartas resalten)
	# Usamos .darkened(0.7) para que sea un tono muy oscuro del color del equipo
	var dark_bg = target_color.darkened(0.8) 
	# Ajustamos la transparencia (alpha) para que no sea negro solido si tienes fondo atrás
	dark_bg.a = 0.8 
	
	color_tween.tween_property(style_box, "bg_color", dark_bg, 0.4)
	
func _animar_header_turno():
	if turn_tween: turn_tween.kill()
	header_bar.scale = Vector2(0.98, 0.98)
	turn_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	turn_tween.tween_property(header_bar, "scale", Vector2.ONE, 0.16)


# ===============================
# GESTIÓN DE MANOS
# ===============================
func repartir_manos_iniciales():
	# REGLA OFICIAL DE SEQUENCE SOBRE CARTAS POR JUGADOR
	var num_players = GameManager.players.size()
	var cards_per_hand = 7 # Default para 2 jugadores
	
	match num_players:
		2: cards_per_hand = 7
		3: cards_per_hand = 6
		4: cards_per_hand = 6
		6: cards_per_hand = 5
		8: cards_per_hand = 4
		9: cards_per_hand = 4
		10: cards_per_hand = 3
		12: cards_per_hand = 3
	
	# Repartir a TODOS los jugadores registrados en el GameManager
	# Solo si sus manos están vacías
	var needs_deal = true
	if not GameManager.players[0]["hand"].is_empty():
		needs_deal = false
		
	if needs_deal:
		for i in range(cards_per_hand):
			for p_index in range(num_players):
				GameManager.agregar_a_mano(p_index, GameManager.draw_card())

	mostrar_mano_jugador_actual()

func mostrar_mano_jugador_actual():
	# Limpiar visualmente
	for child in hand_container.get_children():
		child.queue_free()
	
	# Obtener datos del Singleton
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
		print("Seleccion: ",carta_seleccionada_actual.get_card_id())
	
	actualizar_jerarquia_visual_mano()
	actualizar_ayuda_visual_tablero()
	actualizar_estado_descartar()


func actualizar_jerarquia_visual_mano():
	var hay_seleccion = carta_seleccionada_actual != null
	for wrapper in hand_container.get_children():
		# wrapper es CardWrapper (Control)
		var btn = wrapper.get_node("CardHand") as Button
		if not btn:
			continue
		if not hay_seleccion:
			# Todo normal si no hay selección
			btn.self_modulate = Color.WHITE
			continue

		# Si hay selección: solo la seleccionada queda normal
		if not hay_seleccion or wrapper == carta_seleccionada_actual:
			btn.self_modulate = Color.WHITE
		else:
			btn.self_modulate = Color(0.55, 0.55, 0.55) # Oscurecer no seleccionadas

# ===============================
# LÓGICA CORE
# ===============================

# Retorna: "pon", "quita" o "" (nada)
func _obtener_tipo_movimiento(slot, hand_id: String) -> String:
	if slot.card_id == "FREE": return ""
	
	# Datos del equipo actual
	var current_team_id = GameManager.get_current_team_id()
	# String que identifica al equipo en el slot (ej: "team_0")
	var current_team_str = "team_" + str(current_team_id)
	
	if hand_id.ends_with("_J1"):
		# Jota de 1 ojo: QUITAR
		# Es válido si está ocupado, PERO NO por mi equipo
		if slot.occupied_by != "" and slot.occupied_by != current_team_str:
			if not (slot in fichas_en_secuencia):
				return "quita"
	
	elif hand_id.ends_with("_J2"):
		# Jota de 2 ojos: PONER (Comodín)
		if slot.occupied_by == "":
			return "pon"
			
	else:
		# Carta Normal
		if slot.card_id == hand_id and slot.occupied_by == "":
			return "pon"
			
	return ""
# ===============================
# INTERACCION TABLERO
# ===============================
func actualizar_ayuda_visual_tablero():
	for slot in grid.get_children():
		slot.set_highlight(false)
		slot.set_playable(false)
	
	if not carta_seleccionada_actual: return
	
	var hand_id = carta_seleccionada_actual.get_card_id()
	
	for slot in grid.get_children():
		# Usamos la lógica unificada
		if _obtener_tipo_movimiento(slot, hand_id) != "":
			slot.set_highlight(true)
			slot.set_playable(true)

func _on_slot_clicked(slot):
	if not carta_seleccionada_actual: return
	
	var hand_id = carta_seleccionada_actual.get_card_id()
	var accion = _obtener_tipo_movimiento(slot, hand_id)	
	
	if accion == "pon":
		# Obtenemos color y ID del equipo actual
		var current_team_id = GameManager.get_current_team_id()
		var color_equipo = TEAM_COLORS[current_team_id]
		var mark_str = "team_" + str(current_team_id)
		
		slot.colocar_ficha(color_equipo, mark_str)
		verificar_secuencia(slot)
		finalizar_jugada()
		
	elif accion == "quita":
		slot.quitar_ficha()
		finalizar_jugada()

func finalizar_jugada():
	# 1. Eliminar carta usada de la mano del jugador actual
	if carta_seleccionada_actual:
		GameManager.eliminar_de_mano(GameManager.current_player_index, carta_seleccionada_actual.get_card_id())
		carta_seleccionada_actual = null
	
	# 2. Robar
	robar_carta()
	
	# 3. Verificar Victoria (del EQUIPO actual)
	if _verificar_victoria_equipo():
		_finalizar_partida()
		return

	# 4. Cambiar Turno
	GameManager.cambiar_turno()
	
	# 5. Refrescar UI
	actualizar_ui_turnos()
	mostrar_mano_jugador_actual()
	actualizar_ayuda_visual_tablero()


func robar_carta():
	var id = GameManager.draw_card()
	if id != "":
		GameManager.agregar_a_mano(GameManager.current_player_index, id)

# ===============================
# DESCARTAR (DEAD CARD)
# ===============================
func _on_discard_pressed():
	if not carta_seleccionada_actual: return
	
	# Validar doble check
	if _carta_tiene_jugada_posible(carta_seleccionada_actual.get_card_id()):
		return # No se puede descartar si es jugable

	# Animación y borrado
	var hand_id = carta_seleccionada_actual.get_card_id()
	GameManager.eliminar_de_mano(GameManager.turno_actual, hand_id)
	
	# Pequeña espera si hay animación en la carta
	if carta_seleccionada_actual.has_method("play_discard_anim"):
		await carta_seleccionada_actual.play_discard_anim()
	else:
		carta_seleccionada_actual.queue_free()
		await get_tree().process_frame

	carta_seleccionada_actual = null
	robar_carta() # Reglas dicen: descartas y robas nueva
	GameManager.cambiar_turno()
	actualizar_ui_turnos()
	mostrar_mano_jugador_actual()

func actualizar_estado_descartar():
	if not carta_seleccionada_actual:
		discard_button.disabled = true
		return
	# Si NO tiene jugada, activamos botón
	var tiene_jugada = _carta_tiene_jugada_posible(carta_seleccionada_actual.get_card_id())
	discard_button.disabled = tiene_jugada

func _carta_tiene_jugada_posible(hand_id: String) -> bool:
	for slot in grid.get_children():
		if _obtener_tipo_movimiento(slot, hand_id) != "":
			return true
	return false

# ===============================
# LÓGICA DE SECUENCIA (Ganar)
# ===============================
func _verificar_victoria_equipo() -> bool:
	# Checamos las secuencias del EQUIPO actual
	var current_team = GameManager.get_current_team_id()
	var total_equipos = GameManager.total_teams_in_play
	var secuencias_necesarias = 2
	
	if total_equipos == 3:
		secuencias_necesarias = 1
	
	# Verificamos si alcanzaron la meta
	return team_sequences[current_team] >= secuencias_necesarias
	
func _finalizar_partida():
	# Obtener nombre del equipo ganador (para display)
	var win_team_id = GameManager.get_current_team_id()
	var nombre_ganador = "EQUIPO " + str(win_team_id + 1) # Equipo 1, 2 o 3
	
	# Color
	var color_ganador = TEAM_COLORS[win_team_id]
	if win_team_id == 0: nombre_ganador += " (AZUL)"
	elif win_team_id == 1: nombre_ganador += " (ROJO)"
	else: nombre_ganador += " (VERDE)"
	
	label_turno.text = "¡VICTORIA: " + nombre_ganador + "!"
	label_turno.add_theme_color_override("font_color", color_ganador)

	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_button.disabled = true
	
	mostrar_popup_victoria(nombre_ganador, color_ganador)

func verificar_secuencia(slot_central):
	var direcciones = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	var centro = _get_slot_coords(slot_central)
	var id_dueno = slot_central.occupied_by
	
	for dir in direcciones:
		var linea: Array = [slot_central]
		for d in [dir, -dir]:
			var pos = centro + d
			while _pos_valida(pos):
				var s = _get_slot_at(pos)
				# Slot del MISMO EQUIPO o Comodín
				if s.occupied_by == id_dueno or s.card_id == "FREE":
					if d == dir: linea.append(s)
					else: linea.insert(0, s)
					pos += d
				else:
					break
		
		if linea.size() >= 5:
			for i in range(linea.size() - 4):
				var bloque = linea.slice(i, i + 5)
				_procesar_secuencia_encontrada(bloque)

func _procesar_secuencia_encontrada(slots):
	var fichas_reutilizadas_count = 0
	for s in slots:
		if s in fichas_en_secuencia:
			fichas_reutilizadas_count += 1
	
	if fichas_reutilizadas_count > 1: return
	
	# Sumar secuencia al EQUIPO actual
	var current_team = GameManager.get_current_team_id()
	team_sequences[current_team] += 1
	print("Secuencia para Equipo ", current_team, ". Total: ", team_sequences[current_team])
		
	mostrar_popup_sequence()
	
	var delay_step = 0.1
	var current_delay = 0.0
	
	for s in slots:
		if not s in fichas_en_secuencia:
			fichas_en_secuencia.append(s)
		if s.has_method("play_sequence_anim"):
			s.play_sequence_anim(current_delay)
			current_delay += delay_step
# ===============================
# VISUALES Y HELPERS
# ===============================
func mostrar_popup_sequence():
	var popup := Label.new()
	popup.text = "SEQUENCE!"
	popup.add_theme_color_override("font_color", Color.GREEN)
	popup.add_theme_font_size_override("font_size", 60)
	popup.z_index = 100
	
	center_container.add_child(popup)
	# Centrar manualmente (o usar Anchors si el label tuviera script)
	popup.position = (center_container.size - popup.size) / 2
	popup.pivot_offset = popup.size / 2
	
	# Animación Pop-up
	popup.scale = Vector2.ZERO
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	t.tween_property(popup, "scale", Vector2.ONE, 0.5)
	t.tween_interval(1.0)
	t.tween_property(popup, "modulate:a", 0.0, 0.5)
	t.finished.connect(popup.queue_free)

func _get_slot_coords(slot) -> Vector2i:
	var idx = slot.get_index()
	return Vector2i(idx % 10, idx / 10)

func _get_slot_at(pos: Vector2i):
	return grid.get_child(pos.y * 10 + pos.x)

func _pos_valida(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 10 and pos.y >= 0 and pos.y < 10
	
func mostrar_popup_victoria(nombre_ganador: String, color_equipo: Color):
	# Creamos un CanvasLayer para que se dibuje por encima de toda la UI actual
	var layer = CanvasLayer.new()
	layer.layer = 100 # Un nivel alto asegura que esté al frente
	add_child(layer)
	
	# El fondo oscuro
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8) # Un poco más oscuro para que resalte
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	
	# Contenedor para centrar el texto y el botón
	var v_box = VBoxContainer.new()
	v_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(v_box)
	
	# Etiqueta de victoria
	var win_label = Label.new()
	win_label.text = "¡PARTIDA FINALIZADA!\nGANADOR: " + nombre_ganador
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.add_theme_font_size_override("font_size", 50)
	
	# Le damos una sombra para que se lea mejor
	win_label.add_theme_color_override("font_color", color_equipo)
	win_label.add_theme_constant_override("shadow_offset_x", 3)
	win_label.add_theme_constant_override("shadow_offset_y", 3)
	v_box.add_child(win_label)
	
	# Espaciador
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	v_box.add_child(spacer)
	
	# Botón de reiniciar
	var btn_restart = Button.new()
	btn_restart.text = "REINICIAR JUEGO"
	btn_restart.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v_box.add_child(btn_restart)
	
	# Conexión para reiniciar
	btn_restart.pressed.connect(func(): 
		get_tree().change_scene_to_file(MENU_SCENE_PATH)
	)
