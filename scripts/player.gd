extends CharacterBody3D
class_name Character

# MOVEMENT
const MOVE_SPEED := 3.2
const SPRINT_MULTIPLIER := 2.0
const JUMP_FORCE := 6.0
const GRAVITY := 20.0
const STOP_SPEED := 1.0
const MAX_SPEED_GROUND = (ACCELERATE * MOVE_SPEED * SPRINT_MULTIPLIER) / FRICTION
const MAX_SPEED_AIR := 6.0
const ACCELERATE := 7.0
const AIR_ACCELERATE := 3.0
const FRICTION := 8.0
const AIR_CAP := 0.5
const SURF_FRICTION := 0.1

# CROUCHING
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.3
const CROUCH_SPEED_MULTIPLIER := 0.5
const CROUCH_TRANSITION_SPEED := 8.0

@onready var camera: Camera3D = $CamPivot/Camera3D
@onready var cam_pivot: Node3D = $CamPivot
@onready var nickname: Label3D = $Nickname
@onready var player_mesh: MeshInstance3D = $PlayerVisuals/Armature/Skeleton3D/PlayerMesh

@onready var anim_tree: AnimationTree = $AnimationTree
## X: (0.0 -> 1.0) -> (idle, walk, run)
## Y: (1.0 = crouch, 0.0 = idle, -1.0 = falling)
@onready var anim_blend_vector: Vector2 = anim_tree.get("parameters/BlendTree/BlendSpace2D/blend_position")

var current_anim_blend_vector: Vector2 = Vector2.ZERO
var last_synced_anim_blend_vector = Vector2.ZERO
var current_blend: Vector2 = Vector2.ZERO

var mouse_locked: bool = false

var wish_dir: Vector3 = Vector3.ZERO
var input_vector: Vector2 = Vector2.ZERO
var speed: float = 0.0
var sprinting: bool = false
var is_crouching: bool = false
var current_height: float = STAND_HEIGHT
	
var current_anim_speed = 1.0

var yaw: float = 0.0
var pitch: float = 0.0

var mouse_sens: float = 0.1

var _respawn_point: Vector3 = Vector3(0, 0, 0)


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())


func _ready():
	var current_coll_shape = $CollisionShape3D.shape.duplicate()
	$CollisionShape3D.shape = current_coll_shape
	
	camera.current = is_multiplayer_authority()
	if multiplayer.is_server():
		camera.current = false
	
	yaw = rotation_degrees.y
	pitch = cam_pivot.rotation_degrees.x
	
	if is_multiplayer_authority():
		player_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		mouse_locked = !mouse_locked
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_locked else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion and mouse_locked:
		yaw -= event.relative.x * mouse_sens
		pitch -= event.relative.y * mouse_sens
		pitch = clamp(pitch, -89.0, 89.0)
		
		cam_pivot.rotation_degrees.x = pitch
		rotation_degrees.y = yaw


func _physics_process(delta):
	if not is_multiplayer_authority(): return

	if get_tree().get_current_scene().has_method("is_chat_visible") and get_tree().get_current_scene().is_chat_visible():
		return
	
	process_input()
	
	var target_height := STAND_HEIGHT
	sprinting = Input.is_action_pressed("sprint")
	is_crouching = Input.is_action_pressed("crouch")
	
	if is_crouching:
		target_height = CROUCH_HEIGHT
	current_height = lerp(current_height, target_height, delta * CROUCH_TRANSITION_SPEED)
	
	$CollisionShape3D.shape.height = current_height
	$PlayerVisuals.position.y = (STAND_HEIGHT - current_height) * 0.5
	cam_pivot.position.y = current_height - 0.2
	
	if is_on_floor():
		var horizontal_velocity := velocity
		horizontal_velocity.y = 0
		var decel = STOP_SPEED * delta
		velocity.x = move_toward(velocity.x, 0, decel)
		velocity.z = move_toward(velocity.z, 0, decel)
		apply_friction(delta)
		if is_crouching:
			accelerate(delta, ACCELERATE, MOVE_SPEED * CROUCH_SPEED_MULTIPLIER)
		elif sprinting:
			accelerate(delta, ACCELERATE, MOVE_SPEED * SPRINT_MULTIPLIER)
		else:
			accelerate(delta, ACCELERATE, MOVE_SPEED)
	else:
		apply_gravity(delta)
		accelerate(delta, AIR_ACCELERATE, MOVE_SPEED)
	
	handle_jump()
	move_and_slide()
	
	speed = Vector2(velocity.x, velocity.z).length()
	var normalized_speed = clamp(speed / MAX_SPEED_GROUND, 0.0, 1.0)
	if is_crouching and normalized_speed > 0.05:
		normalized_speed = lerp(normalized_speed, 0.5, delta * 8.0)
	var target_blend: Vector2
	
	if not is_on_floor():
		target_blend = Vector2(normalized_speed, -1.0)
	elif Input.is_action_pressed("crouch"):
		target_blend = Vector2(normalized_speed, 1.0)
	else:
		target_blend = Vector2(normalized_speed, 0.0)
	
	current_blend = lerp(current_blend, target_blend, delta * 4.0)
	current_anim_blend_vector = current_blend
	anim_tree.set("parameters/BlendTree/BlendSpace2D/blend_position", current_anim_blend_vector)
	
	if sprinting:
		current_anim_speed = lerp(current_anim_speed, 1.8, delta * 4.0)
	elif is_crouching:
		current_anim_speed = lerp(current_anim_speed, 1.6, delta * 4.0)
	else:
		current_anim_speed = lerp(current_anim_speed, 1.0, delta * 4.0)
	anim_tree.set("parameters/BlendTree/TimeScale/scale", current_anim_speed)
	
	if current_anim_blend_vector != last_synced_anim_blend_vector:
		last_synced_anim_blend_vector = current_anim_blend_vector
		rpc("remote_set_anim_state", current_anim_blend_vector)
	
	if global_position.y < -50.0:
		var current_vel = velocity
		_respawn()
		velocity = current_vel
		global_position.y += 20.0


func process_input():
	input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	wish_dir = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()


func apply_friction(delta):
	var speed = velocity.length()
	
	if speed < 0.1:
		velocity = Vector3.ZERO
		return
	
	var control = max(STOP_SPEED, speed)
	var drop = control * FRICTION * delta
	
	var new_speed = max(speed - drop, 0)
	if new_speed != 0:
		new_speed /= speed
		velocity *= new_speed


func accelerate(delta, accel_value, max_speed):
	var current_speed = velocity.dot(wish_dir)
	var add_speed = max_speed - current_speed
	
	if add_speed <= 0:
		return
		
	var accel_amount = accel_value * delta * max_speed
	if accel_amount > add_speed:
		accel_amount = add_speed
	
	velocity += wish_dir * accel_amount
	
	if not is_on_floor():
		var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
		var current_horizontal_speed = horizontal_vel.length()
		
		if current_horizontal_speed > MAX_SPEED_AIR:
			var new_scale = MAX_SPEED_AIR / current_horizontal_speed
			velocity.x *= new_scale
			velocity.z *= new_scale


func apply_gravity(delta):
	velocity.y -= GRAVITY * delta


func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_FORCE


func _respawn():
	global_position = _respawn_point
	velocity = Vector3.ZERO


@rpc("any_peer", "reliable")
func change_nick(new_nick: String):
	if nickname:
		nickname.text = new_nick


@rpc("reliable")
func remote_set_anim_state(blend_vector: Vector2):
	if is_multiplayer_authority(): return
	anim_tree.set("parameters/BlendTree/BlendSpace2D/blend_position", blend_vector)
