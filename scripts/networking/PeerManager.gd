class_name PeerManager extends Node


func _ready() -> void:
	deactivate()


func activate() -> void:
	set_process(true)
	#print("%s (%d) activated" % [name, multiplayer.get_unique_id()])


func deactivate() -> void:
	set_process(false)
	#print("%s (%d) deactivated" % [name, multiplayer.get_unique_id()])
