extends Node

# Matriz 10x10 transcrita directamente de la imagen original
const BOARD_MAP = [
	["FREE", "S_2", "S_3", "S_4", "S_5", "S_6", "S_7", "S_8", "S_9", "FREE"],
	["C_6", "C_5", "C_4", "C_3", "C_2", "H_A", "H_K", "H_Q", "H_10", "S_10"],
	["C_7", "S_A", "D_2", "D_3", "D_4", "D_5", "D_6", "D_7", "H_9", "S_Q"],
	["C_8", "S_K", "C_6", "C_5", "C_4", "C_3", "C_2", "D_8", "H_8", "S_K"],
	["C_9", "S_Q", "C_7", "H_6", "H_5", "H_4", "H_A", "D_9", "H_7", "S_A"],
	["C_10", "S_10", "C_8", "H_7", "H_2", "H_3", "H_K", "D_10", "H_6", "D_2"],
	["C_Q", "S_9", "C_9", "H_8", "H_9", "H_10", "H_Q", "D_Q", "H_5", "D_3"],
	["C_K", "S_8", "C_10", "C_Q", "C_K", "C_A", "D_A", "D_K", "H_4", "D_4"],
	["C_A", "S_7", "S_6", "S_5", "S_4", "S_3", "S_2", "H_2", "H_3", "D_5"],
	["FREE", "D_A", "D_K", "D_Q", "D_10", "D_9", "D_8", "D_7", "D_6", "FREE"]
]
#H = CORAZON
#S = ESPADAS
#C = TREBOLES
#D = DIAMANTES
