extends Control

@onready var grid = $VBoxContainer/CenterContainer/GridContainer
@onready var hand_container = $VBoxContainer/HandContainer
# Referencia necesaria para el estiramiento vertical
@onready var center_container = $VBoxContainer/CenterContainer
@onready var vbox = $VBoxContainer

var slot_scene = preload("res://Scenes/Slot.tscn")
var card_hand_scene = preload("res://Scenes/CardHand.tscn")

func _ready():
	# 1. FORZAR TAMAÑO DEL CONTENEDOR PRINCIPAL
	# Aseguramos que el VBox ocupe toda la pantalla disponible
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 2. FORZAR ESTIRAMIENTO DEL CENTRO
	# Esto obliga al CenterContainer a "empujar" hacia abajo y ocupar el aire
	center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 3. AJUSTAR LA MANO
	# Evitamos que la mano crezca para que el tablero sea el que se centre
	hand_container.size_flags_vertical = Control.SIZE_SHRINK_END
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Limpieza de seguridad
	for c in grid.get_children(): c.queue_free()
	for c in hand_container.get_children(): c.queue_free()
	
	setup_board()
	repartir_mano_inicial()

func setup_board():
	grid.columns = 10
	# Espaciado para que no se vea amontonado
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	
	var board_layout = BoardData.BOARD_MAP
	for row in board_layout:
		for card_id in row:
			var new_slot = slot_scene.instantiate()
			grid.add_child(new_slot)
			
			# Tamaño balanceado para centrado visual
			new_slot.custom_minimum_size = Vector2(75, 110) 
			
			if new_slot.has_node("Label"):
				var lb = new_slot.get_node("Label")
				lb.text = card_id
				lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			new_slot.color = Color(0.15, 0.45, 0.15) if card_id == "FREE" else Color(0.1, 0.1, 0.1)

func repartir_mano_inicial():
	for i in range(7):
		var card_id = GameManager.draw_card()
		if card_id:
			var new_card = card_hand_scene.instantiate()
			hand_container.add_child(new_card)
			hand_container.add_theme_constant_override("separation", 15)
			new_card.custom_minimum_size = Vector2(90, 130)
			if new_card.has_method("setup"):
				new_card.setup(card_id)
