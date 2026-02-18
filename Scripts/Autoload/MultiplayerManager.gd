extends Node

# Añade esta señal al principio
signal player_list_changed

const PORT = 7000
var peer = ENetMultiplayerPeer.new()
var local_player_name: String = ""
var players = {} 

func host_game(player_name: String):
	local_player_name = player_name
	var error = peer.create_server(PORT, 12)
	if error != OK: return
	
	multiplayer.multiplayer_peer = peer
	register_player(1, local_player_name)
	
	multiplayer.peer_connected.connect(_on_player_connected)

func register_player(id, name):
	players[id] = name
	# Avisamos que la lista cambió
	player_list_changed.emit()
	print("Jugador registrado: ", name, " (", id, ")")

func _on_player_connected(id):
	# Por ahora solo detectamos la conexión
	print("Nuevo jugador conectado: ", id)
