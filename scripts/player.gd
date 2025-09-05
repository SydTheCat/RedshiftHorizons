extends CharacterBody3D

@export var thrust_force: float = 80.0      # Force applied when thrusting
@export var turn_speed_deg: float = 30.0    # Rotation speed (independent of movement)
@export var max_speed: float = 150.0        # Maximum velocity cap
@export var space_drag: float = 0.98        # Very minimal drag (space has no friction)
@export var thrust_smoothing: float = 6.0   # How smoothly thrust builds up
@export var turn_smoothing: float = 8.0     # How smoothly turning responds

# Weapon properties
@export var laser_color: Color = Color(1.0, 0.3, 0.1, 0.8)  # Orange-red laser
@export var laser_range: float = 200.0  # Maximum laser range
@export var laser_energy: float = 3.0   # Laser brightness

# Laser beam references
var left_laser: Node3D
var right_laser: Node3D
var weapon_mounts: Array = []

# Audio references
var thrust_audio: AudioStreamPlayer3D
var laser_audio: AudioStreamPlayer3D

# Cursor management
var target_cursor_texture: Texture2D
var is_mouse_steering: bool = false
var scan_circle_scene: PackedScene
var scan_circle_instance: Control
var current_target_asteroid: Node3D = null

# Asteroid info display
var asteroid_info_scene: PackedScene
var asteroid_info_instance: Control
var scan_start_time: float = 0.0
var is_scanning_asteroid: bool = false
var is_scan_locked: bool = false
var locked_cursor_position: Vector2

# Mining and inventory
var inventory: Dictionary = {}
var total_credits: int = 0


# Smooth input values
var smooth_thrust: float = 0.0
var smooth_turn: float = 0.0

# Audio state
var is_thrusting: bool = false
var is_firing_lasers: bool = false

func _ready() -> void:
	# Get references to the weapon mounts and lasers from the scene
	initialize_weapon_systems()
	
	# Get reference to thrust audio
	thrust_audio = get_node_or_null("ThrustAudio")
	if not thrust_audio:
		push_warning("Player: ThrustAudio node not found - thrust sound will be disabled")
	
	# Get reference to laser audio
	laser_audio = get_node_or_null("LaserAudio")
	if not laser_audio:
		push_warning("Player: LaserAudio node not found - laser sound will be disabled")
	
	# Load the target cursor texture safely
	if ResourceLoader.exists("res://assets/target_cursor.svg"):
		target_cursor_texture = load("res://assets/target_cursor.svg")
	else:
		push_warning("Player: Target cursor texture not found - using default cursor")
	
	# Load scan circle scene
	if ResourceLoader.exists("res://scenes/scan_circle.tscn"):
		scan_circle_scene = load("res://scenes/scan_circle.tscn")
		# Create scan circle instance and add to UI
		scan_circle_instance = scan_circle_scene.instantiate()
		
		# Add to a UI layer that's always on top
		var ui_layer = get_tree().current_scene.get_node_or_null("UI")
		if ui_layer:
			ui_layer.add_child(scan_circle_instance)
		else:
			get_tree().current_scene.add_child(scan_circle_instance)
		
		scan_circle_instance.hide_scan_circle()
		print("Player: Scan circle loaded and initialized")
	else:
		push_warning("Player: Scan circle scene not found - using default cursor")
	
	# Load asteroid info display scene
	if ResourceLoader.exists("res://scenes/asteroid_info_display.tscn"):
		asteroid_info_scene = load("res://scenes/asteroid_info_display.tscn")
		asteroid_info_instance = asteroid_info_scene.instantiate()
		
		# Add to UI layer
		var ui_layer = get_tree().current_scene.get_node_or_null("UI")
		if ui_layer:
			ui_layer.add_child(asteroid_info_instance)
		else:
			get_tree().current_scene.add_child(asteroid_info_instance)
		
		print("Player: Asteroid info display loaded and initialized")
	else:
		push_warning("Player: Asteroid info display scene not found")

func _input(event):
	# Handle right mouse button release to unlock reticle
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			# Right mouse button released - unlock reticle
			if is_scan_locked:
				is_scan_locked = false
				stop_asteroid_scan()

# Initialize weapon systems by getting references to the scene nodes
func initialize_weapon_systems() -> void:
	# Get references to the weapon mounts
	var left_mount = get_node_or_null("LeftWeaponMount")
	var right_mount = get_node_or_null("RightWeaponMount")
	
	if left_mount and right_mount:
		weapon_mounts = [left_mount, right_mount]
		
		# Get references to the laser beams
		left_laser = get_node_or_null("LeftWeaponMount/LeftLaser")
		right_laser = get_node_or_null("RightWeaponMount/RightLaser")
		
		# Configure the lasers with player settings
		if left_laser and right_laser:
			# Make sure laser beams are initially off
			if left_laser.has_method("stop"):
				left_laser.stop()
			if right_laser.has_method("stop"):
				right_laser.stop()
			
			# Configure left laser
			left_laser.laser_color = laser_color
			left_laser.max_length = laser_range
			left_laser.energy = laser_energy
			left_laser.core_width = 0.1
			left_laser.particle_width = 0.3
			
			# Configure right laser
			right_laser.laser_color = laser_color
			right_laser.max_length = laser_range
			right_laser.energy = laser_energy
			right_laser.core_width = 0.1
			right_laser.particle_width = 0.3
			
		else:
			push_warning("Player: Laser beam nodes not found - weapons will be disabled")
	else:
		push_warning("Player: Weapon mount nodes not found - weapons will be disabled")

# Calculate mouse steering input based on cursor position
func get_mouse_turn_input() -> float:
	# Get the camera from the scene
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return 0.0
	
	# Get mouse position in screen coordinates
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Project mouse position to the world plane at the player's Y level
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	# Find intersection with the XZ plane at player's Y position
	var player_y = global_position.y
	var ray_dir = (to - from).normalized()
	
	# Calculate intersection with XZ plane
	var t = (player_y - from.y) / ray_dir.y
	var world_mouse_pos = from + ray_dir * t
	
	# Calculate direction from player to mouse cursor
	var direction_to_mouse = world_mouse_pos - global_position
	direction_to_mouse.y = 0.0  # Keep on XZ plane
	direction_to_mouse = direction_to_mouse.normalized()
	
	# Get player's current forward direction
	var player_forward = -transform.basis.y  # Ship's forward direction
	player_forward.y = 0.0
	player_forward = player_forward.normalized()
	
	# Calculate the cross product to determine turn direction
	var cross = player_forward.cross(direction_to_mouse)
	
	# Calculate the angle between current direction and target direction
	var dot = player_forward.dot(direction_to_mouse)
	var angle = acos(clamp(dot, -1.0, 1.0))
	
	# Normalize the turn input based on angle (stronger turn for larger angles)
	var turn_strength = clamp(angle / PI, 0.0, 1.0)
	
	# Return turn direction (-1 for left, 1 for right) with strength
	if cross.y > 0:
		return turn_strength  # Turn right
	else:
		return -turn_strength  # Turn left

# Handle laser audio based on firing state
func handle_laser_audio(is_firing: bool) -> void:
	if is_firing and not is_firing_lasers:
		# Start firing - play laser audio
		if laser_audio and not laser_audio.playing:
			laser_audio.play()
		is_firing_lasers = true
	elif not is_firing and is_firing_lasers:
		# Stop firing - stop laser audio
		if laser_audio and laser_audio.playing:
			laser_audio.stop()
		is_firing_lasers = false

# Handle firing the lasers
func fire_lasers(is_firing: bool) -> void:
	if is_firing:
		# Check if laser references exist and have required methods
		if left_laser and right_laser and left_laser.has_method("fire") and right_laser.has_method("fire"):
			# Fire lasers
			left_laser.fire()
			right_laser.fire()
		elif left_laser == null or right_laser == null:
			# Try to get the nodes again in case they were added dynamically
			left_laser = get_node_or_null("LeftWeaponMount/LeftLaser")
			right_laser = get_node_or_null("RightWeaponMount/RightLaser")
	else:
		# Stop firing
		if left_laser != null and left_laser.has_method("stop"):
			left_laser.stop()
		if right_laser != null and right_laser.has_method("stop"):
			right_laser.stop()

# Handle thrust audio based on thrust input
func handle_thrust_audio(thrust_input: float) -> void:
	var should_thrust = abs(thrust_input) > 0.01
	
	if should_thrust and not is_thrusting:
		# Start thrusting - play audio
		if thrust_audio and not thrust_audio.playing:
			thrust_audio.play()
		is_thrusting = true
	elif not should_thrust and is_thrusting:
		# Stop thrusting - stop audio
		if thrust_audio and thrust_audio.playing:
			thrust_audio.stop()
		is_thrusting = false

func _physics_process(dt: float) -> void:
	# Update asteroid detection and scan circle
	update_asteroid_targeting()
	
	# Get raw input
	var turn_input: float = 0.0
	var thrust_input: float = Input.get_action_strength("ui_up")  # W key for thrust
	var fire_input: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)  # Left mouse button for firing
	var mouse_steer_input: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)  # Right mouse button for steering
	
	# Handle mouse steering when right mouse button is pressed
	if mouse_steer_input:
		turn_input = get_mouse_turn_input()
		# Switch to target cursor if not already active
		if not is_mouse_steering:
			is_mouse_steering = true
			if target_cursor_texture:
				Input.set_custom_mouse_cursor(target_cursor_texture, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		# Fallback to keyboard controls
		turn_input = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
		# Switch back to default cursor if mouse steering was active
		if is_mouse_steering:
			is_mouse_steering = false
			Input.set_custom_mouse_cursor(null)
	
	# Fire lasers based on input
	fire_lasers(fire_input)
	
	# Handle audio effects
	handle_laser_audio(fire_input)
	handle_thrust_audio(thrust_input)
	
	# Smooth the inputs for realistic control feel
	smooth_turn = lerp(smooth_turn, turn_input, 1.0 - exp(-turn_smoothing * dt))
	smooth_thrust = lerp(smooth_thrust, thrust_input, 1.0 - exp(-thrust_smoothing * dt))
	
	# SPACE PHYSICS: Turning is completely independent of movement direction
	# Ship can rotate while maintaining its current velocity vector
	rotation_degrees.y += smooth_turn * turn_speed_deg * dt

	# SPACE PHYSICS: Thrust adds force in the direction the ship is facing
	# This creates realistic space movement where you can thrust in any direction
	if abs(smooth_thrust) > 0.01:
		var thrust_direction: Vector3 = -transform.basis.y  # Ship's forward direction
		var thrust_vector: Vector3 = thrust_direction * smooth_thrust * thrust_force * dt
		velocity += thrust_vector  # Add thrust force to current velocity (Newton's laws)

	# SPACE PHYSICS: Very minimal drag (space has almost no friction)
	# Ship maintains momentum and doesn't slow down easily
	velocity *= space_drag  # 0.98 means very slow deceleration
	
	# Cap maximum speed to prevent infinite acceleration
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	# Move the player using the calculated velocity
	move_and_slide()

# Update asteroid targeting and scan circle display
func update_asteroid_targeting():
	if not scan_circle_instance:
		print("No scan circle instance")
		return
		
	var camera = get_viewport().get_camera_3d()
	if not camera:
		print("No camera found")
		return
	
	# If reticle is locked to an asteroid, keep it there and lock cursor to asteroid center
	if is_scan_locked and current_target_asteroid and is_instance_valid(current_target_asteroid):
		scan_circle_instance.set_position_from_world(current_target_asteroid.global_position, camera)
		# Lock mouse cursor to the center of the asteroid
		var asteroid_screen_pos = camera.unproject_position(current_target_asteroid.global_position)
		Input.warp_mouse(asteroid_screen_pos)
		return
	
	# Cast ray from camera through mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	# Create raycast query
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF  # Check all collision layers
	
	var result = space_state.intersect_ray(query)
	
	var target_asteroid = null
	if result:
		var collider = result.get("collider")
		print("Raycast hit: ", collider.name if collider else "null", " Groups: ", collider.get_groups() if collider else "none")
		if collider and (collider.is_in_group("asteroids") or collider.name.to_lower().contains("asteroid")):
			target_asteroid = collider
			print("Found asteroid target: ", target_asteroid.name)
			print("Asteroid mineral_data: ", target_asteroid.mineral_data if target_asteroid.has_method("get") or "mineral_data" in target_asteroid else "no mineral_data property")
	
	# Update scan circle based on target
	if target_asteroid != current_target_asteroid:
		current_target_asteroid = target_asteroid
		
		if current_target_asteroid and is_instance_valid(current_target_asteroid):
			print("Showing scan circle for: ", current_target_asteroid.name)
			# Show scan circle at asteroid position
			scan_circle_instance.show_scan_circle()
			scan_circle_instance.set_position_from_world(current_target_asteroid.global_position, camera)
			
			# Start asteroid info scanning and lock reticle on right-click
			if asteroid_info_instance and not is_scanning_asteroid:
				if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
					is_scan_locked = true
				start_asteroid_scan()
		else:
			# Hide scan circle and stop scanning
			scan_circle_instance.hide_scan_circle()
			stop_asteroid_scan()
			current_target_asteroid = null
	
	# Update scan circle position if we have a target
	if current_target_asteroid and is_instance_valid(current_target_asteroid) and scan_circle_instance.is_active:
		scan_circle_instance.set_position_from_world(current_target_asteroid.global_position, camera)
	elif current_target_asteroid and not is_instance_valid(current_target_asteroid):
		# Clean up invalid reference
		current_target_asteroid = null
		scan_circle_instance.hide_scan_circle()
		stop_asteroid_scan()

# Collect minerals from destroyed asteroids
func collect_minerals(mineral: MineralData) -> void:
	if not mineral:
		return
	
	var mineral_name = mineral.display_name
	var amount = mineral.amount
	var credits_earned = int(amount * mineral.value_per_unit)
	
	# Add to inventory
	if inventory.has(mineral_name):
		inventory[mineral_name] += amount
	else:
		inventory[mineral_name] = amount
	
	# Add credits
	total_credits += credits_earned
	
	# Update UI if available
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("update_inventory_display"):
		ui_manager.update_inventory_display()

# Start scanning an asteroid
func start_asteroid_scan():
	if not current_target_asteroid or not asteroid_info_instance:
		return
		
	is_scanning_asteroid = true
	scan_start_time = Time.get_time_dict_from_system()["second"]
	
	# Position info display near cursor
	var mouse_pos = get_viewport().get_mouse_position()
	asteroid_info_instance.set_position_near_cursor(mouse_pos)
	
	# Start the scanning animation
	asteroid_info_instance.start_scan(current_target_asteroid)

# Stop scanning an asteroid
func stop_asteroid_scan():
	if not asteroid_info_instance:
		return
		
	is_scanning_asteroid = false
	asteroid_info_instance.stop_scan()

# Get inventory summary
func get_inventory_summary() -> String:
	var summary = "=== SPACE MINER INVENTORY ===\n"
	summary += "Total Credits: %d\n" % total_credits
	summary += "─────────────────────────────\n"
	
	if inventory.is_empty():
		summary += "No minerals collected yet.\n\n"
		summary += "Instructions:\n"
		summary += "• Hover over asteroids to see minerals\n"
		summary += "• Left click to fire lasers and mine\n"
		summary += "• Right click + mouse to steer\n"
		summary += "• W key for thrust\n"
		summary += "• Tab to toggle this inventory"
	else:
		summary += "Collected Minerals:\n"
		for mineral_name in inventory.keys():
			summary += "• %s: %.1f units\n" % [mineral_name, inventory[mineral_name]]
	
	return summary
