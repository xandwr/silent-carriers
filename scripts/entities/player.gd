class_name Player extends CharacterBody3D


func _ready() -> void:
	if is_multiplayer_authority():
		# Authority peer handles physics and input
		set_physics_process(true)
		set_process_input(true)
	else:
		# Non-authority peers only run visual updates
		set_physics_process(false)
		set_process_input(false)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
