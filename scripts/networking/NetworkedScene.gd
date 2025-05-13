class_name NetworkedScene extends Node

@export var player_container: Node
@export var package_container: Node
@export var cart_container: Node

@onready var player_scene: PackedScene = preload("uid://bfd1m7fd2g0sj")
@onready var package_scene: PackedScene = preload("uid://paf44kxq6kf7")


func _ready() -> void:
	print("NetworkedScene loaded: %s" % name)
	GameManager.current_scene_name = name


func spawn_player(peer_id: int) -> Player:
	print("NetworkedScene spawning player %d" % peer_id)
	if not player_container:
		push_error("Player container not set in NetworkedScene %s!" % name)
		return null
	
	var player = player_scene.instantiate() as Player
	player.name = str(peer_id)
	
	print("Setting multiplayer authority for player %d" % peer_id)
	player_container.add_child(player, true)
	player.set_multiplayer_authority(peer_id)
	print("Player %d spawned successfully" % peer_id)
	return player


func spawn_package(position: Vector3) -> void:
	if not package_container:
		push_error("Package container not set in NetworkedScene %s!" % name)
		return
	
	var package = package_scene.instantiate()
	package.name = "Package"
	
	package_container.add_child(package, true)
	package.global_position = position
	package.set_multiplayer_authority(1)


func spawn_cart(cart_scene_path: String, marker: Marker3D) -> void:
	if not cart_container: return
	
	var cart_instance = load(cart_scene_path).instantiate()
	
	cart_container.add_child(cart_instance, true)
	cart_instance.global_transform = marker.global_transform
	cart_instance.set_multiplayer_authority(1)
