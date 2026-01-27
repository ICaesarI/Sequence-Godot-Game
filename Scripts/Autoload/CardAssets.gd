extends Node

const CARD_W := 801
const CARD_H := 1082
const PAD_X := 2
const PAD_Y := 2


@onready var atlas: Texture2D = preload("res://Assets/Cards/cards_atlas.png")
const CHIP_TEX := {
	"p1": preload("res://Assets/Chips/chips_flat_blue.png"),
	"p2": preload("res://Assets/Chips/chips_flat_red.png"),
}

static func get_chip(player_id: String) -> Texture2D:
	return CHIP_TEX.get(player_id, null)


# Mapa lógico → posición en el atlas (col, row)
const CARD_POSITIONS := {

	# =====================
	# ♣ TREBOLES (Clubs)
	# =====================
	"C_2":  Vector2i(2, 0),
	"C_3":  Vector2i(3, 0),
	"C_4":  Vector2i(4, 0),
	"C_5":  Vector2i(5, 0),
	"C_6":  Vector2i(6, 0),
	"C_7":  Vector2i(7, 0),
	"C_8":  Vector2i(0, 1),
	"C_9":  Vector2i(1, 1),
	"C_10": Vector2i(1, 0),
	"C_Q":  Vector2i(6, 1),
	"C_K":  Vector2i(5, 1),
	"C_A":  Vector2i(2, 1),

	# =====================
	# ♦ DIAMANTES (Diamonds)
	# =====================
	"D_2":  Vector2i(0, 2),
	"D_3":  Vector2i(1, 2),
	"D_4":  Vector2i(2, 2),
	"D_5":  Vector2i(3, 2),
	"D_6":  Vector2i(4, 2),
	"D_7":  Vector2i(5, 2),
	"D_8":  Vector2i(6, 2),
	"D_9":  Vector2i(7, 2),
	"D_10": Vector2i(7, 1),
	"D_Q":  Vector2i(4, 3),#
	"D_K":  Vector2i(3, 3),
	"D_A":  Vector2i(0, 3),

	# =====================
	# ♥ CORAZONES (Hearts)
	# =====================
	"H_2":  Vector2i(7, 3),
	"H_3":  Vector2i(0, 4),
	"H_4":  Vector2i(1, 4),
	"H_5":  Vector2i(2, 4),
	"H_6":  Vector2i(3, 4),
	"H_7":  Vector2i(4, 4),
	"H_8":  Vector2i(5, 4),
	"H_9":  Vector2i(6, 4),
	"H_10": Vector2i(6, 3),
	"H_Q":  Vector2i(3, 5),
	"H_K":  Vector2i(2, 5),
	"H_A":  Vector2i(7, 4),

	# =====================
	# ♠ ESPADAS (Spades)
	# =====================
	"S_2":  Vector2i(5, 5),
	"S_3":  Vector2i(6, 5),
	"S_4":  Vector2i(7, 5),
	"S_5":  Vector2i(8, 0),
	"S_6":  Vector2i(8, 1),
	"S_7":  Vector2i(8, 2),
	"S_8":  Vector2i(8, 3),
	"S_9":  Vector2i(8, 4),
	"S_10": Vector2i(4, 5),
	"S_Q":  Vector2i(3, 6),
	"S_K":  Vector2i(2, 6),
	"S_A":  Vector2i(8, 5),#

	# =====================
	# 🃏 JOTAS ESPECIALES (Sequence)
	# =====================
	"C_J1": Vector2i(3, 1), # Jota de 1 ojo
	"C_J2": Vector2i(4, 1), # Jota de 2 ojos
	"H_J1": Vector2i(1, 3), # Jota de 1 ojo
	"H_J2": Vector2i(2, 3), # Jota de 2 ojos 
	"S_J1": Vector2i(0, 5), # Jota de 1 ojo
	"S_J2": Vector2i(1, 5), # Jota de 2 ojos
	"D_J1": Vector2i(0, 6), # Jota de 1 ojo
	"D_J2": Vector2i(1, 6), # Jota de 2 ojos

	# =====================
	# EXTRAS (si los usas)
	# =====================
	"BACK": Vector2i(0, 0),
	"FREE": Vector2i(5, 3),
}

func get_face(card_id: String) -> AtlasTexture:
	if not CARD_POSITIONS.has(card_id):
		return null

	var pos := CARD_POSITIONS[card_id] as Vector2i

	var tex := AtlasTexture.new()
	tex.atlas = atlas
	var y := pos.y * (CARD_H + PAD_Y)
	var x := pos.x * (CARD_W + PAD_X)
	tex.region = Rect2(x, y, CARD_W, CARD_H)


	return tex
