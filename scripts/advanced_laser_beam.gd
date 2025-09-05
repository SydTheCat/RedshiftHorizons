extends Node3D

# Laser beam visual properties
@export var laser_color: Color = Color(0.0, 1.0, 0.5, 0.7)  # Green-blue with transparency
@export var laser_width: float = 0.2
@export var max_distance: float = 100.0
@export var pulse_speed: float = 2.0
@export var energy: float = 3.0

# Components
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var ray: RayCast3D
var time_passed: float = 0.0
var is_firing: bool = false
var hit_effect_scene = null

func _ready():
	# Setup raycast for collision detection
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -max_distance)
	ray.collision_mask = 1  # Adjust based on your collision layers
	add_child(ray)
	
	# Create material
	material = StandardMaterial3D.new()
	material.albedo_color = laser_color
	material.emission_enabled = true
	material.emission = laser_color
	material.emission_energy_multiplier = energy
	material.flags_transparent = true
	material.flags_unshaded = true
	
	# Create mesh instance
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	# Try to load a hit effect scene if available
	# Uncomment once you've created a hit effect scene
	# hit_effect_scene = load("res://scenes/laser_hit_effect.tscn")
	
	# Start inactive
	set_firing(false)

# Set the laser active/inactive state
func set_firing(active: bool):
	is_firing = active
	mesh_instance.visible = active
	ray.enabled = active

func _process(delta):
	if not is_firing:
		return
		
	# Update time for animated effects
	time_passed += delta
	
	# Create pulsing effect by modulating emission intensity
	var pulse_factor = (sin(time_passed * pulse_speed * PI) + 1.0) / 2.0  # 0 to 1 pulsing
	material.emission_energy_multiplier = energy * (0.7 + 0.3 * pulse_factor)
	
	# Update raycast
	ray.force_raycast_update()
	var actual_length = max_distance
	var hit_point = Vector3(0, 0, -max_distance)
	var hit_normal = Vector3.FORWARD
	
	if ray.is_colliding():
		hit_point = to_local(ray.get_collision_point())
		hit_normal = ray.get_collision_normal()
		actual_length = global_position.distance_to(ray.get_collision_point())
		
		# Handle hit effects
		_handle_collision(ray.get_collider(), ray.get_collision_point(), hit_normal)
	
	# Update the laser mesh with the accurate length
	_update_laser_mesh(actual_length)

# Update the laser mesh
func _update_laser_mesh(length: float):
	# Create a custom ImmediateMesh for more flexibility
	var mesh = ImmediateMesh.new()
	mesh.clear_surfaces()
	
	# Begin drawing the laser beam
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	
	# Half width for the laser
	var half_width = laser_width / 2.0
	
	# Create two points at the origin
	mesh.surface_set_color(laser_color)
	mesh.surface_set_uv(Vector2(0, 0))
	mesh.surface_add_vertex(Vector3(half_width, 0, 0))
	
	mesh.surface_set_color(laser_color)
	mesh.surface_set_uv(Vector2(0, 1))
	mesh.surface_add_vertex(Vector3(-half_width, 0, 0))
	
	# Create two points at the end of the beam
	mesh.surface_set_color(laser_color)
	mesh.surface_set_uv(Vector2(1, 0))
	mesh.surface_add_vertex(Vector3(half_width, 0, -length))
	
	mesh.surface_set_color(laser_color)
	mesh.surface_set_uv(Vector2(1, 1))
	mesh.surface_add_vertex(Vector3(-half_width, 0, -length))
	
	# End drawing
	mesh.surface_end()
	
	# Apply the mesh and material
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material

# Handle collision effects
func _handle_collision(collider, point, normal):
	# You can implement damage here
	if collider and collider.has_method("take_damage"):
		collider.take_damage(0.1)  # Adjust damage value as needed
	
	# Create hit effect if available
	if hit_effect_scene and randf() < 0.1:  # Only spawn effect occasionally to avoid performance issues
		var hit_effect = hit_effect_scene.instantiate()
		get_tree().root.add_child(hit_effect)
		hit_effect.global_position = point
		# Orient the effect based on the surface normal
		hit_effect.look_at(point + normal, Vector3.UP)

# Example functions to control the laser
func fire():
	set_firing(true)

func stop():
	set_firing(false)

# Change the laser color (can be called during runtime)
func set_color(new_color: Color):
	laser_color = new_color
	material.albedo_color = new_color
	material.emission = new_color
