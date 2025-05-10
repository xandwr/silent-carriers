class_name NetworkedScene extends Node

## The node connected to a MultiplayerSpawner that we instance new players in for automatic replication.
@export var player_container: Node

## The player scene.
@onready var player_scene: PackedScene = preload("uid://bfd1m7fd2g0sj")


func _ready() -> void:
	print("NetworkedScene loaded: %s" % name)
	GameManager.current_scene_name = name


func spawn_player(peer_id: int) -> void:
	if not player_container:
		push_error("Player container not set in NetworkedScene %s!" % name)
		return
	
	var player = player_scene.instantiate() as Player
	player.name = str(peer_id)
	
	player.set_multiplayer_authority(peer_id)
	player_container.add_child(player, true)
