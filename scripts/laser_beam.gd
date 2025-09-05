extends Node3D

# Laser beam visual properties
@export var laser_color: Color = Color(1.0, 0.0, 0.0, 0.7)  # Red with some transparency
@export var laser_width: float = 0.1
@export var max_length: float = 100.0
@export var energy: float = 2.0

# Components
var ray_cast: RayCast3D
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D

func _ready():
	# Create the raycast for hit detection
	ray_cast = RayCast3D.new()
	ray_cast.target_position = Vector3(0, 0, -max_length)  # Points forward along -Z axis
	ray_cast.collision_mask = 1  # Set your collision mask
	add_child(ray_cast)
	
	# Create material for the laser beam
	material = StandardMaterial3D.new()
	material.albedo_color = laser_color
	material.emission_enabled = true
	material.emission = laser_color
	material.emission_energy_multiplier = energy
	material.flags_transparent = true
	material.flags_unshaded = true
	material.billboard_mode = StandardMaterial3D.BILLBOARD_DISABLED
	
	# Create mesh instance for the laser visual
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	# Start with the laser deactivated
	set_laser_active(false)

# Turn the laser on or off
func set_laser_active(active: bool):
	ray_cast.enabled = active
	mesh_instance.visible = active

# Update the laser beam based on the raycast result
func _process(delta):
	if not ray_cast.enabled:
		return
	
	# Force the raycast to update
	ray_cast.force_raycast_update()
	
	# Determine the laser length based on collision
	var laser_length = max_length
	if ray_cast.is_colliding():
		var collision_point = ray_cast.get_collision_point()
		laser_length = global_position.distance_to(collision_point)
		
		# You can handle hit effects here
		var collider = ray_cast.get_collider()
		if collider.has_method("take_damage"):
			collider.take_damage(1.0)  # Damage per frame
	
	# Create or update the laser mesh
	_update_laser_mesh(laser_length)

# Create or update the laser mesh based on length
func _update_laser_mesh(length: float):
	# Create a simple cylinder mesh for the laser
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = laser_width / 2.0
	cylinder.bottom_radius = laser_width / 2.0
	cylinder.height = length
	cylinder.radial_segments = 8  # Lower for better performance
	
	# Set the material and update the mesh
	cylinder.material = material
	mesh_instance.mesh = cylinder
	
	# Position the cylinder so it extends from origin along -Z
	mesh_instance.position = Vector3(0, 0, -length/2)
	# Rotate it so it points along the Z-axis
	mesh_instance.rotation_degrees = Vector3(90, 0, 0)

# Example function to activate the laser
func fire_laser():
	set_laser_active(true)

# Example function to deactivate the laser
func stop_laser():
	set_laser_active(false)
