## NetworkManager.gd
extends Node

signal connection_established()
signal connection_failed()
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)

var is_host: bool = false

# map of peer_id -> Pickable
var held_by_peer: Dictionary[int, Pickable] = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	var cmd_args = OS.get_cmdline_args()
	
	# Some debugging setup to run two instances as both host and client automatically
	if "host" in cmd_args:
		host_game()
	elif "client" in cmd_args:
		join_game()


func _physics_process(delta: float) -> void:
	_update_pickables(delta)


func host_game(port: int = 7000, max_players: int = 4) -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, max_players)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		ServerManager.activate()
		is_host = true
		
		# Host also acts as a client
		ClientManager.activate()
		
		# Register the host in the PlayerRegistry with proper name
		PlayerRegistry.register_player(multiplayer.get_unique_id(), {
			"name": "Host"
		})
		
		connection_established.emit()
	else:
		connection_failed.emit()
		return
	
	# Waiting for a frame here is CRITICAL because the client needs a second to join the server and sync
	await get_tree().process_frame
	ServerManager.load_scene_and_spawn_all(SceneManager.scenes.safehouse)


func join_game(ip: String = "127.0.0.1", port: int = 7000) -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		ClientManager.activate()
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
		current_scene.spawn_player(multiplayer.get_unique_id())


func _on_player_connected(peer_id: int) -> void:
	print("Player %d connected." % peer_id)
	player_connected.emit(peer_id)
	
	# Only host/server authority spawns players
	if is_host:
		var current_scene = SceneManager.current_scene
		if current_scene is NetworkedScene:
			current_scene.spawn_player(peer_id)
			PlayerRegistry.register_player(peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	print("Player %d disconnected." % peer_id)
	player_disconnected.emit(peer_id)
	
	# Clean up stale references if someone leaves while holding something
	if held_by_peer.has(peer_id):
		var body = held_by_peer[peer_id]
		body.freeze = false
		body.held_by = 0
		held_by_peer.erase(peer_id)


## ITEM PICKUP RPCS ##
@rpc("any_peer", "call_local", "reliable")
func _server_request_pickup(body_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	
	var peer_id = multiplayer.get_remote_sender_id()
	var body = get_node_or_null(body_path) as Pickable
	var success := false
	
	if body and body.held_by == 0:
		held_by_peer[peer_id] = body
		body.held_by = peer_id
		body.rpc("sync_held_by", peer_id)
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = true
		success = true
	
	rpc_id(peer_id, "_client_pickup_result", success)


@rpc("authority", "call_local", "reliable")
func _client_pickup_result(success: bool) -> void:
	var local_player = GameManager.player_instance
	if not local_player: return

	if success and local_player.attempted_pickup:
		local_player.held_body = local_player.attempted_pickup
	else:
		print("Pickup failed or invalid")
	local_player.attempted_pickup = null


@rpc("any_peer", "call_local", "reliable")
func _server_request_drop() -> void:
	if not multiplayer.is_server(): return
	var peer = multiplayer.get_remote_sender_id()
	if held_by_peer.has(peer):
		var body = held_by_peer[peer]
		held_by_peer.erase(peer)
		body.freeze = false
		body.held_by = 0
		body.rpc("sync_held_by", 0)


## Updates the position of held objects for each player from the server.
func _update_pickables(delta: float) -> void:
	if not multiplayer.is_server(): return
	
	for peer_id in held_by_peer.keys():
		var body: Pickable = held_by_peer[peer_id]
		var player: Player = PlayerRegistry.get_player(peer_id)
		if player and body:
			body.global_position = player.hold_point.global_position
