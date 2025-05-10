## GameManager.gd
extends Node

var player_instance: Player
var current_scene_name: String
var local_player_name: String = ""


func _ready() -> void:
	local_player_name = "Host" if NetworkManager.is_host else "Client"
