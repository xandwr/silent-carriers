class_name Pickable extends RigidBody3D

@export var held_by: int


@rpc("authority", "call_local")
func sync_held_by(new_holder: int) -> void:
	held_by = new_holder
