extends Node3D

# Utility script for debugging laser beam functionality
# Attach to any scene that has a ParticleLaserBeam node

# Reference to the laser beam being debugged
@export var target_laser_path: NodePath
var laser_beam: Node3D

# Debug visualization
var debug_line: MeshInstance3D
var debug_material: StandardMaterial3D

func _ready():
	# Get reference to the laser beam
	if target_laser_path:
		laser_beam = get_node(target_laser_path)
	else:
		push_error("No laser path specified for debugging")
		return
		
	if not laser_beam:
		push_error("Failed to find laser beam at path: ", target_laser_path)
		return
		
	# Create debug visualization
	_setup_debug_line()
	
	# Create UI for laser debugging
	_setup_debug_ui()

func _setup_debug_line():
	# Create a simple line to show the laser path for debugging
	debug_line = MeshInstance3D.new()
	add_child(debug_line)
	
	# Create debug material (different from laser material)
	debug_material = StandardMaterial3D.new()
	debug_material.albedo_color = Color(1.0, 1.0, 0.0, 0.3)  # Yellow, semi-transparent
	debug_material.emission_enabled = true
	debug_material.emission = Color(1.0, 1.0, 0.0, 1.0)  # Yellow glow
	debug_material.emission_energy_multiplier = 1.0
	debug_material.transparency = 1  # Alpha blend

	# Make debug line initially invisible
	debug_line.visible = false

func _setup_debug_ui():
	# This would create UI controls for testing in a real implementation
	# We use keyboard shortcuts instead of UI controls

func _process(__delta):
	if laser_beam and laser_beam.is_active:
		# Update debug visualization
		_update_debug_line()

func _input(event):
	if not laser_beam:
		return
		
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_D:  # Toggle debug visualization
				debug_line.visible = !debug_line.visible
			KEY_F:  # Fire laser
				laser_beam.fire()
			KEY_G:  # Stop laser
				laser_beam.stop()
			KEY_H:  # Toggle laser
				if laser_beam.is_active:
					laser_beam.stop()
				else:
					laser_beam.fire()
			KEY_R:  # Change to red
				_change_laser_color(Color(1.0, 0.0, 0.0, 1.0))
			KEY_G:  # Change to green
				_change_laser_color(Color(0.0, 1.0, 0.0, 1.0))
			KEY_B:  # Change to blue
				_change_laser_color(Color(0.0, 0.5, 1.0, 1.0))

func _update_debug_line():
	if not laser_beam:
		return
		
	# Get laser beam data
	var ray_cast = laser_beam.ray_cast
	if not ray_cast:
		return
		
	# Create a simple line mesh for visualization
	var line_mesh = CylinderMesh.new()
	line_mesh.top_radius = 0.05
	line_mesh.bottom_radius = 0.05
	line_mesh.height = laser_beam.max_length
	line_mesh.radial_segments = 6
	line_mesh.material = debug_material
	
	# Update the debug line
	debug_line.mesh = line_mesh
	debug_line.position = Vector3(0, 0, -laser_beam.max_length / 2)
	debug_line.rotation_degrees = Vector3(90, 0, 0)
	
	# Draw hit position if there is a collision
	if ray_cast.is_colliding():
		var hit_pos = ray_cast.get_collision_point()
		
func _change_laser_color(new_color: Color):
	if laser_beam:
		laser_beam.set_color(new_color)
