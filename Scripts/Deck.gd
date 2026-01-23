extends Node

var cards = []

func _init():
	generate_deck()
	shuffle_deck()

func generate_deck():
	cards.clear()
	var suits = ["S", "C", "D", "H"] # Spades, Clubs, Diamonds, Hearts
	var values = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "Q", "K", "A"]
	
	for i in range(2):
		for s in suits:
			for v in values:
				cards.append(s + "_" + v)
			
			# 2. Jotas (Jacks)
			# J1 = Un Ojo (Quita ficha)
			# J2 = Dos Ojos (Comodín total)
			cards.append(s + "_J1")
			cards.append(s + "_J2")

	print("Mazo generado con ", cards.size(), " cartas.")

func shuffle_deck():
	cards.shuffle() 

func draw_card():
	if cards.size() > 0:
		return cards.pop_back()
	else:
		push_warning("¡El mazo está vacío!")
		return null


func get_deck_count():
	return cards.size()
