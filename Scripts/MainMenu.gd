extends Control

# Nodos Principales
@onready var btn_2 = find_child("Btn2Players", true, false)
@onready var btn_3 = find_child("Btn3Players", true, false)
@onready var btn_exit = find_child("BtnExit", true, false)
@onready var btn_options = find_child("BtnOptions", true, false)
@onready var options_panel = find_child("OptionsPanel", true, false)
@onready var menu_bg = find_child("TextureRect", true, false)

# Nodos de Contenedores (Usa % si activaste Unique Names)
@onready var menu_panel = $CenterContainer/MenuPanel
@onready var lobby_panel = $CenterContainer/LobbyPanel
@onready var join_panel = %JoinPanel # Panel intermedio para código/IP
@onready var lbl_codigo_valor = $CenterContainer/LobbyPanel/VBoxContainer/LabelCodigoValor
@onready var player_name_input = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/HBoxContainer/PlayerNameInput
@onready var ip_input = %IPInput
@onready var lista_jugadores = %ListaJugadores

const GAME_SCENE_PATH = "res://Scenes/Main.tscn"

# Configuración de Fondos
var lista_fondos = [
	{"nombre": "Terciopelo Rojo", "ruta": "res://Assets/Background/velour_velvet_diff_4k.jpg"},
	{"nombre": "Crepe Georgette", "ruta": "res://Assets/Background/crepe_georgette_diff_4k.jpg"},
	{"nombre": "Mezclilla Azul", "ruta": "res://Assets/Background/denim_fabric_06_diff_4k.jpg"},
	{"nombre": "Jacquard Quatrefoil", "ruta": "res://Assets/Background/quatrefoil_jacquard_fabric_diff_4k.jpg"},
	{"nombre": "Popelina Stretch", "ruta": "res://Assets/Background/stretch_poplin_diff_4k.jpg"}
]
var indice_actual = 0
var fondo_temporal = ""

func _ready():
	# 1. Botones de Juego Local e Interfaz Base
	if btn_2: btn_2.pressed.connect(func(): iniciar_partida(2))
	if btn_3: btn_3.pressed.connect(func(): iniciar_partida(9))
	if btn_exit: btn_exit.pressed.connect(get_tree().quit)
	
	if btn_options and options_panel:
		btn_options.pressed.connect(func(): options_panel.visible = true)
		_setup_carrusel()

	# 2. Botones de Red (Menú Principal)
	var host_btn = find_child("HostButton", true, false)
	var join_btn = find_child("JoinButton", true, false)
	if host_btn: host_btn.pressed.connect(_on_host_button_pressed)
	if join_btn: join_btn.pressed.connect(_on_join_button_pressed)
	
	# 3. Botones del JoinPanel (Confirmar/Cancelar)
	var confirm_join = find_child("ConfirmJoinButton", true, false)
	var cancel_join = find_child("CancelJoinButton", true, false)
	if confirm_join: confirm_join.pressed.connect(_on_confirm_join_button_pressed)
	if cancel_join: cancel_join.pressed.connect(_on_cancel_join_button_pressed)

	# 4. BOTÓN ATRÁS DEL LOBBY (Añade esto aquí)
	var btn_back_lobby = lobby_panel.find_child("CancelHostButton", true, false)
	if btn_back_lobby:
		btn_back_lobby.pressed.connect(_on_back_from_lobby_pressed)
	
	# 5. Conexión al Manager (Señales de Red)
	if is_instance_valid(MultiplayerManager):
		if not MultiplayerManager.player_list_changed.is_connected(_actualizar_lista_visual_jugadores):
			MultiplayerManager.player_list_changed.connect(_actualizar_lista_visual_jugadores)
	else:
		push_error("MultiplayerManager no encontrado. Revisa tus Autoloads.")
	
# --- LÓGICA DE RED Y FLUJO ---

func _on_host_button_pressed():
	var nombre = player_name_input.text.strip_edges().to_upper()
	if nombre == "":
		_marcar_error_nombre()
		return
	
	var nuevo_codigo = generar_codigo_sala()
	
	if is_instance_valid(MultiplayerManager):
		MultiplayerManager.host_game(nombre, nuevo_codigo)
		
		lbl_codigo_valor.text = nuevo_codigo
		menu_panel.hide()
		lobby_panel.show()
		_actualizar_lista_visual_jugadores()

func _on_join_button_pressed():
	# Al presionar Join en el menú, solo abrimos el panel para pedir IP/Código
	var nombre = player_name_input.text.strip_edges()
	if nombre == "":
		_marcar_error_nombre()
		return
	
	menu_panel.hide()
	join_panel.show()

func _on_confirm_join_button_pressed():
	var nombre = player_name_input.text.strip_edges()
	var codigo = ip_input.text.strip_edges().to_upper()
	
	if nombre == "" or codigo == "":
		_marcar_error_nombre()
		return
	
	if is_instance_valid(MultiplayerManager):
		MultiplayerManager.join_game(nombre, "127.0.0.1", codigo)
		
		join_panel.hide()
		lobby_panel.show()
		lbl_codigo_valor.text = "Validando sala..."
		
		if lista_jugadores: lista_jugadores.clear()
		

func _on_cancel_join_button_pressed():
	join_panel.hide()
	menu_panel.show()

func _on_back_from_lobby_pressed():
	if is_instance_valid(MultiplayerManager):
		MultiplayerManager.stop_multiplayer()
	
	lobby_panel.hide()
	menu_panel.show()
	
	if lista_jugadores:
		lista_jugadores.clear()

func _actualizar_lista_visual_jugadores():
	if lista_jugadores:
		lista_jugadores.clear()
		for id in MultiplayerManager.players:
			var nombre_jugador = MultiplayerManager.players[id]
			var item_text = nombre_jugador + ( " (Host)" if id == 1 else "" )
			lista_jugadores.add_item(item_text)
	else:
		print("Error: No se encontró el nodo ListaJugadores")

# --- FUNCIONES DE SOPORTE ---

func generar_codigo_sala() -> String:
	var caracteres = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var res = ""
	for i in range(5):
		res += caracteres[randi() % caracteres.length()]
	return res

func _marcar_error_nombre():
	player_name_input.placeholder_text = "¡NOMBRE REQUERIDO!"
	var original_color = player_name_input.modulate
	player_name_input.modulate = Color.RED
	await get_tree().create_timer(1.0).timeout
	player_name_input.modulate = original_color

func iniciar_partida(n):
	GameManager.setup_game(n)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

# --- CARRUSEL DE OPCIONES ---

func _setup_carrusel():
	var b_ant = options_panel.find_child("BtnAnterior", true, false)
	var b_sig = options_panel.find_child("BtnSiguiente", true, false)
	var b_guardar = options_panel.find_child("BtnGuardar", true, false)
	var b_cerrar = options_panel.find_child("BtnCerrar", true, false)

	if b_ant: b_ant.pressed.connect(func(): _navegar(-1))
	if b_sig: b_sig.pressed.connect(func(): _navegar(1))
	if b_guardar: b_guardar.pressed.connect(_confirmar_seleccion)
	if b_cerrar: b_cerrar.pressed.connect(func(): options_panel.visible = false)
	_actualizar_interfaz()

func _navegar(dir):
	indice_actual = wrap(indice_actual + dir, 0, lista_fondos.size())
	var ruta_elegida = lista_fondos[indice_actual]["ruta"]
	_actualizar_interfaz()
	_previsualizar(ruta_elegida)
	GameManager.cambiar_fondo(ruta_elegida)

func _actualizar_interfaz():
	var lbl = options_panel.find_child("LblNombreFondo", true, false)
	if lbl: lbl.text = lista_fondos[indice_actual]["nombre"]

func _previsualizar(path):
	if menu_bg:
		menu_bg.texture = load(path)
		menu_bg.stretch_mode = TextureRect.STRETCH_TILE

func _confirmar_seleccion():
	options_panel.visible = false
