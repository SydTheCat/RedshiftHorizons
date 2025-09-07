extends Node3D

# Asteroid spawning properties
@export var asteroid_scene: PackedScene
@export var player_path: NodePath            # Path to player node for alignment
@export var enabled: bool = true              # Toggle spawning

# System-wide asteroid generation
@export var total_asteroids: int = 700        # Reduced asteroids for 4000x4000 system
@export var system_radius: float = 4000.0     # System boundary radius (4000x4000)
@export var safe_zone_radius: float = 200.0   # Scaled safe zone for larger system
@export var size_min: float = 0.5             # Minimum scale factor
@export var size_max: float = 2.5             # Maximum scale factor

# Density zones
@export var heavy_zone_count: int = 12         # More heavy zones for 4000x4000 system
@export var heavy_zone_radius: float = 200.0  # Scaled heavy zone radius
@export var heavy_zone_density: float = 2.5   # Slightly reduced density multiplier
@export var light_zone_density: float = 0.6   # Increased light zone density for better balance

# Private variables
var _player: Node3D
var _minimap: Control
var _rng = RandomNumberGenerator.new()
var _spawn_count: int = 0
var _active_asteroids: Array = []
var _heavy_zones: Array[Vector3] = []  # Positions of heavy density zones
var _spawning_complete: bool = false

# Called when the node enters the scene tree for the first time
func _ready():
	_rng.randomize()
	
	# Set up player reference - try multiple ways to find player
	if not player_path.is_empty():
		_player = get_node_or_null(player_path)
	
	# If player path didn't work, try to find player by name
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			# Try finding by common player node names
			var root = get_tree().current_scene
			_player = root.find_child("Player", true, false)
			if _player == null:
				_player = root.find_child("player", true, false)
	
	# Find minimap for asteroid tracking
	_minimap = get_tree().get_first_node_in_group("minimap")
	if _minimap == null:
		# Try finding minimap by name
		var root = get_tree().current_scene
		_minimap = root.find_child("Minimap", true, false)
	
	# Generate all asteroids at game start if enabled
	if enabled:
		generate_all_asteroids()

# Generate all asteroids at once at game start
func generate_all_asteroids():
	if asteroid_scene == null:
		push_warning("AsteroidSpawner: No asteroid scene set - spawning disabled")
		return
	
	print("Generating asteroid field...")
	
	# First, generate heavy density zone positions
	generate_heavy_zones()
	
	# Spawn all asteroids
	for i in range(total_asteroids):
		spawn_asteroid_at_start()
		# Small delay between spawns to prevent frame drops
		if i % 10 == 0:
			await get_tree().process_frame
	
	_spawning_complete = true
	show_completion_message()
	print("Asteroid field generation complete! Spawned ", total_asteroids, " asteroids")

# Generate positions for heavy density zones
func generate_heavy_zones():
	_heavy_zones.clear()
	
	for i in range(heavy_zone_count):
		# Generate random position within system but outside safe zone
		var angle = _rng.randf_range(0, 2.0 * PI)
		var distance = _rng.randf_range(safe_zone_radius + 400.0, system_radius * 0.8)
		
		var zone_pos = Vector3(
			cos(angle) * distance,
			0,  # Keep at Y=0 level
			sin(angle) * distance
		)
		
		_heavy_zones.append(zone_pos)
	
	print("Generated ", heavy_zone_count, " heavy density zones")

# Spawn a single asteroid during initial generation
func spawn_asteroid_at_start():
	# Calculate spawn position within system
	var spawn_position = _get_system_spawn_position()
	
	# Instantiate the asteroid
	var asteroid_instance = asteroid_scene.instantiate()
	
	# Name it uniquely
	_spawn_count += 1
	asteroid_instance.name = "Asteroid_" + str(_spawn_count)
	
	# Position it
	asteroid_instance.global_position = spawn_position
	
	# Random size based on density zone
	var size = get_size_for_position(spawn_position)
	asteroid_instance.scale = Vector3(size, size, size)
	
	# Add to tracking array
	_active_asteroids.append(asteroid_instance)
	
	# Static asteroids - no movement needed
	
	# Add to minimap if available
	if _minimap and _minimap.has_method("add_asteroid"):
		_minimap.add_asteroid(asteroid_instance)
	
	# Add to scene tree using call_deferred to avoid timing issues
	call_deferred("_add_asteroid_to_scene", asteroid_instance)

# Get size based on density zones
func get_size_for_position(pos: Vector3) -> float:
	# Check if position is in a heavy zone
	for zone_pos in _heavy_zones:
		if (pos - zone_pos).length() < heavy_zone_radius:
			# In heavy zone - larger asteroids
			return _rng.randf_range(size_min * heavy_zone_density, size_max * heavy_zone_density)
	
	# In light zone - smaller asteroids
	return _rng.randf_range(size_min * light_zone_density, size_max)

# Get a random spawn position within the entire system
func _get_system_spawn_position() -> Vector3:
	var attempts = 0
	var max_attempts = 100  # Increased attempts for better spacing
	
	while attempts < max_attempts:
		# Generate random position within system radius with better distribution
		var angle = _rng.randf_range(0, 2.0 * PI)
		var distance = _rng.randf_range(safe_zone_radius + 200.0, system_radius * 0.85)  # Scaled for 4000x4000 system
		
		var spawn_pos = Vector3(
			cos(angle) * distance,
			0,  # Keep at Y=0 level
			sin(angle) * distance
		)
		
		# Check if position is valid (not too close to existing asteroids)
		if is_position_valid(spawn_pos):
			return spawn_pos
		
		attempts += 1
	
	# Fallback - return position even if not ideal, but still try to maintain some spacing
	var angle = _rng.randf_range(0, 2.0 * PI)
	var distance = _rng.randf_range(safe_zone_radius + 300.0, system_radius * 0.8)
	return Vector3(cos(angle) * distance, 0, sin(angle) * distance)

# Check if spawn position is valid (not too crowded)
func is_position_valid(pos: Vector3) -> bool:
	var min_distance = 120.0  # Scaled up minimum distance for 4000x4000 system
	
	for asteroid in _active_asteroids:
		if (asteroid.global_position - pos).length() < min_distance:
			return false
	
	return true

# Helper function to safely add asteroid to scene
func _add_asteroid_to_scene(asteroid_instance: Node3D):
	if not asteroid_instance or not is_inside_tree():
		return
		
	var parent = get_parent()
	if parent:
		parent.add_child(asteroid_instance)
	else:
		var main_scene = get_tree().current_scene
		if main_scene:
			main_scene.add_child(asteroid_instance)

# Show completion message when all asteroids are spawned
func show_completion_message():
	# Create completion message
	var message_label = Label.new()
	message_label.text = "🌌 ASTEROID FIELD GENERATED 🌌\n%d asteroids spawned" % total_asteroids
	message_label.add_theme_color_override("font_color", Color.CYAN)
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 150, 200)
	message_label.z_index = 1000
	
	# Add to the scene
	get_tree().current_scene.add_child(message_label)
	
	# Create a tween to fade out and remove the message
	var tween = create_tween()
	tween.tween_property(message_label, "modulate:a", 0.0, 3.0)
	tween.tween_callback(message_label.queue_free)

# Process frame - clean up destroyed asteroids
func _process(_delta):
	# Clean up destroyed asteroids from tracking array
	for i in range(_active_asteroids.size() - 1, -1, -1):
		if not is_instance_valid(_active_asteroids[i]):
			_active_asteroids.remove_at(i)

# Get current asteroid count
func get_asteroid_count() -> int:
	return _active_asteroids.size()

# Check if spawning is complete
func is_spawning_complete() -> bool:
	return _spawning_complete
