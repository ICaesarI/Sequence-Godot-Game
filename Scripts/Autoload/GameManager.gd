extends Node

# --- VARIABLES DE ESTADO ---
var cards = []
var turno_actual: int = 1 

# Manos privadas de cada jugador
var mano_p1: Array = []
var mano_p2: Array = []

# --- INICIALIZACIÓN ---
func _ready():
	
	generate_deck()
	shuffle_deck()
"""
func generate_deck():
	cards.clear()
	var suits = ["S", "C", "D", "H"]
	
	var values = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "Q", "K", "A"]
	
	for i in range(2): 
		for s in suits:
			for v in values:
				cards.append(s + "_" + v)
			
			# J1 = Jota de un ojo (Quitar ficha)
			# J2 = Jota de dos ojos (Comodín / Poner en cualquier lugar)
			cards.append(s + "_J1")
			cards.append(s + "_J2")
	print("Mazo generado con éxito. Total cartas: ", cards.size())
"""
#Prueba de Solo Jotos
func generate_deck():
	cards.clear()
	var suits = ["S", "C", "D", "H"]
	
	# --- PRUEBA CON SOLO JOTAS ---
	for i in range(10): # Generamos 10 copias de cada una para no quedarnos sin cartas
		for s in suits:
			cards.append(s + "_J1") # Jota de 1 ojo (Quitar)
			cards.append(s + "_J2") # Jota de 2 ojos (Poner/Comodín)
	
	print("MAZO DE PRUEBA GENERADO: Solo Jotas. Total: ", cards.size())

func shuffle_deck():
	cards.shuffle()

# --- GESTIÓN DEL MAZO ---
func draw_card() -> String:
	if cards.size() > 0:
		return cards.pop_back()
	return ""

func get_deck_count() -> int:
	return cards.size()

# --- GESTIÓN DE MANOS ---
func agregar_a_mano(id_jugador: int, card_id: String):
	if card_id == "": return
	
	if id_jugador == 1:
		mano_p1.append(card_id)
	else:
		mano_p2.append(card_id)

func eliminar_de_mano(id_jugador: int, card_id: String):
	if id_jugador == 1:
		mano_p1.erase(card_id)
	else:
		mano_p2.erase(card_id)

func get_mano_actual() -> Array:
	return mano_p1 if turno_actual == 1 else mano_p2

# --- CONTROL DE FLUJO ---
func cambiar_turno():
	turno_actual = 2 if turno_actual == 1 else 1
	print("Cambio de turno realizado. Turno del Jugador: ", turno_actual)
