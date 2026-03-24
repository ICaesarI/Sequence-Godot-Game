extends Node

signal player_list_changed
signal room_discovered(codigo, ip)

const PORT = 7000
const UDP_PORT = 7001

var peer = ENetMultiplayerPeer.new()
var local_player_name: String = ""
var players = {} 
var codigo_sala_actual: String = ""
var codigo_intentado: String = ""

# --- VARIABLES LAN DISCOVERY ---
var broadcaster: PacketPeerUDP
var listener: PacketPeerUDP
var broadcast_timer: Timer
var discovered_rooms = {} 
# -------------------------------

func _ready():
	set_process(false)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failed)	
	
	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = 1.0
	broadcast_timer.timeout.connect(_on_broadcast_timer_timeout)
	add_child(broadcast_timer)

# --- SISTEMA DE GESTIÓN LAN DISCOVERY ---
func start_broadcasting():
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	broadcaster.set_dest_address("255.255.255.255", UDP_PORT)
	broadcast_timer.start()

func stop_broadcasting():
	broadcast_timer.stop()
	if broadcaster:
		broadcaster.close()
		broadcaster = null

func _on_broadcast_timer_timeout():
	if broadcaster and codigo_sala_actual != "":
		var message = "SEQ_ROOM:" + codigo_sala_actual
		var buffer = message.to_utf8_buffer()
		
		# 1. Intento global (Suele irse por VirtualBox por tener distinta métrica en Windows)
		broadcaster.set_dest_address("255.255.255.255", UDP_PORT)
		broadcaster.put_packet(buffer)
		
		# 2. Intento forzado a cada subred (Para garantizar que cruce el Wi-Fi real)
		var ips_locales = IP.get_local_addresses()
		for ip in ips_locales:
			if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
				var partes = ip.split(".")
				if partes.size() == 4:
					partes[3] = "255" # Transformamos 192.168.100.2 a 192.168.100.255
					var subnet_broadcast = ".".join(partes)
					broadcaster.set_dest_address(subnet_broadcast, UDP_PORT)
					broadcaster.put_packet(buffer)

func start_listening():
	discovered_rooms.clear()
	listener = PacketPeerUDP.new()
	listener.bind(UDP_PORT)
	set_process(true)

func stop_listening():
	set_process(false)
	if listener:
		listener.close()
		listener = null

func _process(delta):
	while listener and listener.get_available_packet_count() > 0:
		var array_bytes = listener.get_packet()
		var msg = array_bytes.get_string_from_utf8()
		
		# Validar si el grito viene de una partida de Sequence
		if msg.begins_with("SEQ_ROOM:"):
			var code = msg.replace("SEQ_ROOM:", "")
			var sender_ip = listener.get_packet_ip()
			
			if not discovered_rooms.has(code) or discovered_rooms[code] != sender_ip:
				discovered_rooms[code] = sender_ip
				room_discovered.emit(code, sender_ip)
				print("LAN Discovery: ¡Sala oculta encriptada encontrada! Código: ", code, " - IP: ", sender_ip)
# ----------------------------------------

func stop_multiplayer():
	multiplayer.multiplayer_peer = null
	
	if peer:
		peer.close()
		peer = ENetMultiplayerPeer.new() 
	
	players.clear()
	codigo_sala_actual = ""
	codigo_intentado = ""
	
	stop_broadcasting()
	stop_listening()
	
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
	start_broadcasting()
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
	
	
