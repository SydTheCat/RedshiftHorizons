extends Node3D

# Configuration parameters - Much lower defaults to prevent freezing
@export var star_density: float = 0.00005  # Reduced by 10x
@export var view_distance: float = 100.0  # Reduced view distance
@export var sector_size: float = 800.0  # Smaller sectors for more granular loading
@export var spawn_interval: float = 0.5  # Less frequent updates
@export var max_sectors_per_frame: int = 1  # Only create 1 sector per frame
@export var max_stars_per_sector: int = 50  # Safety limit
@export var off_screen_spawn: bool = true  # Only spawn stars outside view frustum

# System parameters
var camera: Camera3D = null
var player: Node3D = null
var active_sectors = {}  # Dictionary of active star sectors
var spawn_timer: float = 0.0
var initialized: bool = false
var pending_sectors = []  # Queue of sectors to be spawned

# Simple star properties
var star_material = null
var star_mesh = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# Create shared resources for stars
	create_shared_resources()
	
	# Wait a few frames before starting to find nodes and spawn stars
	# This prevents freezing during startup
	var startup_timer = get_tree().create_timer(1.0)
	await startup_timer.timeout
	
	# Try to find required nodes
	find_required_nodes()
	
	# Create initial stars around the player
	initialize_first_sector()
	
	# Flag as initialized
	initialized = true

# Create shared resources used by all stars
func create_shared_resources() -> void:
	# Create shared material
	star_material = StandardMaterial3D.new()
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.albedo_color = Color(1, 1, 1)  # White
	star_material.emission_enabled = true
	star_material.emission = Color(1, 1, 1)  # White emission
	star_material.emission_energy_multiplier = 2.0
	
	# Create shared mesh
	star_mesh = SphereMesh.new()
	star_mesh.radius = 0.5
	star_mesh.height = 1.0
	star_mesh.material = star_material

# Find the player and camera
func find_required_nodes() -> void:
	# Find the player
	player = get_tree().get_first_node_in_group("player")
		
	# Try to get camera from viewport first
	camera = get_viewport().get_camera_3d()
	if camera:
		return
		
	# Look for camera in player's children
	if player:
		var player_cam = find_camera_in_node(player)
		if player_cam:
			camera = player_cam
			return
	
	# Look for any camera in the first few levels of the scene tree
	# Limiting depth to avoid freezes
	var cam = find_camera_limited_depth(get_tree().root, 3)
	if cam:
		camera = cam

# Find a camera node in the given parent with limited depth
func find_camera_limited_depth(node: Node, max_depth: int) -> Camera3D:
	if max_depth <= 0:
		return null
		
	if node is Camera3D:
		return node
		
	for child in node.get_children():
		var cam = find_camera_limited_depth(child, max_depth - 1)
		if cam != null:
			return cam
			
	return null

# Find a camera in the given node
func find_camera_in_node(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
		
	for child in node.get_children():
		if child is Camera3D:
			return child
			
	return null

# Create just the player's sector to start
func initialize_first_sector() -> void:
	if player:
		var player_sector = pos_to_sector_key(player.global_position)
		var sector = spawn_sector_offscreen(sector_key_to_pos(player_sector))
		active_sectors[player_sector] = sector

# Process function to handle star spawning/despawning
func _process(delta):
	# Skip if not initialized or missing player
	if not initialized or not player or not is_instance_valid(player):
		return
	
	# Process the queue of pending sectors (one per frame to prevent freezes)
	if pending_sectors.size() > 0:
		var sector_info = pending_sectors.pop_front()
		# Only spawn if this sector is still needed
		if is_sector_still_needed(sector_info.key):
			var new_sector = spawn_sector_offscreen(sector_info.pos)
			active_sectors[sector_info.key] = new_sector
		return  # Only do one sector operation per frame
	
	# Update spawn timer
	spawn_timer += delta
	if spawn_timer < spawn_interval:
		return
	
	spawn_timer = 0.0
	
	# Get player position and viewing direction
	var player_pos = player.global_position
	var view_dir = Vector3.FORWARD
	
	# If we have a camera, use its direction
	if camera and is_instance_valid(camera):
		view_dir = -camera.global_transform.basis.z.normalized()
		
	# Get sectors that should be active - including outside visible range
	var sectors_to_activate = get_offscreen_sectors(player_pos, view_dir)
	
	# Queue new sectors for creation (will be processed one per frame)
	for sector_key in sectors_to_activate:
		if not active_sectors.has(sector_key) and not is_sector_pending(sector_key):
			var sector_pos = sector_key_to_pos(sector_key)
			pending_sectors.append({"key": sector_key, "pos": sector_pos})
			if pending_sectors.size() >= max_sectors_per_frame * 5:  # Limit queue size
				break
	
	# Despawn stars in sectors that are no longer needed
	var sectors_to_remove = []
	for sector_key in active_sectors:
		if not sector_key in sectors_to_activate:
			despawn_sector(active_sectors[sector_key])
			sectors_to_remove.append(sector_key)
	
	for sector_key in sectors_to_remove:
		active_sectors.erase(sector_key)
		
# Check if a sector is still needed based on current player position
func is_sector_still_needed(sector_key: String) -> bool:
	if not player or not is_instance_valid(player):
		return false
		
	var player_pos = player.global_position
	var view_dir = Vector3.FORWARD
	if camera and is_instance_valid(camera):
		view_dir = -camera.global_transform.basis.z.normalized()
		
	var current_sectors = get_offscreen_sectors(player_pos, view_dir)
	return sector_key in current_sectors

# Check if a sector is already in the pending queue
func is_sector_pending(key: String) -> bool:
	for item in pending_sectors:
		if item.key == key:
			return true
	return false

# Convert a position to a sector key
func pos_to_sector_key(pos: Vector3) -> String:
	var sector_x = floor(pos.x / sector_size)
	var sector_y = floor(pos.y / sector_size)
	var sector_z = floor(pos.z / sector_size)
	return "%d,%d,%d" % [sector_x, sector_y, sector_z]

# Convert a sector key back to a position (center of sector)
func sector_key_to_pos(key: String) -> Vector3:
	var parts = key.split(",")
	if parts.size() < 3:  # Safety check
		return Vector3.ZERO
		
	var x = float(parts[0]) * sector_size + sector_size/2
	var y = float(parts[1]) * sector_size + sector_size/2
	var z = float(parts[2]) * sector_size + sector_size/2
	return Vector3(x, y, z)

# Get sectors outside the camera's view frustum
func get_offscreen_sectors(pos: Vector3, view_dir: Vector3) -> Array:
	var active_keys = []
	
	# Always include player's sector for stars behind the camera
	var player_sector = pos_to_sector_key(pos)
	active_keys.append(player_sector)
	
	# Get the main viewing direction for far sectors (beyond view distance)
	var far_distance = view_distance * 1.5
	var far_pos = pos + view_dir * far_distance
	var far_sector = pos_to_sector_key(far_pos)
	if far_sector != player_sector:
		active_keys.append(far_sector)
		
	# Add sectors to the sides but outside camera frustum
	var right_dir = view_dir.cross(Vector3.UP).normalized()
	
	# Far right (outside view)
	var far_right_pos = pos + right_dir * view_distance * 1.2 + view_dir * view_distance * 0.5
	var far_right_sector = pos_to_sector_key(far_right_pos)
	if not far_right_sector in active_keys:
		active_keys.append(far_right_sector)
		
	# Far left (outside view)
	var far_left_pos = pos - right_dir * view_distance * 1.2 + view_dir * view_distance * 0.5
	var far_left_sector = pos_to_sector_key(far_left_pos)
	if not far_left_sector in active_keys:
		active_keys.append(far_left_sector)
		
	# Above and below (outside normal view)
	var up_dir = right_dir.cross(view_dir).normalized()
	
	# Far above (outside view)
	var far_up_pos = pos + up_dir * view_distance * 1.2 + view_dir * view_distance * 0.5
	var far_up_sector = pos_to_sector_key(far_up_pos)
	if not far_up_sector in active_keys:
		active_keys.append(far_up_sector)
		
	# Far below (outside view)
	var far_down_pos = pos - up_dir * view_distance * 1.2 + view_dir * view_distance * 0.5
	var far_down_sector = pos_to_sector_key(far_down_pos)
	if not far_down_sector in active_keys:
		active_keys.append(far_down_sector)
	
	return active_keys

# Spawn stars in a sector but outside of player's current view
func spawn_sector_offscreen(sector_pos: Vector3) -> Node3D:
	var sector = Node3D.new()
	sector.name = "StarSector_%s" % pos_to_sector_key(sector_pos)
	add_child(sector)
	
	# Calculate how many stars to spawn based on volume and density
	var stars_to_spawn = int(sector_size * sector_size * sector_size * star_density)
	stars_to_spawn = min(stars_to_spawn, max_stars_per_sector) # Safety limit
	
	# Background Y offset to position stars lower (behind planets)
	var background_y_offset = -800.0 # Position stars far below the planets to ensure they're behind
	
	# Create stars with random positions within the sector
	for i in range(stars_to_spawn):
		var pos = Vector3(
			sector_pos.x - sector_size/2 + randf() * sector_size,
			# Position stars much lower on the Y axis with minimal variation
			background_y_offset + (randf() * 50.0), # Limited Y variation to ensure stars stay behind planets
			sector_pos.z - sector_size/2 + randf() * sector_size
		)
		
		# Create the star at this position
		create_star(pos, sector)
	
	return sector

# Create a single star at the given position
func create_star(pos: Vector3, parent: Node3D) -> void:
	# Create a mesh instance for the star using shared resources
	var star = MeshInstance3D.new()
	star.mesh = star_mesh
	star.position = pos
	
	# Simple scale variation
	var scale_factor = 0.8 + randf() * 0.7
	star.scale = Vector3(scale_factor, scale_factor, scale_factor)
	
	# Add to parent
	parent.add_child(star)

# Despawn a sector of stars
func despawn_sector(sector: Node3D) -> void:
	if is_instance_valid(sector):
		sector.queue_free()
