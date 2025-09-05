extends Node3D

# Laser beam properties
@export var laser_color: Color = Color(1.0, 0.3, 0.1, 1.0)  # Orange-red with full opacity
@export var core_width: float = 0.2  # Wider core beam
@export var particle_width: float = 0.4  # Wider particles
@export var max_length: float = 100.0
@export var energy: float = 4.0  # More energy for brightness

# Components
var ray_cast: RayCast3D
var core_mesh: MeshInstance3D
var core_material: StandardMaterial3D
var particles: GPUParticles3D
var particle_material: ParticleProcessMaterial

# Hit effect
var hit_particles: GPUParticles3D
var is_active: bool = false

func _ready():
	# Get references to the scene nodes
	ray_cast = $RayCast3D
	core_mesh = $CoreMesh
	particles = $BeamParticles
	hit_particles = $HitParticles
	
	if not ray_cast or not core_mesh or not particles or not hit_particles:
		push_error("Laser beam missing required child nodes!")
		return
	
	# Set up the raycast
	ray_cast.target_position = Vector3(0, 0, -max_length)
	ray_cast.enabled = true
	
	# Get references to materials
	if core_mesh.mesh and core_mesh.mesh.material:
		core_material = core_mesh.mesh.material
	else:
		push_error("Core mesh or material not found")
		return
		
	if particles.process_material:
		particle_material = particles.process_material
	else:
		push_error("Particle material not found")
		return
	
	# Update materials with current settings
	_update_materials()
	
	# Start with laser inactive
	set_laser_active(false)

func _update_materials():
	# Update core beam material
	core_material.albedo_color = laser_color
	core_material.emission = laser_color
	core_material.emission_energy_multiplier = energy * 1.5  # Core is brighter
	
	# Update particle materials
	particle_material.color = laser_color
	
	# Update the mesh dimensions
	_update_core_beam(max_length)
	_update_particles(max_length)

# No longer needed as particles are set up in the scene

# No longer needed as hit particles are set up in the scene

# No longer needed as materials are set up in the scene

func set_laser_active(active: bool):
	is_active = active
	ray_cast.enabled = active
	core_mesh.visible = active
	particles.emitting = active
	
	if not active:
		hit_particles.emitting = false

func _process(delta):
	if not is_active:
		return
	
	# Update raycast and get hit information
	ray_cast.force_raycast_update()
	var beam_length = max_length
	
	if ray_cast.is_colliding():
		var collision_point = ray_cast.get_collision_point()
		var collision_normal = ray_cast.get_collision_normal()
		beam_length = global_position.distance_to(collision_point)
		
		# Position hit particles at collision point
		hit_particles.global_position = collision_point
		
		# Orient particles based on the collision normal
		if collision_normal != Vector3.ZERO:
			# Calculate rotation to face along the normal
			var look_at_pos = collision_point + collision_normal
			hit_particles.look_at(look_at_pos, Vector3.UP)
		
		# Ensure particles are emitting
		if not hit_particles.emitting:
			hit_particles.restart()
			hit_particles.emitting = true
		
		# Apply damage to the target if it has the method
		var collider = ray_cast.get_collider()
		if collider:
			# Check specifically for asteroid collisions
			if collider.has_method("take_damage"):
				collider.take_damage(0.1)
	else:
		# No collision, disable hit particles
		if hit_particles.emitting:
			hit_particles.emitting = false
	
	# Update the core beam
	_update_core_beam(beam_length)
	
	# Update the particles
	_update_particles(beam_length)

func _update_core_beam(length: float):
	# Create cylinder for laser core
	var cylinder = CylinderMesh.new()
	
	# Configure cylinder dimensions
	cylinder.top_radius = core_width / 2.0
	cylinder.bottom_radius = core_width / 2.0
	cylinder.height = length
	cylinder.radial_segments = 8
	
	# Make a fresh copy of the core material to avoid reference issues
	var new_material = StandardMaterial3D.new()
	new_material.albedo_color = laser_color
	new_material.emission_enabled = true
	new_material.emission = laser_color
	new_material.emission_energy_multiplier = energy * 1.5
	
	# Set transparency mode to Alpha Blend
	new_material.transparency = 1 # StandardMaterial3D.TRANSPARENCY_ALPHA
	
	# Set to unshaded for better visibility
	new_material.shading_mode = 0 # StandardMaterial3D.SHADING_MODE_UNSHADED
	
	# Make sure the material is rendered in front of other objects
	new_material.render_priority = 1
	
	# Ensure no culling so beam is visible from all angles
	new_material.cull_mode = 0 # CULL_BACK
	
	# Apply material to the cylinder
	cylinder.material = new_material
	core_material = new_material
	
	# Update the mesh
	core_mesh.mesh = cylinder
	
	# Position cylinder along -Z axis
	core_mesh.position = Vector3(0, 0, -length/2)
	core_mesh.rotation_degrees = Vector3(90, 0, 0)
	
	# Ensure it's visible
	core_mesh.visible = is_active

func _update_particles(length: float):
	# Update particle system size based on beam length
	if particle_material:
		# ParticleProcessMaterial uses emission_shape and emission_box_extents in Godot 4
		if particle_material.get("emission_shape") != null:
			particle_material.emission_shape = 3 # 3 = BOX in Godot 4
			
		var extents = Vector3(particle_width, particle_width, length/2)
		# Different property access based on Godot version
		if particle_material.has_method("set_emission_box_extents"):
			particle_material.set_emission_box_extents(extents)
		elif particle_material.get("emission_box_extents") != null:
			particle_material.emission_box_extents = extents
		
	# Reposition particle system
	particles.position = Vector3(0, 0, -length/2)

# Fire the laser
func fire():
	set_laser_active(true)

# Stop the laser
func stop():
	set_laser_active(false)

# Change laser color at runtime
func set_color(new_color: Color):
	laser_color = new_color
	
	# Update core beam color
	core_material.albedo_color = new_color
	core_material.emission = new_color
	
	# Update particle colors
	particle_material.color = new_color
