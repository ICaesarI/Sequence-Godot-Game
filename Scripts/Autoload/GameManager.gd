extends Node

# --- VARIABLES DE ESTADO ---
var cards = []           # Mazo para robar
var discard_pile = []    # Pila de descarte
var turno_actual: int = 1 

# Manos privadas de cada jugador
var mano_p1: Array = []
var mano_p2: Array = []

# --- INICIALIZACIÓN ---
func _ready():
	reiniciar_juego()

func reiniciar_juego():
	mano_p1.clear()
	mano_p2.clear()
	discard_pile.clear()
	generate_deck()
	shuffle_deck()

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

func shuffle_deck():
	cards.shuffle()

# --- GESTIÓN DEL MAZO ---
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

# --- GESTIÓN DE MANOS Y DESCARTE ---
func agregar_a_mano(id_jugador: int, card_id: String):
	if card_id == "": return
	if id_jugador == 1:
		mano_p1.append(card_id)
	else:
		mano_p2.append(card_id)

func eliminar_de_mano(id_jugador: int, card_id: String):
	# Cuando una carta sale de la mano, va a la PILA DE DESCARTE
	if id_jugador == 1:
		if card_id in mano_p1:
			mano_p1.erase(card_id)
			discard_pile.append(card_id)
	else:
		if card_id in mano_p2:
			mano_p2.erase(card_id)
			discard_pile.append(card_id)

func get_mano_actual() -> Array:
	return mano_p1 if turno_actual == 1 else mano_p2

func get_deck_count() -> int:
	return cards.size()

# --- CONTROL DE FLUJO ---
func cambiar_turno():
	turno_actual = 2 if turno_actual == 1 else 1
	print("Turno del Jugador: ", turno_actual)
