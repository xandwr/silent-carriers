## NetworkManager.gd
extends Node

signal connection_established()
signal connection_failed()
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)

var server_manager: ServerManager
var client_manager: ClientManager
var is_host: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	server_manager = ServerManager
	client_manager = ClientManager
	
	server_manager.network_manager = self
	client_manager.network_manager = self
	
	var cmd_args = OS.get_cmdline_args()
	
	# Some debugging setup to run two instances as both host and client automatically
	if "host" in cmd_args:
		host_game()
	elif "client" in cmd_args:
		join_game()


func host_game(port: int = 7000, max_players: int = 4) -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_players)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		server_manager.activate()
		is_host = true
		
		# Host also acts as a client
		client_manager.activate()
		connection_established.emit()
	else:
		connection_failed.emit()
		return
	
	# Waiting for a frame here is CRITICAL because the client needs a second to join the server and sync
	await get_tree().process_frame
	load_scene_and_spawn_all(SceneManager.scenes.safehouse)


func join_game(ip: String = "127.0.0.1", port: int = 7000) -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		client_manager.activate()
		is_host = false
		
		connection_established.emit()
	else:
		connection_failed.emit()
		return


## Loads a scene and spawns all players in it, if able
func load_scene_and_spawn_all(path: String) -> void:
	SceneManager.load_scene(path, true)
	if not NetworkManager.is_host: return
	
	var current_scene = SceneManager.current_scene
	if current_scene is NetworkedScene:
		for peer_id in multiplayer.get_peers():
			current_scene.spawn_player(peer_id)
	
		# Also spawn the host's player
		current_scene.spawn_player(multiplayer.get_unique_id())


## Returns true if this instance is the authority for the provided Node.
func is_authority_for(node: Node) -> bool:
	return node.get_multiplayer_authority() == multiplayer.get_unique_id()


func _on_player_connected(peer_id: int) -> void:
	print("Player %d connected." % peer_id)
	player_connected.emit(peer_id)
	
	# Only host/server authority spawns players
	if is_host:
		var current_scene = SceneManager.current_scene
		if current_scene is NetworkedScene:
			current_scene.spawn_player(peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	print("Player %d disconnected." % peer_id)
	player_disconnected.emit(peer_id)
