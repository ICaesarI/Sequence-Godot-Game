extends Node

# --- VARIABLES DE ESTADO ---
var cards = []            # Mazo para robar
var discard_pile = []     # Pila de descarte

# Array de diccionarios: { "id": int, "name": String, "team": int, "hand": Array }
var players: Array = []

var current_player_index: int = 0  # Índice del jugador actual
var total_teams_in_play: int = 2   # 2 o 3 equipos


signal fondo_cambiado(nueva_ruta) # Avisa a las escenas que el fondo cambió
var background_texture_path: String = ""

# --- SISTEMA DE SKINS / COLORES (NUEVO) ---
# Aquí se guardan los colores actuales. Modifícalos para cambiar skins.
var team_colors = {
	0: Color.DODGER_BLUE,  # Equipo 0 (Azul Clásico)
	1: Color.INDIAN_RED,   # Equipo 1 (Rojo Clásico)
	2: Color.FOREST_GREEN  # Equipo 2 (Verde Clásico)
}

# --- MÁQUINA DE ESTADOS ---
enum GameState { SETUP, PLAYER_TURN, ANIMATING, CHECKING_WIN, GAME_OVER }
var current_state: GameState = GameState.SETUP

# Señal para avisar a Main.gd que el estado cambió
signal state_changed(new_state)

func change_state(new_state: GameState):
	current_state = new_state
	state_changed.emit(new_state)
	print("Estado cambiado a: ", GameState.keys()[new_state])

# --- INICIALIZACIÓN ---
func _ready():
	if not multiplayer.has_multiplayer_peer():
		print("Iniciando en modo local por defecto...")
	else:
		print("Esperando señal del servidor para iniciar...")
	
func cambiar_fondo(ruta: String):
	background_texture_path = ruta
	fondo_cambiado.emit(ruta) # Emitimos la señal
	
func setup_game(num_players: int):
	# ESCUDO: Si ya hay jugadores en el array (cargados por red), 
	# abortamos esta función para no sobrescribir los nombres reales.
	if players.size() > 0 and multiplayer.has_multiplayer_peer():
		print("DEBUG: Bloqueado inicio local accidental. Ya existe una sesión de red.")
		return

	players.clear()
	discard_pile.clear()
	cards.clear()
	current_player_index = 0
	print("DEBUG: Iniciando MODO LOCAL")
	
	# Regla oficial Sequence: Divisible por 3 -> 3 Equipos. Si no -> 2 Equipos.
	if num_players % 3 == 0:
		total_teams_in_play = 3
	else:
		total_teams_in_play = 2
		
	# Crear Jugadores y asignar Equipos cíclicamente
	for i in range(num_players):
		var assigned_team = i % total_teams_in_play 
		
		var new_player = {
			"id": i,
			"name": "JUGADOR " + str(i + 1), # Nombre por defecto para local
			"team": assigned_team,
			"hand": [],
			"net_id": 1 # ID por defecto para autoridad local
		}
		players.append(new_player)
	
	print("--- NUEVA PARTIDA LOCAL --- Jugadores: ", num_players, " | Equipos: ", total_teams_in_play)
	
	generate_deck()
	shuffle_deck()
	change_state(GameState.PLAYER_TURN)
	print("Juego listo. Turno de: ", get_current_player_name())

# --- GESTIÓN DE COLORES (SKINS) ---
func get_team_color(team_id: int) -> Color:
	return team_colors.get(team_id, Color.WHITE)

func set_team_color(team_id: int, new_color: Color):
	if team_colors.has(team_id):
		team_colors[team_id] = new_color

# --- GENERACIÓN DEL MAZO (REAL) ---
'''
func generate_deck():
	cards.clear()
	var suits = ["S", "C", "D", "H"]
	var values = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "Q", "K", "A"]
	
	# Generamos 2 barajas completas (104 cartas)
	for i in range(2): 
		for s in suits:
			for v in values:
				cards.append(s + "_" + v)
			
			# Jotas: S y C = 1 ojo (J1), H y D = 2 ojos (J2)
			if s == "S" or s == "C":
				cards.append(s + "_J1")
			else:
				cards.append(s + "_J2")
				
	print("Mazo generado. Total: ", cards.size())
'''
func generate_deck():
	cards.clear()
	var suits = ["S", "C", "D", "H"]
	
	# Generamos 5 copias de cada Jota para tener muchas manos
	for i in range(26): 
		for s in suits:
			# Jota de 1 Ojo (Spades/Clubs) -> Quitar
			#if s == "S" or s == "C":
				#cards.append(s + "_J1")
			# Jota de 2 Ojos (Hearts/Diamonds) -> Poner (Comodín)
			#else:
			cards.append(s + "_J2")
				
	print("!!! ALERTA: MODO DEBUG (SOLO JOTAS) !!! Cartas: ", cards.size())

func shuffle_deck():
	cards.shuffle()
	
# --- GESTIÓN DE CARTAS ---
func draw_card() -> String:
	if cards.size() == 0:
		reciclar_descarte()
	
	if cards.size() > 0:
		return cards.pop_back()
	return ""

func reciclar_descarte():
	print("Mazo agotado. Reciclando descarte...")
	if discard_pile.size() == 0:
		print("¡ERROR! No hay cartas.")
		return
	cards = discard_pile.duplicate()
	discard_pile.clear()
	shuffle_deck()

# --- GESTIÓN DE MANOS ---
func agregar_a_mano(player_index: int, card_id: String):
	if card_id == "" or player_index >= players.size(): return
	players[player_index]["hand"].append(card_id)

func eliminar_de_mano(player_index: int, card_id: String):
	if player_index >= players.size(): return
	var p_hand = players[player_index]["hand"]
	if card_id in p_hand:
		p_hand.erase(card_id)
		discard_pile.append(card_id) 
func get_mano_actual() -> Array:
	# SI NO HAY JUGADORES (Cargando red o error)
	if players.is_empty():
		return [] 
	
	# SI EL ÍNDICE ES INVÁLIDO POR ALGUNA RAZÓN
	if current_player_index >= players.size():
		return []
		
	return players[current_player_index]["hand"]

# --- INFORMACIÓN ---
# --- INFORMACIÓN (REPARADO) ---
func get_current_player_data() -> Dictionary:
	if players.size() == 0:
		return {"id": -1, "name": "Cargando...", "team": 0, "hand": []}
	return players[current_player_index]

func get_current_player_name() -> String:
	if players.size() == 0: 
		return "Esperando..."
	return players[current_player_index]["name"]

func get_current_team_id() -> int:
	if players.size() == 0: 
		return 0
	return players[current_player_index]["team"]

func get_deck_count() -> int:
	return cards.size()

# --- TURNOS ---
func cambiar_turno():
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		ejecutar_cambio_turno_remoto.rpc()
	elif not multiplayer.has_multiplayer_peer():
		_logica_interna_cambio_turno()

@rpc("authority", "reliable", "call_local")
func ejecutar_cambio_turno_remoto():
	_logica_interna_cambio_turno()

func _logica_interna_cambio_turno():
	if players.size() == 0:
		print("ERROR: Intento de cambio de turno sin jugadores cargados.")
		return

	current_state = GameState.ANIMATING 
	
	current_player_index = (current_player_index + 1) % players.size()
	
	var p = get_current_player_data()
	print("Nuevo Turno Sincronizado: ", p.name)
	change_state(GameState.PLAYER_TURN)


# --- LÓGICA EXCLUSIVA PARA RED ---

func preparar_partida_red(diccionario_jugadores: Dictionary):
	if not multiplayer.is_server(): return
	
	# El servidor le dice a TODOS (incluyéndose a sí mismo) que registren a los jugadores
	registrar_jugadores_en_todos_los_peers.rpc(diccionario_jugadores)

@rpc("authority", "reliable", "call_local")
func registrar_jugadores_en_todos_los_peers(diccionario_jugadores: Dictionary):
	print("Recibiendo diccionario de jugadores por RPC...")
	players.clear()
	current_player_index = 0
	
	var ids_ordenados = diccionario_jugadores.keys()
	ids_ordenados.sort()
	
	total_teams_in_play = 3 if ids_ordenados.size() % 3 == 0 else 2
	
	for i in range(ids_ordenados.size()):
		var net_id = ids_ordenados[i]
		players.append({
			"id": i,
			"net_id": net_id,
			"name": diccionario_jugadores[net_id],
			"team": i % total_teams_in_play,
			"hand": []
		})
	
	print("REGISTRO COMPLETO: Jugadores listos en este peer: ", players.size())
	
	# Solo después de que todos registraron, el servidor manda el mazo
	if multiplayer.is_server():
		generate_deck()
		shuffle_deck()
		activar_juego_remoto.rpc(cards)

@rpc("authority", "reliable", "call_local")
func activar_juego_remoto(mazo_servidor):
	cards = mazo_servidor
	print("Juego Activado. Mazo recibido. Mi ID es: ", multiplayer.get_unique_id())
	change_state(GameState.PLAYER_TURN)

@rpc("authority", "reliable", "call_local")
func sincronizar_y_comenzar(mazo_servidor):
	cards = mazo_servidor
	current_player_index = 0
	change_state(GameState.PLAYER_TURN)
	print("Cliente: Mazo recibido. Jugadores listos: ", players.size())
