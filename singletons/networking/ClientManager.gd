## ClientManager.gd
extends PeerManager

## The client manager's local peer id
var local_peer_id: int


func activate() -> void:
	super.activate()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	local_peer_id = multiplayer.get_unique_id()


func deactivate() -> void:
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	super.deactivate()


func _on_connected_to_server() -> void:
	print("Client: Connected to server")
	
	# Send our player info to the server
	PlayerRegistry.rpc_id(1, "register_client_info", {
		"name": GameManager.local_player_name
	})
	
	NetworkManager.connection_established.emit()


func _on_connection_failed() -> void:
	print("Client: Failed to connect")
	NetworkManager.connection_failed.emit()


func _on_server_disconnected() -> void:
	print("Client: Server disconnected")
	# Handle disconnection
	get_tree().quit()
