class_name PhysicalButton extends Area3D

signal toggled(activated: bool, peer_id: int, button_index: int)

@export var button_mesh_path: NodePath
@export var button_index: int = -1
@export var press_rotation:Vector3 = Vector3(0.3, 0, 0)
@export var pressed_duration: float = 0.2
@export var toggle_mode: bool = false
@export var indicator_shader: Shader

var _button_mesh: MeshInstance3D
var _original_rotation: Vector3

var _indicator: ShaderMaterial
var _last_owner_peer_id: int = -999

@export var is_activated: bool = false:
	set(value):
		is_activated = value
		_sync_visual()

@export var owner_peer_id: int = 1


func _ready():
	if button_mesh_path != NodePath():
		_button_mesh = get_node(button_mesh_path)
		_original_rotation = _button_mesh.rotation
		
	if _button_mesh:
		# Force material uniqueness per instance
		var mat := _button_mesh.get_active_material(0)
		if mat:
			_button_mesh.set_surface_override_material(0, mat.duplicate())
	
	if indicator_shader:
		_indicator = ShaderMaterial.new()
		_indicator.shader = indicator_shader
	
	_sync_visual()
	
	_update_indicator()


func _process(_delta):
	if owner_peer_id != _last_owner_peer_id:
		_last_owner_peer_id = owner_peer_id
		_update_indicator()


func activate():
	if toggle_mode:
		if multiplayer.is_server():
			# Server toggles and syncs
			_toggle_state()
			rpc("sync_toggle_state", is_activated)
		else:
			rpc_id(1, "request_toggle")
	else:
		_press_animation()


func activate_by(peer_id: int):
	if owner_peer_id <= 0:
		print("Button has no assigned owner yet; ignoring input.")
		return
	
	if peer_id != owner_peer_id:
		print("Peer", peer_id, "is not allowed to toggle this button. Owner is", owner_peer_id)
		return
	
	if toggle_mode:
		if multiplayer.is_server():
			_toggle_state()
			rpc("sync_toggle_state", is_activated)
		else:
			rpc_id(1, "request_toggle_by")
	else:
		_press_animation()


func _press_animation():
	if not _button_mesh: return
	_button_mesh.rotation += press_rotation
	await get_tree().create_timer(pressed_duration).timeout
	_button_mesh.rotation = _original_rotation


@rpc("any_peer", "call_remote")
func request_toggle():
	if multiplayer.is_server():
		_toggle_state()
		rpc("sync_toggle_state", is_activated)


@rpc("any_peer", "call_remote")
func request_toggle_by(_dummy := 0):
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == owner_peer_id:
		_toggle_state()
		rpc("sync_toggle_state", is_activated)
	else:
		print("Rejected toggle attempt from unauthorized peer:", sender_id)


@rpc("authority", "call_remote")
func sync_toggle_state(new_state: bool):
	is_activated = new_state
	_sync_visual()


func _sync_visual():
	if not _button_mesh: return
	_button_mesh.rotation = _original_rotation + (press_rotation if is_activated else Vector3.ZERO)
	_update_indicator()


func _update_indicator():
	if not _button_mesh: return
	
	var my_id = multiplayer.get_unique_id()
	if owner_peer_id == my_id and !is_activated:
		_button_mesh.get_active_material(0).next_pass = _indicator
	else:
		_button_mesh.get_active_material(0).next_pass = null


func _toggle_state():
	is_activated = !is_activated
	_sync_visual()
	toggled.emit(is_activated, owner_peer_id, button_index)
