extends Node3D

# Using 10,000,000 stars (200x the previous 50,000)
@export var star_count: int = 10000000
@export var field_size: Vector3 = Vector3(400, 200, 400)

func _ready():
	# Create multiple particle systems for better performance
	create_particle_system(star_count / 4, Vector3(0, 0, 0), 1.0)
	create_particle_system(star_count / 4, Vector3(0, 0, 0), 0.8)
	create_particle_system(star_count / 4, Vector3(0, 0, 0), 0.6)
	create_particle_system(star_count / 4, Vector3(0, 0, 0), 0.4)

# Create a particle system with the given number of stars
func create_particle_system(count: int, position: Vector3, size_multiplier: float):
	# Create a GPUParticles3D node for efficient rendering
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.amount = count
	particles.lifetime = 999999  # Very long lifetime so stars stay visible
	particles.explosiveness = 1.0  # Emit all particles at once
	particles.fixed_fps = 0  # No need for frequent updates
	particles.visibility_aabb = AABB(Vector3(-field_size.x/2, -field_size.y/2, -field_size.z/2), field_size)
	particles.process_material = create_particle_material(size_multiplier)
	particles.draw_pass_1 = create_star_mesh(size_multiplier)
	
	# Add the particle system to the scene
	add_child(particles)

# Create the particle material
func create_particle_material(size_multiplier: float) -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	
	# Set emission box shape
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = field_size / 2
	
	# No gravity or movement
	material.gravity = Vector3.ZERO
	material.direction = Vector3.ZERO
	material.spread = 180.0
	material.initial_velocity_min = 0.0
	material.initial_velocity_max = 0.0
	
	# Random size variation - wider range for more variety
	material.scale_min = 0.3 * size_multiplier
	material.scale_max = 0.5 * size_multiplier
	
	return material

# Create the star mesh
func create_star_mesh(size_multiplier: float) -> SphereMesh:
	var mesh = SphereMesh.new()
	
	# Create a material for the stars
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1, 1, 1)
	material.emission_enabled = true
	material.emission = Color(1, 1, 1)
	material.emission_energy_multiplier = 3.0
	
	# Apply material and set size - much bigger stars
	mesh.material = material
	mesh.radius = 1.0 * size_multiplier
	mesh.height = 2.0 * size_multiplier
	
	return mesh
