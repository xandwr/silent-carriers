class_name Player extends CharacterBody3D

@export var walk_speed: float = 3.5
@export var mouse_sensitivity: float = 0.001

@onready var camera_pivot: Marker3D = $CameraPivot
@onready var player_camera: Camera3D = $CameraPivot/PlayerCamera

@onready var player_mesh: MeshInstance3D = $PlayerCapsuleMesh
@onready var player_eyes_mesh: MeshInstance3D = $PlayerCapsuleMesh/EyesMesh


var mouse_locked: bool = true:
	set(value):
		mouse_locked = value
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
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


func _process_movement(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	var input_dir: Vector2
	if mouse_locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	else:
		input_dir = Vector2.ZERO
	
	var move_dir = transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	
	velocity = move_dir * walk_speed
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
