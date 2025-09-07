extends StaticBody3D

# Asteroid properties
@export var health: float = 8.0 # Reduced health for quicker destruction
@export var rotation_speed: Vector3 = Vector3(0.2, 0.3, 0.1) # Random rotation speed
@export var shrink_rate: float = 0.05 # Increased shrink rate per hit
@export var min_scale: float = 0.2 # Smaller minimum scale before destruction

# Movement properties
var velocity: Vector3 = Vector3.ZERO

# Mining properties
var mineral_data: MultiMineralData
var is_mouse_hovering: bool = false

# Cached nodes
var mesh_instance: MeshInstance3D
var break_audio: AudioStreamPlayer3D
var impact_particles_scene = null
var active_particles = []
var is_shrinking: bool = false
var original_scale: Vector3
var target_scale: Vector3
var shrink_progress: float = 0.0
var particles_path = "res://scenes/asteroid_impact_particles.tscn"

func _ready():
	mesh_instance = $AsteroidMesh
	break_audio = get_node_or_null("BreakAudio")
	if not break_audio:
		push_warning("MovingAsteroid: BreakAudio node not found - break sound will be disabled")
	original_scale = scale
	# Apply a random rotation to make asteroids look different
	rotate_object_local(Vector3.UP, randf() * 2.0 * PI)
	
	# Add to asteroids group for scan detection
	add_to_group("asteroids")
	
	# Generate mineral data for this asteroid based on size
	mineral_data = MultiMineralData.generate_random_multi_mineral()
	# Scale mineral amounts based on asteroid size
	if mineral_data:
		var size_multiplier = scale.length() / Vector3(1, 1, 1).length()
		for mineral in mineral_data.minerals:
			mineral.amount *= size_multiplier * 2.0  # Larger asteroids have more ore
		mineral_data.update_properties()
		# Scale asteroid health based on total hardness
		health = 5.0 + (mineral_data.total_hardness * 2.0)  # Base 5 + hardness scaling
	
	# Set up mouse detection for hover tooltips
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	

# Set the movement direction and speed
func set_movement(new_velocity: Vector3):
	velocity = new_velocity

# Process for rotation, movement, and shrinking animation
func _process(delta):
	# Rotate the asteroid
	rotate_object_local(Vector3.RIGHT, rotation_speed.x * delta)
	rotate_object_local(Vector3.UP, rotation_speed.y * delta)
	rotate_object_local(Vector3.FORWARD, rotation_speed.z * delta)
	
	# Move the asteroid
	if velocity != Vector3.ZERO:
		global_position += velocity * delta
		# Keep asteroid on same Y-axis as player for laser collision
		var player = get_tree().get_first_node_in_group("player")
		if player:
			global_position.y = player.global_position.y
	
	# Handle shrinking animation
	if is_shrinking:
		shrink_progress += delta * 1.0  # Slower animation speed
		if shrink_progress >= 1.0:
			shrink_progress = 1.0
			is_shrinking = false
		
		scale = original_scale.lerp(target_scale, shrink_progress)
	
	# Clean up finished particle systems
	for i in range(active_particles.size() - 1, -1, -1):
		if not active_particles[i].emitting:
			active_particles[i].queue_free()
			active_particles.remove_at(i)
			
	# Check if asteroid is too far from the center and should be removed
	var system_boundary = 4000.0  # Match player system boundary
	if global_position.length() > system_boundary:
		queue_free()

# Handle damage
func take_damage(amount: float):
	# Scale damage based on total mineral hardness - harder minerals take much less damage
	var damage_resistance = 0.0
	if mineral_data:
		damage_resistance = (mineral_data.total_hardness / 10.0) * 0.9  # 0.18 to 0.9 resistance
	
	health -= amount * (1.0 - damage_resistance)  # Heavily reduce damage based on hardness
	
	# Try to load particle scene if not already loaded
	if impact_particles_scene == null:
		if ResourceLoader.exists(particles_path):
			impact_particles_scene = load(particles_path)
		else:
			push_warning("Asteroid impact particles scene not found: " + particles_path)
	
	# Spawn impact particles if available
	if impact_particles_scene != null:
		var impact_particles = impact_particles_scene.instantiate()
		add_child(impact_particles)
		
		# Position particles at a random point on asteroid's surface (simplified)
		var random_dir = Vector3(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0, randf() * 2.0 - 1.0).normalized()
		var offset = random_dir * 1.5  # Adjust based on asteroid size
		impact_particles.position = offset
		impact_particles.emitting = true
		active_particles.append(impact_particles)
	
	# Shrink the asteroid
	original_scale = scale
	target_scale = original_scale * (1.0 - shrink_rate)
	shrink_progress = 0.0
	is_shrinking = true
	
	# Check if asteroid is destroyed
	if health <= 0 or target_scale.length() < min_scale:
		destroy()

# Mouse hover detection
func _on_input_event(_camera: Camera3D, _event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int):
	pass

func _on_mouse_entered():
	is_mouse_hovering = true
	# Tooltip disabled - using new scan system instead
	# show_mineral_tooltip()

func _on_mouse_exited():
	is_mouse_hovering = false
	# Tooltip disabled - using new scan system instead
	# hide_mineral_tooltip()

# Show mineral information tooltip
func show_mineral_tooltip():
	if mineral_data:
		var tooltip_text = ""
		if mineral_data.has_method("get_total_value"):
			# Multi-mineral asteroid
			tooltip_text = "Multi-Ore Asteroid (%d types)\nTotal Value: %d credits" % [
				mineral_data.minerals.size(),
				mineral_data.get_total_value()
			]
		else:
			# Single mineral asteroid
			tooltip_text = "%s\nAmount: %.1f units\nValue: %d credits/unit\nHardness: %.1f" % [
				mineral_data.display_name,
				mineral_data.amount,
				mineral_data.value_per_unit,
				mineral_data.hardness
			]
		# Show tooltip (this would need a tooltip system)
		print("Tooltip: ", tooltip_text)
		var ui_manager = get_tree().get_first_node_in_group("ui_manager")
		if ui_manager and ui_manager.has_method("show_tooltip"):
			ui_manager.show_tooltip(tooltip_text, global_position)

# Hide mineral information tooltip
func hide_mineral_tooltip():
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("hide_tooltip"):
		ui_manager.hide_tooltip()

# Full destruction of the asteroid
func destroy():
	# Notify player that this asteroid is being destroyed
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("on_asteroid_destroyed"):
		player.on_asteroid_destroyed(self)
	
	# Create a detached audio player for the break sound
	if break_audio and break_audio.stream and is_inside_tree():
		var detached_audio = AudioStreamPlayer3D.new()
		detached_audio.stream = break_audio.stream
		detached_audio.volume_db = break_audio.volume_db
		detached_audio.global_position = global_position
		
		# Add to parent so it persists after asteroid is destroyed
		var parent = get_parent()
		if parent:
			parent.add_child(detached_audio)
			detached_audio.play()
			
			# Auto-remove the audio player after the sound finishes
			detached_audio.finished.connect(func(): detached_audio.queue_free())
	
	# Drop minerals when destroyed
	drop_minerals()
	
	# Try to load particle scene if not already loaded
	if impact_particles_scene == null:
		if ResourceLoader.exists(particles_path):
			impact_particles_scene = load(particles_path)
	
	# Create final explosion effect if particles are available
	if impact_particles_scene != null and is_inside_tree():
		var final_explosion = impact_particles_scene.instantiate()
		var parent = get_parent()
		if parent:
			parent.add_child(final_explosion)
			final_explosion.global_position = global_position
			
			# Make the final explosion much bigger and more dramatic
			final_explosion.amount = 120
			final_explosion.lifetime = 2.0
			final_explosion.explosiveness = 1.0
			if final_explosion.process_material:
				final_explosion.process_material.initial_velocity_min = 12.0
				final_explosion.process_material.initial_velocity_max = 20.0
				final_explosion.process_material.emission_sphere_radius = 1.5
				final_explosion.process_material.scale_min = 0.8
				final_explosion.process_material.scale_max = 1.8
			final_explosion.emitting = true
	
	# Remove the asteroid immediately
	queue_free()

# Drop minerals when asteroid is destroyed
func drop_minerals():
	if mineral_data:
		# Find the player to give minerals to
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("collect_multi_minerals"):
			player.collect_multi_minerals(mineral_data)

func _on_destroyed():
	# Drop minerals when destroyed
	if mineral_data:
		# Find the player to give minerals to
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("collect_minerals"):
			player.collect_minerals(mineral_data)
	
	# Remove from minimap before destroying
	var minimap = get_tree().get_first_node_in_group("minimap")
	if not minimap:
		var root = get_tree().current_scene
		minimap = root.find_child("Minimap", true, false)
	
	if minimap and minimap.has_method("remove_asteroid"):
		minimap.remove_asteroid(self)
	
	queue_free()
