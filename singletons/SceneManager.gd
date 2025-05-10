## SceneManager.gd
extends Node

const scenes: Dictionary[String, String] = {
	"safehouse": "uid://fwyi7j6degoj",
	"terrain": "uid://co5igpiwbylwf",
}

@onready var scene_spawner: MultiplayerSpawner = $"/root/Game/SceneSpawner"
@onready var scene_container: Node = $"/root/Game/CurrentScene"

var current_scene: Node = null
var is_multiplayer_mode: bool = false


func load_scene(path: String, is_networked: bool = false) -> void:
	print("SceneManager (%d) loading scene: %s" % [multiplayer.get_unique_id(), scenes.find_key(path)])
	if current_scene: current_scene.queue_free()
	for child in scene_container.get_children():
		child.queue_free()
	
	is_multiplayer_mode = is_networked
	
	var scene = load(path).instantiate()
	scene_container.add_child(scene, true)
	current_scene = scene
