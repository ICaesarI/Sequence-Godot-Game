extends Control

@onready var btn_2 = find_child("Btn2Players", true, false)
@onready var btn_3 = find_child("Btn3Players", true, false)
@onready var btn_exit = find_child("BtnExit", true, false)
@onready var btn_options = find_child("BtnOptions", true, false)
@onready var options_panel = find_child("OptionsPanel", true, false)
@onready var menu_bg = find_child("TextureRect", true, false)

@onready var menu_panel = $CenterContainer/MenuPanel
@onready var lobby_panel = $CenterContainer/LobbyPanel
@onready var join_panel = %JoinPanel 
@onready var lbl_codigo_valor = $CenterContainer/LobbyPanel/VBoxContainer/LabelCodigoValor
@onready var player_name_input = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/HBoxContainer/PlayerNameInput
@onready var ip_input = %IPInput
@onready var lista_jugadores = %ListaJugadores

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

var bottom_container: HBoxContainer

func _ready():
	if btn_2: btn_2.pressed.connect(func(): iniciar_partida(2))
	if btn_3: btn_3.pressed.connect(func(): iniciar_partida(9))
	if btn_exit: btn_exit.pressed.connect(get_tree().quit)
	
	if btn_options and options_panel:
		btn_options.pressed.connect(func(): options_panel.visible = true)
		_setup_carrusel()

	var host_btn = find_child("HostButton", true, false)
	var join_btn = find_child("JoinButton", true, false)
	if host_btn: host_btn.pressed.connect(_on_host_button_pressed)
	if join_btn: join_btn.pressed.connect(_on_join_button_pressed)
	
	var confirm_join = find_child("ConfirmJoinButton", true, false)
	var cancel_join = find_child("CancelJoinButton", true, false)
	if confirm_join: confirm_join.pressed.connect(_on_confirm_join_button_pressed)
	if cancel_join: cancel_join.pressed.connect(_on_cancel_join_button_pressed)

	var btn_back_lobby = lobby_panel.find_child("CancelHostButton", true, false)
	if btn_back_lobby:
		btn_back_lobby.pressed.connect(_on_back_from_lobby_pressed)
	
	if is_instance_valid(MultiplayerManager):
		if not MultiplayerManager.player_list_changed.is_connected(_actualizar_lista_visual_jugadores):
			MultiplayerManager.player_list_changed.connect(_actualizar_lista_visual_jugadores)
		MultiplayerManager.start_listening()
	else:
		push_error("MultiplayerManager no encontrado. Revisa tus Autoloads.")
		
	_setup_photo_roulette_ui()
	

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
		if bottom_container: bottom_container.hide()
		lobby_panel.show()
		_actualizar_lista_visual_jugadores()

func _on_join_button_pressed():
	var nombre = player_name_input.text.strip_edges().to_upper()
	if nombre == "":
		_marcar_error_nombre()
		return
	
	menu_panel.hide()
	if bottom_container: bottom_container.hide()
	
	var lbl_join = join_panel.find_child("Label", true, false)
	if lbl_join: lbl_join.visible = false
	ip_input.placeholder_text = "CÓDIGO DE SALA..."
	
	join_panel.show()

func _on_confirm_join_button_pressed():
	var nombre = player_name_input.text.strip_edges().to_upper()
	var codigo = ip_input.text.strip_edges().to_upper()
	
	if nombre == "" or codigo == "":
		_marcar_error_nombre()
		return
	
	if is_instance_valid(MultiplayerManager):
		var ip_encontrada = MultiplayerManager.discovered_rooms.get(codigo, "")
		
		if ip_encontrada == "":
			ip_input.text = ""
			ip_input.placeholder_text = "¡CÓDIGO NO ENCONTRADO EN RED!"
			var original_color = ip_input.modulate
			ip_input.modulate = Color.RED
			await get_tree().create_timer(1.5).timeout
			ip_input.modulate = original_color
			ip_input.placeholder_text = "Código de Sala"
			return
			
		MultiplayerManager.stop_listening()
		MultiplayerManager.join_game(nombre, ip_encontrada, codigo)
		
		join_panel.hide()
		lobby_panel.show()
		lbl_codigo_valor.text = "Validando sala..."
		
		if lista_jugadores: lista_jugadores.clear()

func _on_cancel_join_button_pressed():
	join_panel.hide()
	menu_panel.show()
	if bottom_container: bottom_container.show()

func _on_back_from_lobby_pressed():
	if is_instance_valid(MultiplayerManager):
		MultiplayerManager.stop_multiplayer()
		MultiplayerManager.start_listening() # ¡Volver a encender el radar!
	
	lobby_panel.hide()
	menu_panel.show()
	if bottom_container: bottom_container.show()
	
	if lista_jugadores:
		lista_jugadores.clear()

func _actualizar_lista_visual_jugadores():
	if lista_jugadores:
		lista_jugadores.clear()
		for id in MultiplayerManager.players:
			var nombre_jugador = MultiplayerManager.players[id]
			var item_text = nombre_jugador + ( " (Host)" if id == 1 else "" )
			lista_jugadores.add_item(item_text)
		
		var btn_start = lobby_panel.find_child("StartGameButton", true, false)
		if btn_start:
			var es_host = (multiplayer.get_unique_id() == 1)
			btn_start.visible = es_host
			
			if not btn_start.pressed.is_connected(_on_start_game_pressed):
				btn_start.pressed.connect(_on_start_game_pressed)


func generar_codigo_sala() -> String:
	var caracteres = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var res = ""
	for i in range(5):
		res += caracteres[randi() % caracteres.length()]
	return res

func _on_start_game_pressed():
	if multiplayer.is_server():
		var numero_de_jugadores = MultiplayerManager.players.size()
		print("Host iniciando partida con ", numero_de_jugadores, " jugadores.")
		
		MultiplayerManager.rpc("iniciar_partida_remota", numero_de_jugadores)

func _marcar_error_nombre():
	player_name_input.placeholder_text = "¡NOMBRE REQUERIDO!"
	var original_color = player_name_input.modulate
	player_name_input.modulate = Color.RED
	await get_tree().create_timer(1.0).timeout
	player_name_input.modulate = original_color

func iniciar_partida(n):
	GameManager.setup_game(n)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
	
func _setup_photo_roulette_ui():
	var f_bold = load("res://Assets/FuentesTexto/PixelOperator-Bold.ttf")
	var f_reg = load("res://Assets/FuentesTexto/PixelOperator.ttf")

	# 1. Quitar panel grisáceo central
	if menu_panel:
		menu_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	# 2. Configurar el título
	var title_label = find_child("Label", true, false)
	if title_label:
		if f_bold: title_label.add_theme_font_override("font", f_bold)
		title_label.add_theme_font_size_override("font_size", 95)
		title_label.add_theme_color_override("font_color", Color.WHITE)
		title_label.add_theme_color_override("font_outline_color", Color.BLACK)
		title_label.add_theme_constant_override("outline_size", 8)
	
	# 3. Estilo Píldora Blanca para Inputs (Name y Room Code)
	var pill_white = StyleBoxFlat.new()
	pill_white.bg_color = Color.WHITE
	pill_white.set_corner_radius_all(50)
	pill_white.content_margin_top = 15
	pill_white.content_margin_bottom = 15
	
	for input in [player_name_input, ip_input]:
		if input:
			if f_reg: input.add_theme_font_override("font", f_reg)
			input.add_theme_stylebox_override("normal", pill_white)
			input.add_theme_stylebox_override("focus", pill_white)
			input.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
			input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5))
			input.add_theme_font_size_override("font_size", 28)
			input.alignment = HORIZONTAL_ALIGNMENT_CENTER
			input.custom_minimum_size = Vector2(300, 60)
			
	# 4. Estilo Píldora Roja Intenso Principal (Crear y Unirse)
	var pill_red = StyleBoxFlat.new()
	pill_red.bg_color = Color("#e63946") # Frambuesa/Rojo
	pill_red.set_corner_radius_all(50)
	pill_red.content_margin_top = 18
	pill_red.content_margin_bottom = 18
	
	var pill_red_hover = pill_red.duplicate()
	pill_red_hover.bg_color = Color("#f05a66")
	
	var pill_red_pressed = pill_red.duplicate()
	pill_red_pressed.bg_color = Color("#bc2732")
	
	var m_btns = [
		find_child("HostButton", true, false), find_child("JoinButton", true, false),
		find_child("ConfirmJoinButton", true, false), find_child("CancelJoinButton", true, false),
		find_child("StartGameButton", true, false), find_child("CancelHostButton", true, false)
	]
	
	for btn in m_btns:
		if btn:
			if f_bold: btn.add_theme_font_override("font", f_bold)
			btn.add_theme_stylebox_override("normal", pill_red)
			btn.add_theme_stylebox_override("hover", pill_red_hover)
			btn.add_theme_stylebox_override("pressed", pill_red_pressed)
			btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			btn.add_theme_font_size_override("font_size", 38)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_outline_color", Color(0,0,0,0.4))
			btn.add_theme_constant_override("outline_size", 3)
			btn.custom_minimum_size = Vector2(300, 60)
			_conectar_animacion_rebote(btn)
			
	# 5. Mover y Estilizar Secundarios Abajo (Translúcidos)
	var pill_dark = StyleBoxFlat.new()
	pill_dark.bg_color = Color(0, 0, 0, 0.5)
	pill_dark.set_corner_radius_all(50)
	pill_dark.content_margin_top = 15
	pill_dark.content_margin_bottom = 15
	
	var pb_hover = pill_dark.duplicate()
	pb_hover.bg_color = Color(0, 0, 0, 0.7)
	
	var s_btns = [btn_2, btn_3, btn_options, btn_exit]
	
	bottom_container = HBoxContainer.new()
	bottom_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_container.add_theme_constant_override("separation", 20)
	add_child(bottom_container)
	# Pegardo abajo al medio
	bottom_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_KEEP_SIZE, 30)
	bottom_container.offset_top = -100
	bottom_container.offset_bottom = -40
	
	for btn in s_btns:
		if btn:
			btn.get_parent().remove_child(btn)
			bottom_container.add_child(btn)
			if f_reg: btn.add_theme_font_override("font", f_reg)
			btn.add_theme_stylebox_override("normal", pill_dark)
			btn.add_theme_stylebox_override("hover", pb_hover)
			btn.add_theme_stylebox_override("pressed", pill_dark)
			btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			btn.add_theme_font_size_override("font_size", 20)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_outline_color", Color(0,0,0, 0.4))
			btn.add_theme_constant_override("outline_size", 2)
			btn.custom_minimum_size = Vector2(130, 45)
			_conectar_animacion_rebote(btn)
			
	if btn_2: btn_2.text = "2P LOCAL"
	if btn_3: btn_3.text = "3P LOCAL"
	if btn_options: btn_options.text = "OPCIONES"
	
	# Ocultar basura visual
	for lbl_name in ["Label2", "HSeparator", "Control"]:
		var node = find_child(lbl_name, true, false)
		if node: node.visible = false
		
	# 6. Pulir Paneles de Lobby y Unirse
	if lista_jugadores:
		if f_reg: lista_jugadores.add_theme_font_override("font", f_reg)
		var pill_list = pill_dark.duplicate()
		pill_list.set_corner_radius_all(20)
		lista_jugadores.add_theme_stylebox_override("panel", pill_list)
		lista_jugadores.add_theme_color_override("font_color", Color.WHITE)
		lista_jugadores.add_theme_font_size_override("font_size", 30)
		lista_jugadores.add_theme_constant_override("v_separation", 15)
		
	if lobby_panel:
		var lbl_code_lbl = lobby_panel.find_child("Label", true, false)
		if lbl_code_lbl:
			if f_reg: lbl_code_lbl.add_theme_font_override("font", f_reg)
			lbl_code_lbl.add_theme_font_size_override("font_size", 26)
			lbl_code_lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl_code_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			lbl_code_lbl.add_theme_constant_override("outline_size", 4)
	
	if lbl_codigo_valor:
		if f_bold: lbl_codigo_valor.add_theme_font_override("font", f_bold)
		lbl_codigo_valor.add_theme_font_size_override("font_size", 75)
		lbl_codigo_valor.add_theme_color_override("font_color", Color("#e63946"))
		lbl_codigo_valor.add_theme_color_override("font_outline_color", Color.WHITE)
		lbl_codigo_valor.add_theme_constant_override("outline_size", 8)
		lbl_codigo_valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
	# 7. Separaciones de los Paneles Secundarios
	if join_panel:
		join_panel.add_theme_constant_override("separation", 20)
		join_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	if lobby_panel:
		var lobby_vbox = lobby_panel.get_child(0)
		if lobby_vbox and lobby_vbox is VBoxContainer:
			lobby_vbox.add_theme_constant_override("separation", 25)
			
	# 8. Pulir el Panel de Opciones
	if options_panel:
		var options_bg = StyleBoxFlat.new()
		options_bg.bg_color = Color(0.05, 0.05, 0.05, 0.95)
		options_bg.set_corner_radius_all(30)
		options_bg.content_margin_top = 20
		options_bg.content_margin_bottom = 20
		options_bg.content_margin_left = 30
		options_bg.content_margin_right = 30
		
		options_panel.add_theme_stylebox_override("panel", options_bg)
		options_panel.self_modulate = Color(1, 1, 1, 1) 
		
		var b_ant = options_panel.find_child("BtnAnterior", true, false)
		var b_sig = options_panel.find_child("BtnSiguiente", true, false)
		var b_cerrar = options_panel.find_child("BtnCerrar", true, false)
		var lbl_bg = options_panel.find_child("Label", true, false)
		var lbl_nf = options_panel.find_child("LblNombreFondo", true, false)
		var lbl_sf = options_panel.find_child("SELECCIONAR FONDO", true, false)
		
		if f_bold:
			if lbl_sf:
				lbl_sf.text = "AJUSTES GLOBALES"
				lbl_sf.add_theme_font_override("font", f_bold)
				lbl_sf.add_theme_font_size_override("font_size", 38)
				lbl_sf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if f_reg:
			if lbl_bg: 
				lbl_bg.text = "Tapete"
				lbl_bg.custom_minimum_size.x = 140
				lbl_bg.add_theme_font_override("font", f_reg)
				lbl_bg.add_theme_font_size_override("font_size", 28)
			if lbl_nf: 
				lbl_nf.add_theme_font_override("font", f_reg)
				lbl_nf.add_theme_font_size_override("font_size", 28)
				
		var sep = options_panel.find_child("HSeparator", true, false)
		if sep and sep.get_parent():
			var p_container = sep.get_parent()
			p_container.add_theme_constant_override("separation", 25)
			
			# --- Brillo ---
			var hb_brillo = HBoxContainer.new()
			var lbl_brillo = Label.new()
			lbl_brillo.text = "Brillo"
			lbl_brillo.custom_minimum_size.x = 140
			if f_reg: lbl_brillo.add_theme_font_override("font", f_reg)
			lbl_brillo.add_theme_font_size_override("font_size", 30)
			
			var slide_brillo = HSlider.new()
			slide_brillo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slide_brillo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slide_brillo.min_value = 0.1
			slide_brillo.max_value = 1.0
			slide_brillo.step = 0.05
			slide_brillo.value = GameManager.global_brightness
			slide_brillo.value_changed.connect(func(v): GameManager.set_brightness(v))
			
			hb_brillo.add_child(lbl_brillo)
			hb_brillo.add_child(slide_brillo)
			p_container.add_child(hb_brillo)
			p_container.move_child(hb_brillo, sep.get_index())
			
			# --- Volumen ---
			var hb_vol = HBoxContainer.new()
			var lbl_vol = Label.new()
			lbl_vol.text = "Volumen"
			lbl_vol.custom_minimum_size.x = 140
			if f_reg: lbl_vol.add_theme_font_override("font", f_reg)
			lbl_vol.add_theme_font_size_override("font_size", 30)
			
			var slide_vol = HSlider.new()
			slide_vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slide_vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slide_vol.min_value = 0.0
			slide_vol.max_value = 1.0
			slide_vol.step = 0.05
			slide_vol.value = GameManager.global_volume
			slide_vol.value_changed.connect(func(v): GameManager.set_volume(v))
			
			hb_vol.add_child(lbl_vol)
			hb_vol.add_child(slide_vol)
			p_container.add_child(hb_vol)
			p_container.move_child(hb_vol, sep.get_index())
		
		var btn_pill_pequeno = pill_red.duplicate()
		btn_pill_pequeno.content_margin_top = 5
		btn_pill_pequeno.content_margin_bottom = 5
		
		for obtn in [b_ant, b_sig, b_cerrar]:
			if obtn:
				if f_bold: obtn.add_theme_font_override("font", f_bold)
				obtn.add_theme_stylebox_override("normal", btn_pill_pequeno)
				obtn.add_theme_stylebox_override("hover", pill_red_hover)
				obtn.add_theme_stylebox_override("pressed", pill_red_pressed)
				obtn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
				obtn.add_theme_font_size_override("font_size", 26)
				obtn.add_theme_color_override("font_color", Color.WHITE)
				obtn.add_theme_constant_override("outline_size", 2)
				_conectar_animacion_rebote(obtn)
		
		if b_cerrar:
			b_cerrar.custom_minimum_size = Vector2(150, 45)
			b_cerrar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _conectar_animacion_rebote(btn: Button):
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.mouse_entered.connect(func():
		var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15)
	)
	btn.mouse_exited.connect(func():
		var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(btn, "scale", Vector2.ONE, 0.15)
	)
	btn.button_down.connect(func():
		var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)
	)
	btn.button_up.connect(func():
		var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15)
	)

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
