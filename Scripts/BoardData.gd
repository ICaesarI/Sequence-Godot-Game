#Tablero del Juego

#"S" = Spades/Picas 
#"C" = Clubs/Tréboles 
#"D" = Diamonds/Diamantes 
#"H" = Hearts/Corazones)
extends Node

const BOARD_MAP = [
	["FREE", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "FREE"],
	["C6", "C5", "C4", "C3", "C2", "H_A", "H_K", "H_Q", "H_10", "S10"],
	["C7", "S_A", "D2", "D3", "D4", "D5", "D6", "D7", "H9", "SQ"],
	["C8", "SK", "D10", "SQ", "SK", "S_A", "H2", "D8", "H8", "SK"],
	["C9", "SQ", "D9", "H_A", "H2", "H3", "D10", "D9", "H7", "S_A"],
	["C10", "S10", "D8", "HK", "H5", "H4", "DQ", "D_A", "H6", "D2"],
	["CQ", "H9", "D7", "HQ", "H6", "H7", "DK", "C2", "H5", "D3"],
	["CK", "H8", "D6", "H10", "H_A", "H_Q", "H_K", "C3", "H4", "D4"],
	["C_A", "H7", "D5", "D4", "D3", "D2", "C_A", "C4", "C3", "D5"],
	["FREE", "CQ", "CK", "C_A", "DK", "DQ", "D10", "D9", "D8", "FREE"]
]
