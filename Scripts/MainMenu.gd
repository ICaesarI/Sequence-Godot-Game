extends Control

# Referencias seguras
@onready var btn_2 = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/HBoxContainer/Btn2Players
@onready var btn_3 = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/HBoxContainer/Btn3Players
@onready var btn_exit = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/BtnExit

const GAME_SCENE_PATH = "res://Scenes/Main.tscn"

func _ready():
	print("--- MENÚ CARGADO (ESPERANDO INPUT) ---")
	
	# Verificación de seguridad
	if not btn_2:
		return

	# Conexión manual y segura
	if not btn_2.pressed.is_connected(_on_2_players_pressed):
		btn_2.pressed.connect(_on_2_players_pressed)
	
	if not btn_3.pressed.is_connected(_on_3_players_pressed):
		btn_3.pressed.connect(_on_3_players_pressed)
		
	if not btn_exit.pressed.is_connected(_on_exit_pressed):
		btn_exit.pressed.connect(_on_exit_pressed)

func _on_2_players_pressed():
	print("¡CLICK DETECTADO! -> 2 Jugadores")
	iniciar_partida(2)

func _on_3_players_pressed():
	print("¡CLICK DETECTADO! -> 3 Jugadores")
	iniciar_partida(9)

func iniciar_partida(n):
	print("Configurando GameManager...")
	GameManager.setup_game(n)
	print("Cambiando escena...")
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_exit_pressed():
	get_tree().quit()
