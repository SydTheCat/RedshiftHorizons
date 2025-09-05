extends Node3D

# Asteroid spawning properties
@export var asteroid_scene: PackedScene
@export var spawn_interval_min: float = 2.0
@export var spawn_interval_max: float = 5.0
@export var safe_zone_radius: float = 25.0    # Minimum distance from player (safe zone)
@export var spawn_distance_min: float = 40.0  # Minimum spawn distance
@export var spawn_distance_max: float = 80.0  # Maximum spawn distance
@export var size_min: float = 0.5             # Minimum scale factor
@export var size_max: float = 2.5             # Maximum scale factor
@export var player_path: NodePath            # Path to player node for alignment
@export var enabled: bool = true              # Toggle spawning
@export var max_active_asteroids: int = 15    # Maximum number of active asteroids

# Movement properties for asteroids
@export var speed_min: float = 0.3
@export var speed_max: float = 1.2

# Advanced spawning options
@export var spawn_ahead_bias: float = 0.3     # Bias to spawn ahead of player movement
@export var cleanup_distance: float = 200.0   # Distance at which to remove asteroids

# Private variables
var _timer: Timer
var _player: Node3D
var _minimap: Control
var _rng = RandomNumberGenerator.new()
var _spawn_count: int = 0
var _active_asteroids: Array = []

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
	
	# Set up spawn timer
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.autostart = false
	_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_timer)
	
	# Start spawning if enabled
	if enabled:
		start_spawning()
		
	# Force immediate spawn for testing
	if asteroid_scene != null:
		spawn_asteroid()

# Start the asteroid spawning process
func start_spawning():
	enabled = true
	_set_next_spawn_time()
	_timer.start()

# Stop the asteroid spawning process
func stop_spawning():
	enabled = false
	_timer.stop()

# Set a random time for the next spawn
func _set_next_spawn_time():
	var next_time = _rng.randf_range(spawn_interval_min, spawn_interval_max)
	_timer.wait_time = next_time

# Called when the spawn timer times out
func _on_spawn_timer_timeout():
	if enabled and asteroid_scene != null and _active_asteroids.size() < max_active_asteroids:
		spawn_asteroid()
	
	# Set time for next spawn
	_set_next_spawn_time()

# Spawn a new asteroid
func spawn_asteroid():
	if asteroid_scene == null:
		push_error("AsteroidSpawner: No asteroid scene set!")
		return
	
	# Get player position for calculations
	var player_pos = Vector3.ZERO
	if _player != null:
		player_pos = _player.global_position
	
	# Calculate spawn position (at the same y level as player)
	var spawn_position = _get_spawn_position()
	
	# Instantiate the asteroid
	var asteroid_instance = asteroid_scene.instantiate()
	
	# Add to scene tree - add to parent (the main scene) instead of the spawner itself
	get_parent().add_child(asteroid_instance)
	
	# Name it uniquely
	_spawn_count += 1
	asteroid_instance.name = "Asteroid_" + str(_spawn_count)
	
	# Position it
	asteroid_instance.global_position = spawn_position
	
	# Random size
	var size = _rng.randf_range(size_min, size_max)
	asteroid_instance.scale = Vector3(size, size, size)
	
	# Set movement direction toward player position
	var direction_to_player = (player_pos - spawn_position).normalized()
	var speed = _rng.randf_range(speed_min, speed_max)
	
	# Add to active asteroids list
	_active_asteroids.append(asteroid_instance)
	
	# Add asteroid to minimap if available
	if _minimap and _minimap.has_method("add_asteroid"):
		_minimap.add_asteroid(asteroid_instance)
	
	# Set up movement if asteroid has appropriate script
	if asteroid_instance.has_method("set_movement"):
		asteroid_instance.set_movement(direction_to_player * speed)

# Get a random spawn position at player's level
func _get_spawn_position() -> Vector3:
	# Generate random angle around the circle
	var angle = _rng.randf_range(0, 2.0 * PI)
	
	# Generate random distance within range
	var distance = _rng.randf_range(spawn_distance_min, spawn_distance_max)
	
	# Calculate position on a circle around the player's position
	var player_pos = Vector3.ZERO
	if _player != null:
		player_pos = _player.global_position
	
	# Try spawning on XZ plane (Y is up/down in most 3D games)
	var spawn_pos = Vector3.ZERO
	
	# Method 1: XZ plane with Y as vertical (most common in 3D games)
	spawn_pos.x = player_pos.x + cos(angle) * distance
	spawn_pos.z = player_pos.z + sin(angle) * distance
	spawn_pos.y = player_pos.y
	
	# Apply spawn ahead bias
	if _player != null:
		spawn_pos += _player.global_transform.basis * Vector3(1, 0, 0) * spawn_ahead_bias * distance
	
	# Ensure spawn position is outside safe zone
	while (spawn_pos - player_pos).length() < safe_zone_radius:
		angle = _rng.randf_range(0, 2.0 * PI)
		distance = _rng.randf_range(spawn_distance_min, spawn_distance_max)
		spawn_pos.x = player_pos.x + cos(angle) * distance
		spawn_pos.z = player_pos.z + sin(angle) * distance
		spawn_pos.y = player_pos.y
	
	
	return spawn_pos

# Process frame - optional for additional logic
func _process(delta):
	# Clean up destroyed asteroids from tracking array
	for i in range(_active_asteroids.size() - 1, -1, -1):
		if not is_instance_valid(_active_asteroids[i]):
			_active_asteroids.remove_at(i)
	
	# Remove asteroids that are too far away
	for i in range(_active_asteroids.size() - 1, -1, -1):
		var asteroid = _active_asteroids[i]
		if (asteroid.global_position - _player.global_position).length() > cleanup_distance:
			# Remove from minimap before destroying
			if _minimap and _minimap.has_method("remove_asteroid"):
				_minimap.remove_asteroid(asteroid)
			
			asteroid.queue_free()
			_active_asteroids.remove_at(i)
