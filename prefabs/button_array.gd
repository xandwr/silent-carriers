class_name ButtonArray extends Node3D

@export var buttons_container: Node3D

var buttons: Array[PhysicalButton] = []
var assigned_buttons: Dictionary[int, int] = {} # peer_id -> button_index


func _ready() -> void:
	if not buttons_container: return
	
	NetworkManager.player_connected.connect(assign_buttons_to_connected_players)
	
	for child in buttons_container.get_children():
		buttons.append(child)


## index -> activated state
func set_button_states(button_states: Dictionary[int, bool]):
	for index in button_states:
		buttons[index].is_activated = button_states[index]


func setup_buttons_for_player_count(current_players: int) -> void:
	var total_buttons := buttons.size()
	var button_states: Dictionary[int, bool] = {}
	
	for i in total_buttons:
		# All buttons except the last `current_players` are active
		var is_active = i < total_buttons - current_players
		button_states[i] = is_active
	set_button_states(button_states)


func assign_buttons_to_connected_players(_peer_id: int):
	var peer_ids := multiplayer.get_peers()
	peer_ids.append(multiplayer.get_unique_id()) # include host
	peer_ids.sort() # stable order
	
	var total := buttons.size()
	var used = min(peer_ids.size(), total)
	
	for i in range(used):
		var peer_id = peer_ids[i]
		assigned_buttons[peer_id] = i
		var btn := buttons[i]
		btn.button_index = i
		btn.owner_peer_id = peer_id
		btn.toggle_mode = true
		
		if not btn.toggled.is_connected(_on_button_toggled):
			btn.toggled.connect(_on_button_toggled)
		
		btn.set_multiplayer_authority(1) # server owns all logic
		btn.is_activated = false
		btn._sync_visual()
	
	# Mark unused buttons as always-on (starting from the end)
	for i in range(used, total):
		buttons[i].owner_peer_id = -1
		buttons[i].is_activated = true
		buttons[i]._sync_visual()


func _on_button_toggled(is_active: bool, peer_id: int, index: int) -> void:
	if PlayerRegistry and PlayerRegistry.has_peer(peer_id):
		PlayerRegistry.set_player_ready(peer_id, is_active)
		print("Player %d toggled ready: %s" % [peer_id, is_active])
