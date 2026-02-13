extends Control

@onready var btn_2 = find_child("Btn2Players", true, false)
@onready var btn_3 = find_child("Btn3Players", true, false)
@onready var btn_exit = find_child("BtnExit", true, false)
@onready var btn_options = find_child("BtnOptions", true, false)
@onready var options_panel = find_child("OptionsPanel", true, false)
@onready var menu_bg = find_child("TextureRect", true, false)

const GAME_SCENE_PATH = "res://Scenes/Main.tscn"

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
	if btn_2: btn_2.pressed.connect(func(): iniciar_partida(2))
	if btn_3: btn_3.pressed.connect(func(): iniciar_partida(9))
	if btn_exit: btn_exit.pressed.connect(get_tree().quit)
	
	if btn_options and options_panel:
		btn_options.pressed.connect(func(): options_panel.visible = true)
		_setup_carrusel()

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
	var ruta_elegida = lista_fondos[indice_actual]["ruta"] # Aquí estaba el error
	
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
	if fondo_temporal != "":
		GameManager.cambiar_fondo(fondo_temporal)
	options_panel.visible = false

func iniciar_partida(n):
	GameManager.setup_game(n)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
