extends ColorRect

func _ready():
	# Ponemos el color inicial (Negro/Gris muy oscuro)
	color = Color(0.1, 0.1, 0.1)
	# Si es una esquina, la pintamos de verde
	if get_node("Label").text == "FREE":
		color = Color(0.15, 0.45, 0.15)

func _on_mouse_entered():
	# EFECTO BALATRO: Se infla y brilla
	var tween = create_tween()
	# Escala a 1.1 (110%) en 0.1 segundos
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	# Lo resaltamos con un color azulado
	color = Color(0.2, 0.2, 0.5)
	z_index = 1 # Para que se vea por encima de los vecinos

func _on_mouse_exited():
	# Vuelve a la normalidad
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	# Restaurar color original
	if get_node("Label").text == "FREE":
		color = Color(0.15, 0.45, 0.15)
	else:
		color = Color(0.1, 0.1, 0.1)
	z_index = 0
