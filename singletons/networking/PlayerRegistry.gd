## PlayerRegistry.gd
extends Node

signal player_registered(peer_id, player_info)
signal player_unregistered(peer_id)
signal player_updated(peer_id, field, value)

## Main player data store
var players: Dictionary = {}


## Registers a new player with the system
func register_player(peer_id: int, info: Dictionary = {}) -> void:
	var key = str(peer_id)
	
	# Create default info if none provided
	if info.is_empty():
		info = {
			"name": "Player " + key,
			"color": Color.from_hsv(randf(), 0.8, 0.9),
			"ready": false
		}
	
	# Store player info
	players[key] = info
	player_registered.emit(peer_id, info)
	
	print("Player registered: %d - %s" % [peer_id, str(info)])


## Removes a player from the registry
func unregister_player(peer_id: int) -> void:
	var key = str(peer_id)
	if players.has(key):
		var info = players[key]
		players.erase(key)
		player_unregistered.emit(peer_id)
		print("Player unregistered: %d - %s" % [peer_id, info.get("name", "Unknown")])


## Updates a specific field for a player
func update_player(peer_id: int, field: String, value) -> void:
	var key = str(peer_id)
	if players.has(key):
		players[key][field] = value
		player_updated.emit(peer_id, field, value)


func has_peer(peer_id: int) -> bool:
	return players.has(str(peer_id))


func get_player(peer_id: int) -> Player:
	if not SceneManager.current_scene:
		return null
	
	var scene := SceneManager.current_scene
	if scene is NetworkedScene and scene.player_container:
		return scene.player_container.get_node_or_null(str(peer_id)) as Player
	
	return null


func get_player_name(peer_id: int) -> String:
	return players.get(str(peer_id), {}).get("name", "Unknown Player")


@rpc("any_peer", "reliable")
func set_player_ready(peer_id: int, is_ready: bool) -> void:
	if not multiplayer.is_server():
		# Forward request to server
		rpc_id(1, "set_player_ready", peer_id, is_ready)
		return
	
	# Update on server
	update_player(peer_id, "ready", is_ready)
	
	# Sync full registry to all clients
	rpc("sync_player_registry", players)


## Network synchronization
@rpc("any_peer", "reliable")
func register_client_info(info: Dictionary) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	
	if multiplayer.is_server():
		# Actually use the info parameter!
		register_player(peer_id, info)
		# Then sync to everyone
		rpc("sync_player_registry", players)


@rpc("authority", "reliable")
func sync_player_registry(registry_data: Dictionary) -> void:
	players = registry_data
