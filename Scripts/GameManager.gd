extends Node  # Cambia Node2D por Node, es mejor para gestores globales

var deck = []
var suits = ["S", "C", "D", "H"]
var values = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "A", "Q", "K"]

func _ready():
	create_deck()
	shuffle_deck()

func create_deck():
	deck.clear()
	for i in range(2):
		for s in suits:
			for v in values:
				deck.append(s + v)
	for i in range(8):
		deck.append("J")

func shuffle_deck():
	deck.shuffle()

# ASEGÚRATE DE QUE ESTA FUNCIÓN ESTÉ ESCRITA ASÍ:
func draw_card():
	if deck.size() > 0:
		return deck.pop_back()
	return null
