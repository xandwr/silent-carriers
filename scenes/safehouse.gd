## safehouse.gd
extends NetworkedScene

@export var player_buttons: ButtonArray
@export var cart_marker: Marker3D


func _ready() -> void:
	super._ready()
	
	if cart_marker and NetworkManager.is_host:
		spawn_cart("uid://cgt3vlotbeycq", cart_marker)
	
	# TODO: remove this later
	spawn_package(Vector3(-10, 5, -5))
	
	if player_buttons:
		player_buttons.setup_buttons_for_player_count(multiplayer.get_peers().size())
