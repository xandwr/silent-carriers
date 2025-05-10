class_name Game extends Node


func _ready() -> void:
	ImGuiGD.Connect(_on_imgui_layout)
	
	var cmd_args = OS.get_cmdline_args()
	
	for arg in cmd_args:
		if arg.begins_with("pos_"):
			var parts = arg.split("_")
			if parts.size() >= 3:
				var x := int(parts[1])
				var y := int(parts[2])
				
				await get_tree().process_frame
				DisplayServer.window_set_position(Vector2i(x, y))
		if arg == "host":
			get_window().title = "Silent Carriers - Host"
		if arg == "client":
			get_window().title = "Silent Carriers - Client (%d)" % multiplayer.get_unique_id()


func _on_imgui_layout() -> void:
	ImGui.Begin("Debug")
	ImGui.SetWindowSize(Vector2(200, 100))
	
	ImGui.Text("Peer ID: %s" % multiplayer.get_unique_id())
	ImGui.Text("Player Name: %s" % GameManager.player_instance.name if GameManager.player_instance else "<null>")
	
	ImGui.End()
