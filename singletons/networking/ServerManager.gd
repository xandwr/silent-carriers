## ServerManager.gd
extends PeerManager

## A dictionary of connected peers (peer id, player info)
var connected_peers: Dictionary[int, Dictionary] = {}


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
	connected_peers[peer_id] = {
		"name": "Player %d" % peer_id
	}
	
	# Emit signal through NetworkManager
	NetworkManager.player_connected.emit(peer_id)
	
	spawn_player(peer_id)
	
	if multiplayer.is_server():
		# Send current registry to the new player
		PlayerRegistry.rpc_id(peer_id, "sync_player_registry", PlayerRegistry.players)


func _on_player_disconnected(peer_id: int) -> void:
	print("Server: Player %d disconnected." % peer_id)
	
	connected_peers.erase(peer_id)
	NetworkManager.player_disconnected.emit(peer_id)


func spawn_player(peer_id: int) -> void:
	var current_scene = SceneManager.current_scene
	if current_scene is NetworkedScene:
		current_scene.spawn_player(peer_id)


func load_scene_and_spawn_all(path: String) -> void:
	SceneManager.load_scene(path, true)
	
	# Spawn all connected players in the new scene
	for peer_id in multiplayer.get_peers():
		spawn_player(peer_id)
	
	# Also spawn the host's player
	spawn_player(multiplayer.get_unique_id())
