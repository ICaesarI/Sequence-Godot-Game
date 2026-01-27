extends Control

signal slot_clicked(slot_node)

@onready var bg: ColorRect = $BG
@onready var face: TextureRect = $CardFace
@onready var debug_label: Label = $Label
@onready var chip_layer: Control = $ChipLayer

const CHIP_P1 := preload("res://Assets/Chips/chips_flat_blue.png")
const CHIP_P2 := preload("res://Assets/Chips/chips_flat_red.png")

var card_id: String = ""
var occupied_by: String = ""
var is_playable: bool = false
var is_free := false

# --- Animacion  ---
var highlight_tween: Tween # Variable para controlar la animación del highlight
var hover_tween: Tween
var seq_tween: Tween

# --- Color base ---
var base_color: Color

func _ready():
	pivot_offset = custom_minimum_size / 2
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# estos NO deben capturar clicks
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Guardamos el color original del slot (el fondo)
	base_color = bg.color
	bg.color.a = 0.75
	
	# --- Conexiones ---
	gui_input.connect(_on_gui_input)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("slot_clicked", self)

# --- Assets ---
func setup(id: String):
	card_id = id
	var tex := CardAssets.get_face(card_id)
	if tex:
		face.texture = tex
		debug_label.text = ""
	else:
		debug_label.text = id

# --- Cambiar color base ---
func set_base_color(c: Color, free_slot := false) -> void:
	base_color = c
	is_free = free_slot
	bg.color = c

# --- Highlight ----
func set_highlight(active: bool):
	if highlight_tween:
		highlight_tween.kill()
	
	if active:
		face.modulate = Color.WHITE
		highlight_tween = create_tween().set_loops()
		# Animación de pulso
		highlight_tween.tween_property(face, "modulate", Color(0.5, 0.5, 0.5), 0.7).set_trans(Tween.TRANS_SINE)
		highlight_tween.tween_property(face, "modulate", Color.DIM_GRAY, 0.7).set_trans(Tween.TRANS_SINE)
	else:
		# Reset total al estado original
		face.modulate = Color.WHITE
		z_index = 1

# --- FUNCION PARA COLOCAR FICHA  ---
func colocar_ficha(_color_ficha: Color, player_id: String) -> void:
	occupied_by = player_id
	
	# Oscurecer fondo al estar ocupada
	bg.color = Color(0.0, 0.0, 0.0, 0.90)	
	# Borrar chip anterior si existía
	var old_chip := chip_layer.get_node_or_null("Chip")
	if old_chip:
		old_chip.queue_free()

	# Crear chip como imagen
	var chip := TextureRect.new()
	chip.name = "Chip"
	chip.texture = CHIP_P1 if player_id == "p1" else CHIP_P2
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	chip.modulate = Color(1.2, 1.2, 1.2, 1.0)

	# Tamaño relativo al slot
	var d: float = minf(size.x, size.y) * 0.85 
	chip.custom_minimum_size = Vector2(d, d)

	# Centrar
	chip.position = (size - chip.custom_minimum_size) / 2.0
	chip_layer.add_child(chip)

	# animación spawn
	chip.scale = Vector2.ZERO
	var t := create_tween()
	t.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT) 
	t.tween_property(chip, "scale", Vector2.ONE, 0.4)

func quitar_ficha() -> void:
	occupied_by = ""
	var chip := chip_layer.get_node_or_null("Chip")
	if chip:
		chip.queue_free()
	restore_base()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		var chip := chip_layer.get_node_or_null("Chip") as Control
		if chip:
			chip.position = (size - chip.custom_minimum_size) / 2.0

func set_playable(state: bool) -> void:
	is_playable = state


# --- ANIMACION MOUSE ---
func _on_mouse_entered():
	_kill_hover_tween()

	# Si NO es jugable, hover muy leve (o nada)
	if not is_playable:
		z_index = 2
		hover_tween = create_tween()
		hover_tween.tween_property(self, "self_modulate", Color(0.95, 0.95, 0.95), 0.1)
	else:
		# Si es jugable, hover fuerte
		z_index = 10
		hover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hover_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.15)
		hover_tween.parallel().tween_property(self, "self_modulate", Color(1.2, 1.2, 1.2), 0.10)


func _on_mouse_exited():
	_kill_hover_tween()

	z_index = 1
	hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.10)

func play_sequence_anim(delay: float = 0.0) -> void:
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	# Evita que se acumulen animaciones
	if seq_tween:
		seq_tween.kill()
	# Subimos prioridad visual momentánea
	z_index = 20
	
	var color_gold = Color(1.5, 1.2, 0.2, 1.0)
	var bg_locked = Color(0.3, 0.25, 0.1, 0.9)
	
	seq_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	seq_tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.25)
	seq_tween.parallel().tween_property(self, "self_modulate", color_gold, 0.2)
	
	seq_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.3)
	seq_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.3)
	
	
	bg.color = bg_locked
	
	seq_tween.finished.connect(func(): 
		z_index = 1
		)

func restore_base() -> void:
	bg.color = base_color
	self_modulate = Color.WHITE
	face.modulate = Color.WHITE
	scale = Vector2.ONE

func _kill_hover_tween():
	if hover_tween:
		hover_tween.kill()
		hover_tween = null
