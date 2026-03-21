extends Node

signal player_list_changed

const PORT = 7000
var peer = ENetMultiplayerPeer.new()
var local_player_name: String = ""
var players = {} 
var codigo_sala_actual: String = ""
var codigo_intentado: String = ""


func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failed)	

func stop_multiplayer():
	multiplayer.multiplayer_peer = null
	
	if peer:
		peer.close()
		peer = ENetMultiplayerPeer.new() 
	
	players.clear()
	codigo_sala_actual = ""
	codigo_intentado = ""
	player_list_changed.emit() 
	print("Red reseteada.")

func host_game(player_name: String, codigo: String):
	players.clear()
	local_player_name = player_name
	codigo_sala_actual = codigo.to_upper()
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 12)
	if error != OK: return
	
	multiplayer.multiplayer_peer = peer
	register_player(1, local_player_name)
	print("Servidor creado. Código: ", codigo_sala_actual)
	
	
func join_game(player_name: String, ip_address: String, codigo: String):
	players.clear()
	local_player_name = player_name
	codigo_intentado = codigo.to_upper() 
	
	multiplayer.multiplayer_peer = null
	peer = ENetMultiplayerPeer.new()
	
	var error = peer.create_client(ip_address, PORT)
	if error != OK: return
	
	multiplayer.multiplayer_peer = peer
	print("Cliente intentando unir con código: ", codigo_intentado)

func _on_connection_success():
	var mi_id = multiplayer.get_unique_id()
	rpc_id(1, "verificar_y_registrar", mi_id, local_player_name, codigo_intentado)

@rpc("any_peer", "reliable")
func verificar_y_registrar(id, nombre, codigo_enviado):
	if not multiplayer.is_server(): return
	
	print("Validando cliente: ", nombre, " con código: ", codigo_enviado)
	
	if codigo_enviado == codigo_sala_actual:
		register_player(id, nombre)
		rpc("register_player", id, nombre)
		rpc_id(id, "register_player", 1, local_player_name)
		for p_id in players:
			if p_id != id: rpc_id(id, "register_player", p_id, players[p_id])
	else:
		print("CÓDIGO ERRÓNEO. Expulsando...")
		peer.disconnect_peer(id)

func _on_player_connected(_id):
	pass 

func _on_player_disconnected(id):
	if players.has(id):
		var nombre_saliente = players[id]
		players.erase(id)
		player_list_changed.emit()
		
		if multiplayer.is_server():
			rpc("remover_jugador_remoto", id)
			print("Jugador ", nombre_saliente, " se ha ido. Avisando a todos.")

func _on_connection_failed():
	multiplayer.multiplayer_peer = null
	players.clear()
	player_list_changed.emit()

@rpc("any_peer", "reliable")
func remover_jugador_remoto(id):
	if players.has(id):
		players.erase(id)
		player_list_changed.emit()

@rpc("any_peer", "reliable")
func register_player(id, p_name):
	players[id] = p_name
	player_list_changed.emit()
	
@rpc("authority", "reliable", "call_local")
func iniciar_partida_remota(n: int):
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
	
	await get_tree().create_timer(0.3).timeout
	
	if multiplayer.is_server():
		GameManager.preparar_partida_red(players)
	
	
