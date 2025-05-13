## trailer_cart.gd
class_name TrailerCart extends Cart

@export var trailer_body: VehicleBody3D
@export var cab_body: VehicleBody3D

var trailer_driver_wheels: Array[VehicleWheel3D] = []


func get_driver_wheels() -> Array[VehicleWheel3D]:
	var wheels: Array[VehicleWheel3D] = []
	for child in cab_body.get_children():
		if child is VehicleWheel3D:
			if child.use_as_steering == true:
				wheels.append(child as VehicleWheel3D)
	return wheels


func get_trailer_driver_wheels() -> Array[VehicleWheel3D]:
	var wheels: Array[VehicleWheel3D] = []
	for child in trailer_body.get_children():
		if child is VehicleWheel3D:
			if child.use_as_steering == true:
				wheels.append(child as VehicleWheel3D)
	return wheels


func _ready() -> void:
	driver_wheels = get_driver_wheels()
	trailer_driver_wheels = get_trailer_driver_wheels()
	
	# Initial physics state based on authority
	if is_multiplayer_authority():
		cab_body.set_physics_process(true)
		trailer_body.set_physics_process(true)
	else:
		cab_body.set_physics_process(false)
		trailer_body.set_physics_process(false)
	
	multiplayer.connect("peer_connected", _on_multiplayer_peer_connected)
	_update_physics_state()


@rpc("authority", "call_local", "reliable")
func enable_physics_bodies(enable: bool) -> void:
	if cab_body and trailer_body:
		cab_body.set_physics_process(enable)
		trailer_body.set_physics_process(enable)
		print("TrailerCart: %s physics bodies on peer %d" % 
			["Enabling" if enable else "Disabling", multiplayer.get_unique_id()])


func _update_physics_state() -> void:
	if is_multiplayer_authority():
		print("TrailerCart: Enabling physics on authority peer ", multiplayer.get_unique_id())
		cab_body.set_physics_process(true)
		trailer_body.set_physics_process(true)
	else:
		print("TrailerCart: Disabling physics on non-authority peer ", multiplayer.get_unique_id())
		cab_body.set_physics_process(false)
		trailer_body.set_physics_process(false)


func _on_multiplayer_peer_connected(id: int) -> void:
	_update_physics_state()


func _sync_physics_bodies_with_authority() -> void:
	# Ensure physics bodies match the cart's authority state
	var should_process = is_multiplayer_authority()
	cab_body.set_physics_process(should_process)
	trailer_body.set_physics_process(should_process)
	print("TrailerCart: Synced physics bodies with authority=%d, physics=%s" % 
		  [get_multiplayer_authority(), str(should_process)])


@rpc("authority", "call_local", "reliable")
func confirm_cart_authority() -> void:
	print(">> CONFIRM_CART_AUTHORITY on peer %d: is_multiplayer_authority=%s" % 
		[multiplayer.get_unique_id(), is_multiplayer_authority()])
	
	set_physics_process(true)
	
	if self is TrailerCart:
		_sync_physics_bodies_with_authority()
	
	if driver_id == -1:
		driver_id = multiplayer.get_unique_id()



func _on_authority_changed():
	print("Cart authority changed to %d" % get_multiplayer_authority()) 
	
	# Sync the VehicleBody physics to match Cart authority
	cab_body.set_physics_process(is_multiplayer_authority())
	trailer_body.set_physics_process(is_multiplayer_authority())


func _physics_process(delta: float):
	if not is_multiplayer_authority(): return
	if Engine.get_physics_frames() % 60 == 0:
		print("TrailerCart physics: peer=%d, driver=%d, throttle=%.2f" % 
			  [multiplayer.get_unique_id(), driver_id, throttle])
	
	# Get ALL wheels that need braking when stopped (both cab and trailer)
	var all_wheels = []
	all_wheels.append_array(get_driver_wheels())
	all_wheels.append_array(get_trailer_driver_wheels())
	
	if not is_driver():
		# Not being driven — engage brakes on ALL wheels
		for wheel in all_wheels:
			wheel.engine_force = lerp(wheel.engine_force, 0.0, delta * 2.0)
			wheel.brake = lerp(wheel.brake, brake_power, delta * 2.0)
		return
	
	# Driving logic below
	for wheel in driver_wheels:
		if abs(throttle) > 0.01:
			wheel.engine_force = lerp(wheel.engine_force, throttle * engine_power, delta * 5)
			wheel.brake = 0.0
		else:
			# When no throttle input, gradually apply brakes instead of removing them
			wheel.engine_force = lerp(wheel.engine_force, 0.0, delta * 10.0)
			wheel.brake = lerp(wheel.brake, brake_power * 0.5, delta * 2.0)
	
	for wheel in trailer_driver_wheels:
		if abs(throttle) > 0.01:
			wheel.engine_force = lerp(wheel.engine_force, throttle * engine_power, delta * 5)
			wheel.brake = 0.0
		else:
			wheel.engine_force = lerp(wheel.engine_force, 0.0, delta * 10.0)
			wheel.brake = lerp(wheel.brake, brake_power * 0.3, delta * 2.0)
	
	if driver_wheels.size() >= 2:
		driver_wheels[0].steering = lerp(driver_wheels[0].steering, steer * max_steer, delta)
		driver_wheels[1].steering = lerp(driver_wheels[1].steering, steer * max_steer, delta)
	
	if trailer_driver_wheels.size() >= 2:
		trailer_driver_wheels[0].steering = lerp(trailer_driver_wheels[0].steering, steer * max_steer * 0.3, delta)
		trailer_driver_wheels[1].steering = lerp(trailer_driver_wheels[1].steering, steer * max_steer * 0.3, delta)
