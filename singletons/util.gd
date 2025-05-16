## Util.gd
extends Node


func _ready() -> void:
	parse_cmd_args()


func parse_cmd_args():
	var args = OS.get_cmdline_args()
	var player_name := ""
	var is_host := false
	var is_client := false

	for arg in args:
		if arg.begins_with("name_"):
			player_name = arg.split("_")[1]
		elif arg == "host":
			is_host = true
		elif arg == "client":
			is_client = true

	await get_tree().process_frame

	if is_host:
		Network.start_host()
		await get_tree().process_frame
		get_window().title = "Server"
		_get_menu().hide()

		# Minimize the server window
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

	elif is_client:
		Network.join_game(player_name)
		await get_tree().process_frame
		get_window().title = "Client %s" % player_name
		_get_menu().hide()

		# Resize and reposition clients
		var index = 0 if (player_name == "A") else 1
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DisplayServer.window_set_position(Vector2i(1280 * index, 360))


func _get_menu() -> Control:
	return get_node("/root/Game/MainMenu")
