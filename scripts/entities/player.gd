class_name Player extends CharacterBody3D

@export var player_name: String

@export_category("Camera Settings")
@export var mouse_sensitivity: float = 0.001

@export_category("Movement Settings")
@export var walk_speed: float = 3.5
@export var sprint_speed: float = 6.0
@export var jump_force: float = 4.0

@onready var camera_pivot: Marker3D = $CameraPivot
@onready var player_camera: Camera3D = $CameraPivot/PlayerCamera
@onready var name_label: Label3D = $NameLabel
@onready var interaction_raycast: RayCast3D = $CameraPivot/PlayerCamera/InteractionRaycast
@onready var hold_point: Marker3D = $CameraPivot/PlayerCamera/HoldPoint

@onready var player_mesh: MeshInstance3D = $PlayerCapsuleMesh
@onready var player_eyes_mesh: MeshInstance3D = $PlayerCapsuleMesh/EyesMesh

@onready var scoreboard: Scoreboard = $Scoreboard

var current_move_speed: float = 0.0
var mouse_locked: bool = true:
	set(value):
		mouse_locked = value
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE

var attempted_pickup: Pickable = null
var held_body: Pickable = null


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	scoreboard.visible = false
	
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		GameManager.player_instance = self
		player_camera.current = true
	
	if is_multiplayer_authority():
		# Authority peer handles physics and input
		mouse_locked = false
		set_physics_process(true)
		set_process_input(true)
	else:
		# Non-authority peers only run visual updates
		set_physics_process(false)
		set_process_input(false)


func _process(_delta: float) -> void:	
	scoreboard.player_list.clear()
	for peer_id in PlayerRegistry.players:
		if peer_id == str(multiplayer.get_unique_id()):
			scoreboard.player_list.add_item(PlayerRegistry.players[peer_id].name + " (you)")
		else:
			scoreboard.player_list.add_item(PlayerRegistry.players[peer_id].name)
	
	if Input.is_action_pressed("scoreboard"):
		scoreboard.visible = true
	else:
		scoreboard.visible = false


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		if player_mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			player_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if player_eyes_mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			player_eyes_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	
	_process_movement(delta)


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion and mouse_locked:
		_process_mouselook(event)
	
	if event.is_action_pressed("pause"):
		mouse_locked = !mouse_locked
	
	if event.is_action_pressed("interact"):
		if held_body:
			_drop_body()
		else:
			if interaction_raycast.is_colliding():
				var hit = interaction_raycast.get_collider()
				
				if hit is Pickable:
					_try_pickup(hit)
				elif hit is PhysicalButton:
					if multiplayer.is_server():
						hit.activate_by(multiplayer.get_unique_id())
					else:
						hit.rpc_id(1, "request_toggle_by")


func _try_pickup(body: Pickable):
	attempted_pickup = body
	NetworkManager.rpc_id(1, "_server_request_pickup", body.get_path())


func _drop_body():
	NetworkManager.rpc_id(1, "_server_request_drop")
	if held_body: held_body = null


func _process_movement(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	var input_dir: Vector2
	if mouse_locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	else:
		input_dir = Vector2.ZERO
	
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y += jump_force
	
	current_move_speed = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var move_dir = transform.basis * Vector3(input_dir.x, 0, input_dir.y) * current_move_speed
	velocity.x = move_dir.x
	velocity.z = move_dir.z
	
	move_and_slide()


func _process_mouselook(mouse_event: InputEventMouseMotion) -> void:
	if not is_multiplayer_authority(): return
	
	var mouse_motion = mouse_event.relative * mouse_sensitivity
	
	camera_pivot.rotation.x = clamp(
		camera_pivot.rotation.x - mouse_motion.y,
		deg_to_rad(-89),
		deg_to_rad(89)
	)
	
	rotation.y -= mouse_motion.x
	
	scoreboard.visible = false


@rpc("any_peer", "call_local", "reliable")
func set_player_name(p_name: String) -> void:
	player_name = p_name
	name_label.text = p_name
