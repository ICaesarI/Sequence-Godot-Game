extends Button

func setup(card_id: String):
	# Si tienes un Label hijo, esto le pone el nombre (ej. "S2")
	if has_node("Label"):
		$Label.text = card_id
	
	# OPCIONAL: Esto hace que el ID aparezca en el texto nativo del botón
	text = card_id
