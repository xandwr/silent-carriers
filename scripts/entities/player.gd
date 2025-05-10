class_name Player extends CharacterBody3D


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:	
	if is_multiplayer_authority():
		# Authority peer handles physics and input
		set_physics_process(true)
		set_process_input(true)
	else:
		# Non-authority peers only run visual updates
		set_physics_process(false)
		set_process_input(false)


func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
