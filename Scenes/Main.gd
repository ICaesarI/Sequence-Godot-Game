extends Node2D

var slot_scene = preload("res://Scenes/Slot.tscn")
@onready var grid = $GridContainer

func _ready():
	var board_layout = preload("res://Scripts/BoardData.gd").new().BOARD_MAP
	
	for row in board_layout:
		for card_id in row:
			var new_slot = slot_scene.instantiate()
			grid.add_child(new_slot)
			
			new_slot.get_node("Label").text = card_id
			
			if card_id == "FREE":
				new_slot.color = Color(0.15, 0.45, 0.15) # Verde oscuro / Casillas Libres
			else:
				new_slot.color = Color(0.1, 0.1, 0.1) # Negro Balatro / Casilla Generica
