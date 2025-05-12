## safehouse.gd
extends NetworkedScene

@export var player_buttons: ButtonArray


func _ready() -> void:
	super._ready()
	
	# TODO: remove this later
	spawn_package(Vector3(-10, 5, -5))
	
	if player_buttons:
		player_buttons.setup_buttons_for_player_count(multiplayer.get_peers().size())
