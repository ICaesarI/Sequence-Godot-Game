extends Control

@onready var grid = $VBoxContainer/CenterContainer/GridContainer
@onready var hand_container = $VBoxContainer/HandContainer
@onready var center_container = $VBoxContainer/CenterContainer
@onready var vbox = $VBoxContainer
@onready var label_turno = $VBoxContainer/LabelTurno

var fichas_en_secuencia: Array = []

var slot_scene = preload("res://Scenes/Slot.tscn")
var card_hand_scene = preload("res://Scenes/CardHand.tscn")

var carta_seleccionada_actual = null
var color_j1 = Color.MEDIUM_SLATE_BLUE
var color_j2 = Color.INDIAN_RED

# ===============================
# READY
# ===============================
func _ready():
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_container.size_flags_vertical = Control.SIZE_SHRINK_END
	
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
			new_slot.custom_minimum_size = Vector2(75, 110)
			new_slot.card_id = id
			
			new_slot.slot_clicked.connect(_on_slot_clicked)
			
			if new_slot.has_node("Label"):
				new_slot.get_node("Label").text = "" if id == "FREE" else id.replace("_", " ")
			
			new_slot.color = Color(0.2, 0.5, 0.2) if id == "FREE" else Color(0.4, 0.4, 0.4)

func actualizar_ui_turnos():
	if GameManager.turno_actual == 1:
		label_turno.text = "TURNO: JUGADOR 1 (AZUL)"
		label_turno.add_theme_color_override("font_color", color_j1)
	else:
		label_turno.text = "TURNO: JUGADOR 2 (ROJO)"
		label_turno.add_theme_color_override("font_color", color_j2)

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
		new_card.pressed.connect(func(): gestionar_seleccion_mano(new_card))

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
	
	actualizar_ayuda_visual_tablero()

# ===============================
# LOGICA DE JUEGO
# ===============================
func actualizar_ayuda_visual_tablero():
	for slot in grid.get_children():
		if slot.has_method("set_highlight"): slot.set_highlight(false)
	
	if not carta_seleccionada_actual: return
	var hand_id = carta_seleccionada_actual.card_id
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

func _on_slot_clicked(slot):
	if not carta_seleccionada_actual: return
	
	var hand_id = carta_seleccionada_actual.card_id
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
		slot.color = Color(0.4, 0.4, 0.4)

	finalizar_jugada()

func finalizar_jugada():
	# 1. Eliminar de la mano lógica del GameManager
	if carta_seleccionada_actual:
		GameManager.eliminar_de_mano(GameManager.turno_actual, carta_seleccionada_actual.card_id)
		carta_seleccionada_actual = null
	
	# 2. El jugador que termina roba carta
	robar_carta()
	
	# 3. Cambio de turno
	GameManager.cambiar_turno()
	
	# 4. Refresco Visual Total
	actualizar_ui_turnos()
	mostrar_mano_jugador_actual()
	actualizar_ayuda_visual_tablero()

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

	for s in slots:
		if not s in fichas_en_secuencia:
			fichas_en_secuencia.append(s)
			# Efecto visual de secuencia completada
			s.color = Color(0.2, 0.2, 0.2) 

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
