extends Control

@onready var grid = $RootMargin/VBoxContainer/CenterContainer/BoardAspect/BoardPanel/MarginContainer/GridContainer
@onready var hand_container = $RootMargin/VBoxContainer/HandPanel/MarginContainer/HandRow/HandContainer
@onready var center_container = $RootMargin/VBoxContainer/CenterContainer
@onready var label_turno = $RootMargin/VBoxContainer/HeaderBar/LabelTurno
@onready var discard_button: Button= $RootMargin/VBoxContainer/HandPanel/MarginContainer/HandRow/DiscardButton
@onready var header_bar = $RootMargin/VBoxContainer/HeaderBar

var slot_scene = preload("res://Scenes/Slot.tscn")
var card_hand_scene = preload("res://Scenes/CardHand.tscn")

var fichas_en_secuencia: Array = []
var carta_seleccionada_actual = null
var turn_tween: Tween

var secuencias_j1: int = 0
var secuencias_j2: int = 0

# Colores de Jugadores
const COLOR_J1 = Color.MEDIUM_SLATE_BLUE
const COLOR_J2 = Color.INDIAN_RED
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

	if GameManager.get_deck_count() == 0:
		GameManager.generate_deck()
		GameManager.shuffle_deck()
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
	if GameManager.turno_actual == 1:
		label_turno.text = "TURNO: JUGADOR 1 (AZUL)"
		label_turno.add_theme_color_override("font_color", COLOR_J1)
	else:
		label_turno.text = "TURNO: JUGADOR 2 (ROJO)"
		label_turno.add_theme_color_override("font_color", COLOR_J2)
	_animar_header_turno()

func _animar_header_turno():
	if turn_tween: turn_tween.kill()
	header_bar.scale = Vector2(0.98, 0.98)
	turn_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	turn_tween.tween_property(header_bar, "scale", Vector2.ONE, 0.16)


# ===============================
# GESTIÓN DE MANOS
# ===============================
func repartir_manos_iniciales():
	# Llenamos las manos lógicas en el GameManager para ambos jugadores
	# Solo repartimos si las manos están vacías
	if GameManager.get_mano_actual().is_empty(): 
		for i in range(7):
			GameManager.agregar_a_mano(1, GameManager.draw_card())
			GameManager.agregar_a_mano(2, GameManager.draw_card())

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
	
	var id_adversario = "p2" if GameManager.turno_actual == 1 else "p1"
	
	if hand_id.ends_with("_J1"):
		if slot.occupied_by == id_adversario:
			if not (slot in fichas_en_secuencia): 
				return "quita"
	
	elif hand_id.ends_with("_J2"):
		if slot.occupied_by == "":
			return "pon"
			
	else:
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
		var color_actual = COLOR_J1 if GameManager.turno_actual == 1 else COLOR_J2
		var id_jugador = "p" + str(GameManager.turno_actual)
		slot.colocar_ficha(color_actual, id_jugador)
		verificar_secuencia(slot)
		finalizar_jugada()
		
	elif accion == "quita":
		slot.quitar_ficha()
		finalizar_jugada()

func finalizar_jugada():
	# 1. Eliminar carta usada (El GameManager ahora la enviará al descarte)
	if carta_seleccionada_actual:
		GameManager.eliminar_de_mano(GameManager.turno_actual, carta_seleccionada_actual.get_card_id())
		carta_seleccionada_actual = null
	
	# 2. Robar y pasar turno
	robar_carta()
	
	# 3. Verificar si el jugador actual GANÓ (2 secuencias)
	if _verificar_victoria_jugador():
		_finalizar_partida()
		return # Detener el flujo de turnos

	GameManager.cambiar_turno()
	
	# 4. Refrescar UI
	actualizar_ui_turnos()
	mostrar_mano_jugador_actual()
	actualizar_ayuda_visual_tablero()


func robar_carta():
	var id = GameManager.draw_card()
	if id != "":
		GameManager.agregar_a_mano(GameManager.turno_actual, id)

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
func _verificar_victoria_jugador() -> bool:
	if GameManager.turno_actual == 1:
		return secuencias_j1 >= 2
	else:
		return secuencias_j2 >= 2

func _finalizar_partida():
	var ganador = "JUGADOR 1 (AZUL)" if GameManager.turno_actual == 1 else "JUGADOR 2 (ROJO)"
	label_turno.text = "¡GANADOR: " + ganador + "!"
	label_turno.add_theme_color_override("font_color", Color.GOLD)
	

	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_button.disabled = true
	
	mostrar_popup_victoria(ganador)

func verificar_secuencia(slot_central):
	var direcciones = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	var centro = _get_slot_coords(slot_central)
	var id_dueno = slot_central.occupied_by
	
	for dir in direcciones:
		var linea: Array = [slot_central]
		
		# Expandir en ambas direcciones para buscar 5 fichas
		for d in [dir, -dir]:
			var pos = centro + d
			while _pos_valida(pos):
				var s = _get_slot_at(pos)
				# Slot propio O comodín Free del tablero (esquinas)
				if s.occupied_by == id_dueno or s.card_id == "FREE":
					if d == dir: linea.append(s) 
					else: linea.insert(0, s)      
					pos += d
				else:
					break
		
		# Checar si hay 5 seguidos
		if linea.size() >= 5:
			# Extraer sub-grupos de 5 (si hay 6 o más fichas)
			for i in range(linea.size() - 4):
				var bloque = linea.slice(i, i + 5)
				_procesar_secuencia_encontrada(bloque)


func _procesar_secuencia_encontrada(slots):
	var fichas_reutilizadas_count = 0
	for s in slots:
		if s in fichas_en_secuencia:
			fichas_reutilizadas_count += 1
	
	if fichas_reutilizadas_count > 1:
		return
	
	if GameManager.turno_actual == 1:
		secuencias_j1 += 1
		print("Secuencias J1: ", secuencias_j1)
	else:
		secuencias_j2 += 1
		print("Secuencias J2: ", secuencias_j2)
		
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
	
func mostrar_popup_victoria(nombre_ganador: String):
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
	v_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(v_box)
	
	# Etiqueta de victoria
	var win_label = Label.new()
	win_label.text = "¡PARTIDA FINALIZADA!\nGANADOR: " + nombre_ganador
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.add_theme_font_size_override("font_size", 50)
	# Le damos una sombra para que se lea mejor
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
	btn_restart.custom_minimum_size = Vector2(250, 70)
	v_box.add_child(btn_restart)
	
	# Conexión para reiniciar
	btn_restart.pressed.connect(func(): 
		GameManager.reiniciar_juego() # Asegúrate de llamar a limpiar el mazo
		get_tree().reload_current_scene()
	)
