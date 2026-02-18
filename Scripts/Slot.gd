extends Control

signal slot_clicked(slot_node)

@onready var bg: ColorRect = $BG
@onready var face: TextureRect = $CardFace
@onready var debug_label: Label = $Label
@onready var chip_layer: Control = $ChipLayer

var card_id: String = ""
var occupied_by: String = ""
var is_playable: bool = false
var is_free := false

# --- Animación ---
var highlight_tween: Tween
var hover_tween: Tween
var seq_tween: Tween

# --- Configuración Visual ---
var base_color: Color
const CHIP_SCALE_RATIO = 0.85 # La ficha ocupará el 85% del slot

func _ready():
	# Pivote en el centro para que las escalas (zoom) se vean bien
	pivot_offset = size / 2
	
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Los hijos deben ignorar el mouse para que el Control padre (Slot) reciba el clic
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	base_color = bg.color
	bg.color.a = 0.75
	
	gui_input.connect(_on_gui_input)
	# Conexión segura de señales
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	# Asegurar pivote correcto si cambia el tamaño
	resized.connect(func(): pivot_offset = size / 2)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameManager.current_state == GameManager.GameState.PLAYER_TURN:
			emit_signal("slot_clicked", self)
		

# --- Configuración Inicial ---
func setup(id: String):
	card_id = id
	var tex := CardAssets.get_face(card_id)
	if tex:
		face.texture = tex
		debug_label.text = "" # Ocultar texto si hay imagen
	else:
		face.texture = null
		debug_label.text = id # Mostrar ID si falla la imagen

# --- Estado Base ---
func set_base_color(c: Color, free_slot := false) -> void:
	base_color = c
	is_free = free_slot
	bg.color = c

# --- Highlight (Indicar jugada válida) ---
func set_highlight(active: bool):
	if highlight_tween:
		highlight_tween.kill()
	
	if active:
		# Poner la carta por encima de las demás visualmente
		z_index = 5 
		face.modulate = Color.WHITE
		
		highlight_tween = create_tween().set_loops()
		highlight_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Pulso de color (De normal a verdoso/brillante)
		highlight_tween.tween_property(face, "modulate", Color(0.6, 0.6, 0.6), 0.7)
		highlight_tween.tween_property(face, "modulate", Color.WHITE, 0.6)
	else:
		z_index = 0
		face.modulate = Color.WHITE

# --- GESTIÓN DE FICHAS ---
func colocar_ficha(_color_ficha: Color, player_id: String) -> void:
	occupied_by = player_id
	
	# Oscurecer fondo para resaltar la ficha
	bg.color = Color(0.0, 0.0, 0.0, 0.9)
	
	# Limpieza preventiva
	var old_chip := chip_layer.get_node_or_null("Chip")
	if old_chip: old_chip.queue_free()

	# Crear Ficha
	var chip := TextureRect.new()
	chip.name = "Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var chip_tex = CardAssets.get_chip(player_id)
	if chip_tex:
		chip.texture = chip_tex
		# Un poco más brillante para que destaque del fondo oscuro
		chip.modulate = Color(1.1, 1.1, 1.1, 1.0) 
	else:
		chip.modulate = _color_ficha # Fallback por color

	chip_layer.add_child(chip)
	
	# Ajustar tamaño y posición inicial
	_update_chip_layout()

	# Animación de entrada (Pop)
	chip.scale = Vector2.ZERO
	chip.pivot_offset = chip.size / 2 # Pivote al centro de la ficha
	
	var t := create_tween()
	t.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(chip, "scale", Vector2.ONE, 0.5)

func quitar_ficha() -> void:
	occupied_by = ""
	var chip := chip_layer.get_node_or_null("Chip")
	if chip:
		# Animación de salida antes de borrar
		var t = create_tween()
		t.tween_property(chip, "scale", Vector2.ZERO, 0.2)
		t.finished.connect(chip.queue_free)
	
	restore_base()

# --- Responsive: Mantener ficha centrada y escalada ---
func _notification(what):
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2
		_update_chip_layout()

func _update_chip_layout():
	var chip = chip_layer.get_node_or_null("Chip")
	if chip:
		# Calculamos el tamaño basado en el lado más pequeño del slot
		var d: float = minf(size.x, size.y) * CHIP_SCALE_RATIO
		chip.custom_minimum_size = Vector2(d, d)
		chip.size = Vector2(d, d) # Forzar tamaño actual
		chip.position = (size - chip.size) / 2.0
		chip.pivot_offset = chip.size / 2

# --- Estados Lógicos ---
func set_playable(state: bool) -> void:
	is_playable = state
	
func set_locked_visual():
	# Visualmente indicar que esta ficha ya es parte de una secuencia (bloqueada)
	if chip_layer.get_child_count() > 0:
		var chip = chip_layer.get_child(0)
		# Le damos un tinte grisáceo o metálico
		chip.modulate = Color(0.7, 0.7, 0.7, 1.0) 

# --- INTERACCIÓN MOUSE (HOVER) ---
func _on_mouse_entered():
	_kill_hover_tween()

	if not is_playable:
		# Hover sutil para cartas no jugables
		z_index = 2
		hover_tween = create_tween()
		hover_tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.1)
	else:
		# Hover exagerado para cartas jugables
		z_index = 10
		hover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hover_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15)
		hover_tween.parallel().tween_property(self, "self_modulate", Color(1.1, 1.1, 1.1), 0.1)

func _on_mouse_exited():
	_kill_hover_tween()

	# Restaurar z_index dependiendo de si tiene highlight activo
	z_index = 5 if highlight_tween and highlight_tween.is_running() else 0
	
	hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	hover_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.1)

func _kill_hover_tween():
	if hover_tween:
		hover_tween.kill()
		hover_tween = null

# --- ANIMACIÓN DE SECUENCIA COMPLETADA ---
func play_sequence_anim(delay: float = 0.0) -> void:
	var team_to_anim = GameManager.get_current_team_id()
	
	if delay > 0:
		await get_tree().create_timer(delay).timeout
		
	if seq_tween: seq_tween.kill()
	
	z_index = 20 # Traer al frente
	
	# Color dorado brillante
	var bg_locked = Color(0.2, 0.15, 0.05, 0.95) # Fondo oscuro dorad
	
	# --- LÓGICA DE COLOR MODULAR ---
	
	var glow_color = Color.WHITE
	
	match team_to_anim:
		0: # EQUIPO AZUL (Usamos un Cian/Azul Eléctrico)
			glow_color = Color(0.8, 1.2, 2.0) 
		1: # EQUIPO ROJO (Usamos un Rojo Neón suave)
			glow_color = Color(2.0, 0.85, 0.85)
		2: # EQUIPO VERDE (Usamos un Verde Lima brillante)
			glow_color = Color(0.83, 1.763, 0.83, 0.925)
		_: # Fallback (Blanco brillante por si acaso)
			glow_color = Color(1.2, 1.2, 1.2)
	
	# Aplicamos el color dinámico
	
	seq_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 1. Escalar y Brillar
	seq_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.3)
	seq_tween.parallel().tween_property(self,  "modulate", glow_color, 0.2)
	
	# 2. Regresar y fijar color de fondo
	seq_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.4)
	seq_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.4)
	
	bg.color = bg_locked
	
	seq_tween.finished.connect(func(): z_index = 0)

func restore_base() -> void:
	bg.color = base_color
	self_modulate = Color.WHITE
	face.modulate = Color.WHITE
	scale = Vector2.ONE
