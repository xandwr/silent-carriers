## DriverSeat.gd
class_name DriverSeat extends Area3D

@export var cart: Cart
@export var seat_socket: Node3D

@export var occupant_id: int = -1


func interact(player_id: int) -> void:
	if NetworkManager.is_host:
		_process_interact(player_id)
	else:
		request_interact.rpc_id(1, player_id)


# Local function to actually do the work
func _process_interact(player_id: int) -> void:
	if occupant_id == player_id:
		exit_seat()
		return
		
	if occupant_id == -1:
		var player = get_tree().get_nodes_in_group("players").filter(func(p): return p.get_multiplayer_authority() == player_id)[0]
		if player:
			# Normal flow - player enters vehicle
			player.enter_vehicle(self)
			occupant_id = player_id
			cart.set_driver(player_id)
			player.rpc_id(player_id, "_rpc_enter_vehicle", self.get_path())
			
			# Only server can transfer authority
			if multiplayer.is_server():
				# This is a critical fix - we need to transfer authority for the VehicleBody3D nodes
				if cart is TrailerCart:
					var trailer_cart = cart as TrailerCart
					print("Transferring physics body authority to player ", player_id)
					
					# Transfer authority
					cart.set_multiplayer_authority(player_id)
					trailer_cart.cab_body.set_multiplayer_authority(player_id)
					trailer_cart.trailer_body.set_multiplayer_authority(player_id)
					
					# CRITICAL ADDITION: Tell the client to enable physics processing
					cart.rpc_id(player_id, "enable_physics_bodies", true)
				else:
					cart.set_multiplayer_authority(player_id)


@rpc("any_peer", "reliable")
func request_interact(player_id: int) -> void:
	var sender = multiplayer.get_remote_sender_id()
	if sender == player_id:  # Verify it's the right player
		_process_interact(player_id)


func _process_exit(player_id: int) -> void:
	if occupant_id == -1:
		return
	
	var player = get_tree().get_nodes_in_group("players").filter(
		func(p): return p.get_multiplayer_authority() == player_id
	)[0]
	
	if player:
		player.rpc_id(player_id, "_rpc_exit_vehicle")
		player.exit_vehicle()
	
	cart.clear_driver()
	
	# Server reclaims authority
	
	occupant_id = -1


@rpc("any_peer", "reliable")
func request_exit(player_id: int) -> void:
	if occupant_id != player_id:
		return
	_process_exit(player_id)


func is_occupied() -> bool:
	return occupant_id != -1


func exit_seat() -> void:
	if occupant_id == -1:
		return
		
	var player = get_tree().get_nodes_in_group("players").filter(func(p): return p.get_multiplayer_authority() == occupant_id)[0]
	if player:
		player.exit_vehicle()
		cart.clear_driver()
	
	# Only return authority to server if we're actually exiting
	if multiplayer.is_server() and occupant_id != -1:
		cart.set_multiplayer_authority(1)  # Give authority back to server
		
	occupant_id = -1
