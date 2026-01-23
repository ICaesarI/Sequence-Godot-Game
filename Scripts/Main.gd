extends Control

@onready var grid = $VBoxContainer/CenterContainer/GridContainer
@onready var hand_container = $VBoxContainer/HandContainer
@onready var center_container = $VBoxContainer/CenterContainer
@onready var vbox = $VBoxContainer

var fichas_en_secuencia: Array = []

var slot_scene = preload("res://Scenes/Slot.tscn")
var card_hand_scene = preload("res://Scenes/CardHand.tscn")

var carta_seleccionada_actual = null
var jugador_color = Color.MEDIUM_SLATE_BLUE
var jugador_id = "p1"

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
	repartir_mano_inicial()

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

# ===============================
# MANO
# ===============================
func repartir_mano_inicial():
	for child in hand_container.get_children():
		child.queue_free()
	for i in range(7):
		robar_carta()

func robar_carta():
	var id_carta = GameManager.draw_card()
	if id_carta:
		var new_card = card_hand_scene.instantiate()
		hand_container.add_child(new_card)
		new_card.pressed.connect(func(): gestionar_seleccion_mano(new_card))
		new_card.setup(id_carta)

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
# HIGHLIGHT
# ===============================
func actualizar_ayuda_visual_tablero():
	for slot in grid.get_children():
		slot.set_highlight(false)
	
	if not carta_seleccionada_actual:
		return
	
	var hand_id = carta_seleccionada_actual.card_id
	
	for slot in grid.get_children():
		var valido := false
		
		if hand_id == slot.card_id and slot.occupied_by == "":
			valido = true
		elif hand_id.ends_with("_J2") and slot.card_id != "FREE" and slot.occupied_by == "":
			valido = true
		elif hand_id.ends_with("_J1") and slot.card_id != "FREE" and slot.occupied_by != "":
			valido = true
		
		if valido:
			slot.set_highlight(true)

# ===============================
# CLICK SLOT
# ===============================
func _on_slot_clicked(slot):
	if not carta_seleccionada_actual:
		return
	
	var hand_id = carta_seleccionada_actual.card_id
	
	if (hand_id == slot.card_id or hand_id.ends_with("_J2")) \
	and slot.occupied_by == "" \
	and slot.card_id != "FREE":
		ejecutar_movimiento(slot, "pon")
	
	elif hand_id.ends_with("_J1") \
	and slot.card_id != "FREE" \
	and slot.occupied_by != "":
		
		if slot in fichas_en_secuencia:
			print("No puedes quitar una ficha de una SEQUENCE")
			return
		
		ejecutar_movimiento(slot, "quita")

# ===============================
# MOVIMIENTO
# ===============================
func ejecutar_movimiento(slot, accion):
	if accion == "pon":
		slot.colocar_ficha(jugador_color, jugador_id)
		verificar_secuencia(slot)
	
	elif accion == "quita":
		for child in slot.get_children():
			if child.name != "Label":
				child.queue_free()
		slot.occupied_by = ""
		slot.color = Color(0.4, 0.4, 0.4)
	
	finalizar_jugada()

func finalizar_jugada():
	if carta_seleccionada_actual:
		carta_seleccionada_actual.queue_free()
		carta_seleccionada_actual = null
	
	actualizar_ayuda_visual_tablero()
	robar_carta()

# ===============================
# SEQUENCE LOGIC
# ===============================
func verificar_secuencia(slot_central):
	var direcciones = [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, -1)
	]
	
	var centro = _get_slot_coords(slot_central)
	
	for dir in direcciones:
		var linea: Array = []
		
		var pos = centro - dir
		while _pos_valida(pos):
			var s = _get_slot_at(pos)
			if s.occupied_by == jugador_id or s.card_id == "FREE":
				linea.insert(0, s)
				pos -= dir
			else:
				break
		
		linea.append(slot_central)
		
		pos = centro + dir
		while _pos_valida(pos):
			var s = _get_slot_at(pos)
			if s.occupied_by == jugador_id or s.card_id == "FREE":
				linea.append(s)
				pos += dir
			else:
				break
		
		if linea.size() >= 5:
			for i in range(linea.size() - 4):
				var bloque = linea.slice(i, i + 5)
				registrar_secuencia(bloque)

func registrar_secuencia(slots):
	var hay_nueva := false

	for s in slots:
		if not s in fichas_en_secuencia:
			hay_nueva = true

	if not hay_nueva:
		return

	for s in slots:
		if not s in fichas_en_secuencia:
			fichas_en_secuencia.append(s)
			s.color = Color(0.8, 0.8, 1.0)

	print("SEQUENCE FORMADA (cruce permitido)")


# ===============================
# GRID UTILS
# ===============================
func _get_slot_coords(slot) -> Vector2i:
	var index = slot.get_index()
	return Vector2i(index % 10, index / 10)

func _get_slot_at(pos: Vector2i):
	return grid.get_child(pos.y * 10 + pos.x)

func _pos_valida(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 10 and pos.y >= 0 and pos.y < 10
