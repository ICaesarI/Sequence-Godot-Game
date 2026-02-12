extends Control

# Buscamos todo por nombre para evitar errores de ruta
@onready var btn_2 = find_child("Btn2Players", true, false)
@onready var btn_3 = find_child("Btn3Players", true, false)
@onready var btn_exit = find_child("BtnExit", true, false)
@onready var btn_options = find_child("BtnOptions", true, false)
@onready var options_panel = find_child("OptionsPanel", true, false)

const GAME_SCENE_PATH = "res://Scenes/Main.tscn"

func _ready():
	print("--- MENÚ CARGADO ---")
	
	# Conexiones principales
	if btn_2: btn_2.pressed.connect(_on_2_players_pressed)
	if btn_3: btn_3.pressed.connect(_on_3_players_pressed)
	if btn_exit: btn_exit.pressed.connect(_on_exit_pressed)
	
	# Lógica del botón de opciones
	if btn_options and options_panel:
		btn_options.pressed.connect(func(): options_panel.visible = true)
		_conectar_botones_textura()
	else:
		print("ADVERTENCIA: No se encontró BtnOptions u OptionsPanel en la escena.")

func _conectar_botones_textura():
	# Buscamos los botones DENTRO del panel de opciones
	var btn_velvet = options_panel.find_child("BtnVelvet", true, false)
	if btn_velvet:
		btn_velvet.pressed.connect(func(): _aplicar_textura("res://Assets/Textures/velour_velvet_diff_4k.jpg"))
	
	var btn_denim = options_panel.find_child("BtnDenim", true, false)
	if btn_denim:
		btn_denim.pressed.connect(func(): _aplicar_textura("res://Assets/Textures/denim_fabric_06_diff_4k.jpg"))

# ESTA FUNCIÓN SOLO DEBE APARECER UNA VEZ (Línea 43 aprox)
func _aplicar_textura(path: String):
	if "background_texture_path" in GameManager:
		GameManager.background_texture_path = path
	options_panel.visible = false
	print("Fondo cambiado a: ", path)

func iniciar_partida(n):
	GameManager.setup_game(n)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_2_players_pressed(): iniciar_partida(2)
func _on_3_players_pressed(): iniciar_partida(9)
func _on_exit_pressed(): get_tree().quit()
