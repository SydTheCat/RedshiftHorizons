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

# Cursor management
var target_cursor_texture: Texture2D
var is_mouse_steering: bool = false

# Mining and inventory
var inventory: Dictionary = {}
var total_credits: int = 0


# Smooth input values
var smooth_thrust: float = 0.0
var smooth_turn: float = 0.0

func _ready() -> void:
	# Get references to the weapon mounts and lasers from the scene
	initialize_weapon_systems()
	
	# Load the target cursor texture
	target_cursor_texture = load("res://assets/target_cursor.svg")

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
			left_laser.stop()
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
			push_error("Player: Failed to get references to laser beams - check scene hierarchy and node names")
	else:
		push_error("Player: Failed to get references to weapon mounts - check scene hierarchy")

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

# Handle firing the lasers
func fire_lasers(is_firing: bool) -> void:
	if is_firing:
		# Check if laser references exist
		var left_valid = left_laser != null
		var right_valid = right_laser != null
		var both_valid = left_valid and right_valid
		
		if both_valid:
			# Check if lasers were already active
			var left_was_active = left_laser.is_active
			var right_was_active = right_laser.is_active
			
			# Fire lasers
			left_laser.fire()
			right_laser.fire()
		else:
			# Detailed error for missing laser references
			push_error("ERROR: Cannot fire lasers - references are null: left=" + str(left_valid) + ", right=" + str(right_valid))
			
			# Try to get the node again in case it was added dynamically
			if !left_valid:
				left_laser = get_node_or_null("LeftWeaponMount/LeftLaser")
			if !right_valid:
				right_laser = get_node_or_null("RightWeaponMount/RightLaser")
	else:
		# Stop firing
		if left_laser != null:
			left_laser.stop()
		if right_laser != null:
			right_laser.stop()

func _physics_process(dt: float) -> void:
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



	# Keep motion on XZ plane (2D space movement)
	velocity.y = 0.0
	move_and_slide()

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
