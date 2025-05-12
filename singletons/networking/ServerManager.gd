## ServerManager.gd
extends PeerManager

## A dictionary of connected peers (peer id, player info)
var connected_peers: Dictionary[String, Dictionary] = {}


func activate() -> void:
	super.activate()
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)


func deactivate() -> void:
	if multiplayer.peer_connected.is_connected(_on_player_connected):
		multiplayer.peer_connected.disconnect(_on_player_connected)
	if multiplayer.peer_disconnected.is_connected(_on_player_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_player_disconnected)
	super.deactivate()


func _on_player_connected(peer_id: int) -> void:
	print("Server: Player %d connected." % peer_id)
	var player_info = {
		"name": "Player %d" % peer_id,
		"color": Color.from_hsv(randf(), 0.8, 0.9),
		"ready": false
	}
	
	PlayerRegistry.register_player(peer_id, player_info)
	NetworkManager.player_connected.emit(peer_id)
	
	if multiplayer.is_server():
		# Send updated registry to ALL peers (not just the new one goddammit lol)
		NetworkManager.rpc("_client_receive_player_registry", PlayerRegistry.players)


func _on_player_disconnected(peer_id: int) -> void:
	print("Server: Player %d disconnected." % peer_id)
	
	connected_peers.erase(peer_id)
	NetworkManager.player_disconnected.emit(peer_id)


func spawn_player(peer_id: int) -> void:
	var current_scene = SceneManager.current_scene
	if current_scene is NetworkedScene:
		var player = current_scene.spawn_player(peer_id)
		var player_name = PlayerRegistry.get_player_name(peer_id)
		if player:
			player.rpc_id(peer_id, "set_player_name", player_name)
			player.rpc("set_player_name", player_name)


func load_scene_and_spawn_all(path: String) -> void:
	SceneManager.load_scene(path, true)
	
	# Spawn all connected players in the new scene
	for peer_id in multiplayer.get_peers():
		spawn_player(peer_id)
	
	# Also spawn the host's player
	spawn_player(multiplayer.get_unique_id())
	
	await get_tree().process_frame  # Wait for nodes to be ready
	NetworkManager.update_all_player_names()
