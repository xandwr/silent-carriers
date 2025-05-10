class_name PeerManager extends Node

var network_manager: NetworkManager:
	set(value):
		print("%s network_manager set to: %s" % [name, value])


func _ready() -> void:
	deactivate()


func activate() -> void:
	set_process(true)
	print("%s activated" % name)


func deactivate() -> void:
	set_process(false)
	print("%s deactivated" % name)
