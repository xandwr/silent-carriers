class_name PeerManager extends Node

var network_manager: NetworkManager:
	set(value):
		print("%s (%d) network_manager set to: %s" % [name, multiplayer.get_unique_id(), value])


func _ready() -> void:
	deactivate()


func activate() -> void:
	set_process(true)
	print("%s (%d) activated" % [name, multiplayer.get_unique_id()])


func deactivate() -> void:
	set_process(false)
	print("%s (%d) deactivated" % [name, multiplayer.get_unique_id()])
