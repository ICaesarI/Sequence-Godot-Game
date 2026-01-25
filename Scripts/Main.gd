extends Control

@onready var grid = $RootMargin/VBoxContainer/CenterContainer/BoardAspect/BoardPanel/MarginContainer/GridContainer
@onready var hand_container = $RootMargin/VBoxContainer/HandPanel/MarginContainer/HandRow/HandContainer
@onready var center_container = $RootMargin/VBoxContainer/CenterContainer
@onready var vbox = $RootMargin/VBoxContainer
@onready var label_turno = $RootMargin/VBoxContainer/HeaderBar/LabelTurno
@onready var discard_button: Button= $RootMargin/VBoxContainer/HandPanel/MarginContainer/HandRow/DiscardButton
@onready var hand_panel = $RootMargin/VBoxContainer/HandPanel
@onready var header_bar = $RootMargin/VBoxContainer/HeaderBar
@onready var board_panel = $RootMargin/VBoxContainer/CenterContainer/BoardAspect/BoardPanel


var fichas_en_secuencia: Array = []
var slot_scene = preload("res://Scenes/Slot.tscn")
var card_hand_scene = preload("res://Scenes/CardHand.tscn")

var carta_seleccionada_actual = null
var color_j1 = Color.MEDIUM_SLATE_BLUE
var color_j2 = Color.INDIAN_RED
var turn_tween: Tween

# ===============================
# READY
# ===============================
func _ready():
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
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
			new_slot.card_id = id
			
			new_slot.slot_clicked.connect(_on_slot_clicked)
			
			if new_slot.has_node("Label"):
				new_slot.get_node("Label").text = "" if id == "FREE" else id.replace("_", " ")
			
			var base_c = Color(0.2, 0.5, 0.2) if id == "FREE" else Color(0.4, 0.4, 0.4)
			var final_c = Color(base_c.r, base_c.g, base_c.b, 0.75)

			if new_slot.has_method("set_base_color"):
				new_slot.set_base_color(final_c, id == "FREE")
			else:
				new_slot.color = final_c

	_resize_board_slots()

func actualizar_ui_turnos():
	if GameManager.turno_actual == 1:
		label_turno.text = "TURNO: JUGADOR 1 (AZUL)"
		label_turno.add_theme_color_override("font_color", color_j1)
	else:
		label_turno.text = "TURNO: JUGADOR 2 (ROJO)"
		label_turno.add_theme_color_override("font_color", color_j2)
	actualizar_indicador_jugador_activo()

# ===============================
# GESTIÓN DE SLOTS
# ===============================
		
func _resize_board_slots():
	await get_tree().process_frame

	var available_w = grid.size.x
	var available_h = grid.size.y
	if available_w <= 0 or available_h <= 0:
		return

	var cols := 10
	var rows := 10

	# ratio slot: 75x110
	var ratio := 75.0 / 110.0

	# max height que cabe si usamos toda la altura
	var cell_h = available_h / rows
	var cell_w = cell_h * ratio

	# si por ancho no cabe, recalculamos desde ancho
	if cell_w * cols > available_w:
		cell_w = available_w / cols
		cell_h = cell_w / ratio

	for slot in grid.get_children():
		slot.custom_minimum_size = Vector2(cell_w, cell_h)



# ===============================
# GESTIÓN DE MANOS
# ===============================
func repartir_manos_iniciales():
	# Llenamos las manos lógicas en el GameManager para ambos jugadores
	for i in range(7):
		GameManager.agregar_a_mano(1, GameManager.draw_card())
		GameManager.agregar_a_mano(2, GameManager.draw_card())
	
	# Dibujamos la mano del jugador inicial (J1)
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


func robar_carta():
	var id_carta = GameManager.draw_card()
	if id_carta != "":
		# Se agrega al array del jugador que acaba de jugar
		GameManager.agregar_a_mano(GameManager.turno_actual, id_carta)

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
		# wrapper es CardWrapper (Control)
		var btn = wrapper.get_node("CardHand") as Button
		if not btn:
			continue

		if not hay_seleccion:
			# Todo normal si no hay selección
			btn.self_modulate = Color.WHITE
			continue

		# Si hay selección: solo la seleccionada queda normal
		if wrapper == carta_seleccionada_actual:
			btn.self_modulate = Color.WHITE
		else:
			btn.self_modulate = Color(0.55, 0.55, 0.55, 1.0)

	
# ===============================
# Discard Card
# ===============================
func carta_tiene_jugada(hand_id: String) -> bool:
	for slot in grid.get_children():
		if slot.card_id == "FREE":
			continue
		if hand_id.ends_with("_J2"):
			if slot.occupied_by == "":
				return true
		elif hand_id.ends_with("_J1"):
			var id_adversario = "p2" if GameManager.turno_actual == 1 else "p1"
			if slot.occupied_by == id_adversario and not (slot in fichas_en_secuencia):
				return true
		else:
			if slot.card_id == hand_id and slot.occupied_by == "":
				return true
	return false


func actualizar_estado_descartar():
	if not carta_seleccionada_actual:
		discard_button.disabled = true
		return

	var hand_id = carta_seleccionada_actual.get_card_id()
	# Solo habilitar si es dead card (NO tiene jugada)
	discard_button.disabled = carta_tiene_jugada(hand_id)


func _on_discard_pressed():
	if not carta_seleccionada_actual:
		return

	var hand_id = carta_seleccionada_actual.get_card_id()

	# Seguridad: solo descartar si es dead card
	if carta_tiene_jugada(hand_id):
		print("Esta carta aún tiene jugada, no se puede descartar.")
		return

	# 1) Quitar del modelo (GameManager)
	GameManager.eliminar_de_mano(GameManager.turno_actual, hand_id)

	# 2) Animar descarte y esperar
	var t: Tween = null
	if carta_seleccionada_actual.has_method("play_discard_anim"):
		t = carta_seleccionada_actual.play_discard_anim()
	else:
		carta_seleccionada_actual.queue_free()

	carta_seleccionada_actual = null
	actualizar_ayuda_visual_tablero()
	actualizar_estado_descartar()

	if t:
		await t.finished
	else:
		await get_tree().process_frame

	# 3) Robar reemplazo + cambiar turno + refrescar UI
	robar_carta()
	GameManager.cambiar_turno()
	actualizar_ui_turnos()
	mostrar_mano_jugador_actual()
	actualizar_jerarquia_visual_mano()

	
# ===============================
# LOGICA DE JUEGO
# ===============================
func actualizar_ayuda_visual_tablero():
	for slot in grid.get_children():
		if slot.has_method("set_highlight"): slot.set_highlight(false)
		if slot.has_method("set_playable"):slot.set_playable(false)
	
	if not carta_seleccionada_actual: return
	var hand_id = carta_seleccionada_actual.get_card_id()
	var id_adversario = "p2" if GameManager.turno_actual == 1 else "p1"
	
	for slot in grid.get_children():
		var es_valido = false
		
		# Poner normal o J2 (comodín)
		if (hand_id == slot.card_id or hand_id.ends_with("_J2")) and slot.occupied_by == "" and slot.card_id != "FREE":
			es_valido = true
		
		# Quitar con J1 (un ojo)
		elif hand_id.ends_with("_J1") and slot.card_id != "FREE" and slot.occupied_by == id_adversario:
			if not slot in fichas_en_secuencia:
				es_valido = true
			
		if es_valido and slot.has_method("set_highlight"):
			slot.set_highlight(true)
		if slot.has_method("set_playable"):
			slot.set_playable(true)

func _on_slot_clicked(slot):
	if not carta_seleccionada_actual: return
	
	var hand_id = carta_seleccionada_actual.get_card_id()
	var id_adversario = "p2" if GameManager.turno_actual == 1 else "p1"
	
	# ACCIÓN: PONER
	if (hand_id == slot.card_id or hand_id.ends_with("_J2")) and slot.occupied_by == "" and slot.card_id != "FREE":
		ejecutar_movimiento(slot, "pon")
	
	# ACCIÓN: QUITAR
	elif hand_id.ends_with("_J1") and slot.card_id != "FREE" and slot.occupied_by == id_adversario:
		if slot in fichas_en_secuencia: return
		ejecutar_movimiento(slot, "quita")

func ejecutar_movimiento(slot, accion):
	if accion == "pon":
		var color_actual = color_j1 if GameManager.turno_actual == 1 else color_j2
		var id_jugador = "p" + str(GameManager.turno_actual)
		slot.colocar_ficha(color_actual, id_jugador)
		verificar_secuencia(slot)
		
	elif accion == "quita":
		for child in slot.get_children():
			if child.name != "Label": child.queue_free()
		slot.occupied_by = ""
		if slot.has_method("restore_base"):
			slot.restore_base()
		else:
			# fallback
			slot.color = Color(0.4, 0.4, 0.4, 0.75)


	finalizar_jugada()

func finalizar_jugada():
	# 1. Eliminar de la mano lógica del GameManager
	if carta_seleccionada_actual:
		GameManager.eliminar_de_mano(GameManager.turno_actual, carta_seleccionada_actual.get_card_id())
		carta_seleccionada_actual = null
	
	# 2. El jugador que termina roba carta
	robar_carta()
	
	# 3. Cambio de turno
	GameManager.cambiar_turno()
	
	# 4. Refresco Visual Total
	actualizar_ui_turnos()
	mostrar_mano_jugador_actual()
	actualizar_ayuda_visual_tablero()
	actualizar_jerarquia_visual_mano()
	
func actualizar_indicador_jugador_activo():
	if turn_tween:
		turn_tween.kill()
		turn_tween = null
		
	# Animación sutil de confirmación
	header_bar.scale = Vector2.ONE * 0.98
	turn_tween = create_tween()
	turn_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	turn_tween.tween_property(header_bar, "scale", Vector2.ONE, 0.16)

# ===============================
# SEQUENCE LOGIC
# ===============================
func verificar_secuencia(slot_central):
	var direcciones = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)
	]
	var centro = _get_slot_coords(slot_central)
	var id_dueno = slot_central.occupied_by 
	
	for dir in direcciones:
		var linea: Array = []
		
		# Hacia atrás
		var pos = centro - dir
		while _pos_valida(pos):
			var s = _get_slot_at(pos)
			if s.occupied_by == id_dueno or s.card_id == "FREE":
				linea.insert(0, s)
				pos -= dir
			else: break
		
		linea.append(slot_central)
		
		# Hacia adelante
		pos = centro + dir
		while _pos_valida(pos):
			var s = _get_slot_at(pos)
			if s.occupied_by == id_dueno or s.card_id == "FREE":
				linea.append(s)
				pos += dir
			else: break
		
		if linea.size() >= 5:
			for i in range(linea.size() - 4):
				var bloque = linea.slice(i, i + 5)
				registrar_secuencia(bloque)

func registrar_secuencia(slots):
	var hay_nueva := false
	for s in slots:
		if not s in fichas_en_secuencia:
			hay_nueva = true

	if not hay_nueva: return
	
	# Popup global (una vez por secuencia)
	mostrar_popup_sequence()

	for s in slots:
		if not s in fichas_en_secuencia:
			fichas_en_secuencia.append(s)
			
		# Efecto visual de secuencia completada (estado final)
		s.color = Color(0.2, 0.2, 0.2, 0.90)

		# Animación de “WOW”
		if s.has_method("play_sequence_anim"):
			s.play_sequence_anim()

func mostrar_popup_sequence():
	var popup := Label.new()
	popup.text = "SEQUENCE!"
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Estilo rápido (puedes cambiar fuente/size luego)
	popup.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	popup.add_theme_font_size_override("font_size", 42)

	# Lo ponemos sobre el área del tablero (CenterContainer)
	center_container.add_child(popup)
	popup.z_index = 999

	# Centramos en el tablero (usando el tamaño del container)
	popup.position = (center_container.size / 2) - (popup.size / 2)

	# Estado inicial (pequeño y ligeramente abajo)
	popup.scale = Vector2(0.8, 0.8)
	popup.modulate.a = 0.0
	popup.position += Vector2(0, 18)

	# Animación: aparece + pop + sube + se desvanece
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(popup, "modulate:a", 1.0, 0.10)
	t.parallel().tween_property(popup, "scale", Vector2(1.05, 1.05), 0.18)
	t.parallel().tween_property(popup, "position", popup.position - Vector2(0, 18), 0.18)

	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(popup, "scale", Vector2.ONE, 0.10)

	# Mantener un poquito
	t.tween_interval(0.35)

	# Fade out + subir leve
	t.tween_property(popup, "modulate:a", 0.0, 0.22)
	t.parallel().tween_property(popup, "position", popup.position - Vector2(0, 10), 0.22)

	t.finished.connect(func():
		popup.queue_free()
	)


# ===============================
# UTILS
# ===============================
func _get_slot_coords(slot) -> Vector2i:
	var index = slot.get_index()
	return Vector2i(index % 10, index / 10)

func _get_slot_at(pos: Vector2i):
	return grid.get_child(pos.y * 10 + pos.x)

func _pos_valida(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 10 and pos.y >= 0 and pos.y < 10
