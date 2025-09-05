extends StaticBody3D

# Asteroid properties
@export var health: float = 8.0 # Reduced health for quicker destruction
@export var rotation_speed: Vector3 = Vector3(0.2, 0.3, 0.1) # Random rotation speed
@export var shrink_rate: float = 0.05 # Increased shrink rate per hit
@export var min_scale: float = 0.2 # Smaller minimum scale before destruction

# Mining properties
var mineral_data: MineralData
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
		push_warning("Asteroid: BreakAudio node not found - break sound will be disabled")
	original_scale = scale
	# Apply a random rotation to make asteroids look different
	rotate_object_local(Vector3.UP, randf() * 2.0 * PI)
	
	# Add to asteroids group for scan detection
	add_to_group("asteroids")
	
	# Generate mineral data for this asteroid based on size
	mineral_data = MineralData.generate_random_mineral()
	# Scale mineral amount based on asteroid size
	if mineral_data:
		var size_multiplier = scale.length() / Vector3(1, 1, 1).length()
		mineral_data.amount *= size_multiplier * 2.0  # Larger asteroids have more ore
		# Scale asteroid health based on mineral hardness
		health = 5.0 + (mineral_data.hardness * 2.0)  # Base 5 + hardness scaling
	
	# Set up mouse detection for hover tooltips
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	

# Process for rotation and shrinking animation
func _process(delta):
	# Keep static asteroid on same Y-axis as player for laser collision
	var player = get_tree().get_first_node_in_group("player")
	if player:
		global_position.y = player.global_position.y
	
	# Rotate the asteroid
	rotate_object_local(Vector3.RIGHT, rotation_speed.x * delta)
	rotate_object_local(Vector3.UP, rotation_speed.y * delta)
	rotate_object_local(Vector3.FORWARD, rotation_speed.z * delta)
	
	# Handle shrinking animation
	if is_shrinking:
		shrink_progress += delta * 1.0  # Slower animation speed (was 2.0)
		if shrink_progress >= 1.0:
			shrink_progress = 1.0
			is_shrinking = false
		
		scale = original_scale.lerp(target_scale, shrink_progress)
	
	# Clean up finished particle systems
	for i in range(active_particles.size() - 1, -1, -1):
		if not active_particles[i].emitting:
			active_particles[i].queue_free()
			active_particles.remove_at(i)

# Handle damage
func take_damage(amount: float):
	# Scale damage based on mineral hardness - harder minerals take much less damage
	var damage_resistance = 0.0
	if mineral_data:
		damage_resistance = (mineral_data.hardness / 10.0) * 0.9  # 0.18 to 0.9 resistance
	
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
	
	# Check if asteroid is destroyed - destroy when scale reaches 0.7 or below
	if health <= 0 or scale.x <= 0.7 or scale.y <= 0.7 or scale.z <= 0.7:
		destroy()

# Mouse hover detection
func _on_input_event(_camera: Camera3D, _event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int):
	pass

func _on_mouse_entered():
	is_mouse_hovering = true
	# Show tooltip with mineral information
	show_mineral_tooltip()

func _on_mouse_exited():
	is_mouse_hovering = false
	# Hide tooltip
	hide_mineral_tooltip()

# Show mineral information tooltip
func show_mineral_tooltip():
	if mineral_data:
		var tooltip_text = "%s\nAmount: %.1f units\nValue: %d credits/unit\nHardness: %.1f" % [
			mineral_data.display_name,
			mineral_data.amount,
			mineral_data.value_per_unit,
			mineral_data.hardness
		]
		
		# Get the UI manager to show tooltip
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

# Drop minerals when asteroid is destroyed
func drop_minerals():
	if mineral_data:
		# Find the player to give minerals to
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("collect_mineral"):
			player.collect_mineral(mineral_data)
			
			# Show collection notification
			var ui_manager = get_tree().get_first_node_in_group("ui_manager")
			if ui_manager and ui_manager.has_method("show_collection_notification"):
				var total_value = mineral_data.amount * mineral_data.value_per_unit
				var message = "Collected %.1f %s (+%d credits)" % [
					mineral_data.amount,
					mineral_data.display_name,
					total_value
				]
				ui_manager.show_collection_notification(message)
