## cart.gd
class_name Cart extends Node3D

@export var engine_power: float = 1000.0
@export var max_steer: float = 0.8
@export var brake_power: float = 20.0

var throttle: float = 0.0
var steer: float = 0.0

var driver_wheels: Array[VehicleWheel3D] = []
@export var driver_id: int = -1

var _authority_locked: bool = false


func _ready():
	if is_multiplayer_authority():
		print("Cart: I have authority, enabling physics.")
		set_physics_process(true)


func get_driver_wheels() -> Array[VehicleWheel3D]:
	return []


func set_driver(peer_id: int) -> void:
	if driver_id == peer_id:
		return
	print("Setting cart driver to %d" % peer_id)
	driver_id = peer_id
	rpc_id(peer_id, "set_driver_id", peer_id)


func clear_driver() -> void:
	if driver_id == -1:
		return
		
	print("Clearing cart driver ", driver_id)
	
	# Explicitly unlock authority before transferring back
	if multiplayer.is_server():
		lock_authority.rpc(0)  # 0 = unlock
		
		# Delay authority transfer slightly to ensure lock processing completes
		get_tree().create_timer(0.1).timeout.connect(func():
			set_multiplayer_authority(1)  # Return to server
		)
		
		# Sync to former driver
		rpc_id(driver_id, "set_driver_id", -1)
		
	driver_id = -1


@rpc("any_peer", "call_local", "unreliable") 
func sync_input(throttle_val: float, steer_val: float) -> void:
	var sender = multiplayer.get_remote_sender_id()
	
	# Only accept input from the assigned driver
	if sender != driver_id:
		return
		
	print("sync_input(): peer=%d, throttle=%.2f, steer=%.2f" % [sender, throttle_val, steer_val])
	throttle = throttle_val
	steer = steer_val


@rpc("authority", "call_local", "reliable")
func lock_authority(peer_id: int) -> void:
	_authority_locked = (peer_id > 0)
	print("Authority lock set to: ", _authority_locked, " for peer: ", peer_id)


func request_authority_transfer(peer_id: int) -> void:
	if not multiplayer.is_server():
		print("Only server can transfer authority!")
		return
	
	print("SERVER transferring authority to %d" % peer_id)
	
	set_multiplayer_authority(peer_id)
	
	# Wait a frame to allow the authority to sync
	await get_tree().process_frame
	await get_tree().process_frame  # two is safer for SteamP2P
	
	# Tell the new authority to confirm they now control the cart
	rpc_id(peer_id, "confirm_cart_authority")
	
	# Also tell everyone else who the new owner is, just for debugging visibility
	rpc("debug_print_cart_ownership")


@rpc("authority", "call_local", "reliable")
func update_physics_after_authority() -> void:
	if self is TrailerCart:
		var trailer_cart = self as TrailerCart
		trailer_cart._update_physics_state()


@rpc("authority", "call_local", "reliable")
func confirm_cart_authority() -> void:
	print("Client confirmed cart ownership on peer ", multiplayer.get_unique_id())
	
	# If this is a TrailerCart, make sure physics is enabled for the physics bodies
	if self is TrailerCart:
		var trailer_cart = self as TrailerCart
		
		# Explicitly enable physics on the physics bodies
		trailer_cart.cab_body.set_physics_process(true)
		trailer_cart.trailer_body.set_physics_process(true)
		
		print("Enabled physics bodies on client peer ", multiplayer.get_unique_id())
		
	# Enable physics processing
	set_physics_process(true)


func is_driver() -> bool:
	# The original check is too restrictive
	# var me = multiplayer.get_unique_id()
	# return driver_id == me
	
	# Either you're the driver OR you have authority while authority is locked
	var me = multiplayer.get_unique_id()
	return driver_id == me || (get_multiplayer_authority() == me && _authority_locked)


@rpc("authority", "call_local", "reliable")
func set_driver_id(peer_id: int) -> void:
	driver_id = peer_id
	print("Driver ID synced to: %d" % peer_id)
