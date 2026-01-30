extends Node

enum Teams { BLUE, RED, GREEN }

# --- VARIABLES DE ESTADO ---
var cards = []           # Mazo para robar
var discard_pile = []    # Pila de descarte

# Array de diccionarios. Cada elemento es un jugador:
# { "id": int, "name": String, "team": int, "hand": Array }
var players: Array = []

var current_player_index: int = 0  # Índice (0 a N) del jugador actual en el array
var total_teams_in_play: int = 2   # Cuántos equipos hay en esta partida (2 o 3)

# --- INICIALIZACIÓN ---
func _ready():
	pass
	#setup_game(2)

func setup_game(num_players: int):
	# 1. Limpieza
	players.clear()
	discard_pile.clear()
	cards.clear()
	current_player_index = 0
	
	# 2. Determinar número de equipos (Regla oficial Sequence)
	# Si el número de jugadores es divisible por 3 (3, 6, 9, 12), usamos 3 equipos.
	# En cualquier otro caso (2, 4, 8, 10), usamos 2 equipos.
	if num_players % 3 == 0:
		total_teams_in_play = 3
	else:
		total_teams_in_play = 2
		
	# 3. Crear Jugadores y asignar Equipos cíclicamente
	for i in range(num_players):
		var assigned_team = i % total_teams_in_play # 0, 1, 0, 1... o 0, 1, 2, 0...
		
		var new_player = {
			"id": i,
			"name": "JUGADOR " + str(i + 1),
			"team": assigned_team,
			"hand": []
		}
		players.append(new_player)
	
	print("--- NUEVA PARTIDA CONFIGURADA ---")
	print("Jugadores: ", num_players)
	print("Equipos: ", total_teams_in_play)
	
	# 4. Generar y barajar mazo
	generate_deck()
	shuffle_deck()
	

# --- FUNCIÓN DE PRUEBA: SOLO JOTAS ---
func generate_deck():
	cards.clear()
	var suits = ["S", "C", "D", "H"]
	
	# Generamos muchas copias de Jotas para pruebas de lógica
	for i in range(10): 
		for s in suits:
			# Jota de 1 ojo (Quitar ficha del rival)
			# cards.append(s + "_J1") 
			# Jota de 2 ojos (Comodín / Poner donde sea)
			cards.append(s + "_J2")
	
	print("MAZO DE PRUEBA GENERADO: Solo Jotas. Total: ", cards.size())
"""
# --- GENERACIÓN DEL MAZO (Lógica Real) ---
func generate_deck():
	cards.clear()
	var suits = ["S", "C", "D", "H"]
	var values = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "Q", "K", "A"]
	
	# Generamos exactamente 2 barajas completas (104 cartas)
	for i in range(2): 
		for s in suits:
			# Cartas normales
			for v in values:
				cards.append(s + "_" + v)
			
			# Jotas (Regla Sequence: 2 de cada tipo por mazo)
			# S y C = 1 ojo (Quitar), H y D = 2 ojos (Comodín)
			if s == "S" or s == "C":
				cards.append(s + "_J1")
			else:
				cards.append(s + "_J2")
				
	print("Mazo generado con éxito (2 barajas). Total: ", cards.size())
"""
func shuffle_deck():
	cards.shuffle()
	
# --- GESTIÓN DE CARTAS ---
func draw_card() -> String:
	# Si el mazo se acaba, reciclamos el descarte
	if cards.size() == 0:
		reciclar_descarte()
	
	if cards.size() > 0:
		return cards.pop_back()
	
	return ""

func reciclar_descarte():
	print("Mazo agotado. Reciclando pila de descarte...")
	if discard_pile.size() == 0:
		print("¡ERROR CRÍTICO! No hay cartas ni en el mazo ni en el descarte.")
		return
		
	# Pasamos el descarte al mazo principal
	cards = discard_pile.duplicate()
	discard_pile.clear()
	shuffle_deck()
	print("Mazo reciclado con ", cards.size(), " cartas.")


# --- GESTIÓN DE MANOS (SISTEMA DE ARRAY) ---
# Agrega carta al jugador indicado (por ID de jugador, no equipo)
func agregar_a_mano(player_index: int, card_id: String):
	if card_id == "" or player_index >= players.size(): return
	players[player_index]["hand"].append(card_id)

# Quita carta de la mano y la manda al descarte
func eliminar_de_mano(player_index: int, card_id: String):
	if player_index >= players.size(): return
	
	var p_hand = players[player_index]["hand"]
	if card_id in p_hand:
		p_hand.erase(card_id)
		discard_pile.append(card_id) # ¡Al descarte!

# Obtiene la mano del jugador que tiene el turno actual
func get_mano_actual() -> Array:
	return players[current_player_index]["hand"]

# --- INFORMACIÓN DEL JUGADOR ACTUAL ---
# Estas funciones ayudan a Main.gd a saber quién juega sin calcular nada

func get_current_player_data() -> Dictionary:
	return players[current_player_index]

func get_current_team_id() -> int:
	return players[current_player_index]["team"]

func get_current_player_name() -> String:
	return players[current_player_index]["name"]

func get_deck_count() -> int:
	return cards.size()

# --- CONTROL DE TURNOS ---
func cambiar_turno():
	# Avanzamos el índice. El operador módulo (%) hace que rote infinitamente
	# 0 -> 1 -> 2 -> 0 -> 1...
	current_player_index = (current_player_index + 1) % players.size()
	
	var p = get_current_player_data()
	print("Nuevo Turno: ", p.name, " (Equipo ", p.team, ")")
