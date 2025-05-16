## game.gd
extends Node3D

@export var player_scene: PackedScene

@onready var players_container: Node = $MultiplayerSpawner/Players
@onready var menu: Control = $MainMenu
@onready var nick_input: LineEdit = $MainMenu/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/NameEdit

@onready var message: LineEdit = $MultiplayerChat/Message
@onready var send: Button = $MultiplayerChat/Send
@onready var chat: TextEdit = $MultiplayerChat/Chat
@onready var multiplayer_chat: Control = $MultiplayerChat

var chat_visible = false


func _ready():
	multiplayer_chat.hide()
	menu.show()
	multiplayer_chat.set_process_input(true)
	if not multiplayer.is_server():
		return
		
	Network.player_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_remove_player)


func _on_player_connected(peer_id, player_info):
	_add_player(peer_id, player_info)


func _on_host_pressed():
	menu.hide()
	Network.start_host()


func _on_join_pressed():
	menu.hide()
	Network.join_game(nick_input.text.strip_edges(), "127.0.0.1")


func _add_player(id: int, _player_info : Dictionary):
	if players_container.has_node(str(id)) or not multiplayer.is_server() or id == 1: return
	
	var player = player_scene.instantiate()
	player.name = str(id)
	players_container.add_child(player, true)
	player.position = get_spawn_point()
	
	var nick = Network.players[id]["nick"]
	player.rpc("change_nick", nick)
	
	rpc("sync_player_position", id, player.position)


func get_spawn_point() -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI)
	return Vector3(spawn_point.x, 0, spawn_point.y)


func _remove_player(id):
	if not multiplayer.is_server() or not players_container.has_node(str(id)): return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()


@rpc("any_peer", "call_local")
func sync_player_position(id: int, new_position: Vector3):
	var player = players_container.get_node(str(id))
	if player:
		player.position = new_position


func _on_quit_pressed() -> void:
	get_tree().quit()


func toggle_chat():
	if menu.visible:
		return

	chat_visible = !chat_visible
	if chat_visible:
		multiplayer_chat.show()
		message.grab_focus()
	else:
		multiplayer_chat.hide()
		get_viewport().set_input_as_handled()


func is_chat_visible() -> bool:
	return chat_visible


func _input(event):
	if event.is_action_pressed("toggle_chat"):
		toggle_chat()
	elif event is InputEventKey and event.keycode == KEY_ENTER:
		_on_send_pressed()


func _on_send_pressed() -> void:
	var trimmed_message = message.text.strip_edges()
	if trimmed_message == "": return

	var nick = Network.players[multiplayer.get_unique_id()]["nick"]
	
	rpc("msg_rpc", nick, trimmed_message)
	message.text = ""
	message.grab_focus()


@rpc("any_peer", "call_local")
func msg_rpc(nick, msg):
	chat.text += str(nick, " : ", msg, "\n")
