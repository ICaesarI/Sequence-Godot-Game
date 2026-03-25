extends PanelContainer

# find_child evita los errores de "Node not found" si moviste las carpetas
@onready var lbl_count = find_child("Lbl_Count", true, false)
@onready var discard_texture = find_child("TextureRect", true, false)

func _ready():
	self.show()
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Esto quita el fondo negro/gris que causa la franja visual
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func actualizar_mazo(cartas_restantes: int, id_carta: String):
	if lbl_count:
		lbl_count.text = "RESTAN: " + str(cartas_restantes)
	
	if discard_texture:
		# Cargamos tu atlas de cartas
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = load("res://Assets/Cards/cards_atlas.png")
		
		# Recorte de prueba: Mostramos la primera carta (81x117 px)
		atlas_tex.region = Rect2(0, 0, 81, 117) 
		
		discard_texture.texture = atlas_tex
		discard_texture.custom_minimum_size = Vector2(100, 140) # Obligamos a que tenga tamaño
		discard_texture.show()

func configurar_layout(_es_movil: bool):
	# Esto asegura que el panel no colapse al cambiar de pantalla
	self.custom_minimum_size = Vector2(180, 250)
