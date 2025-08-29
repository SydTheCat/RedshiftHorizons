extends Node3D

@export var rotation_speed: Vector3 = Vector3(0, 0.2, 0)  # Degrees per second

func _process(delta):
	rotate_y(deg_to_rad(rotation_speed.y * delta))
	rotate_x(deg_to_rad(rotation_speed.x * delta))
	rotate_z(deg_to_rad(rotation_speed.z * delta))
