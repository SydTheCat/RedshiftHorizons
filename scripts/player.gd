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
@export var max_cargo_space: float = 100.0

# Ship systems
@export var max_hull_integrity: float = 100.0
var current_hull_integrity: float = 100.0
@export var max_fuel: float = 100.0
var current_fuel: float = 100.0
var game_over_active: bool = false

# System boundaries
@export var system_boundary: float = 4000.0


# Smooth input values
var smooth_thrust: float = 0.0
var smooth_turn: float = 0.0

# Audio state
var is_thrusting: bool = false
var is_firing_lasers: bool = false

func _ready() -> void:
	# Initialize ship systems
	current_hull_integrity = max_hull_integrity
	current_fuel = max_fuel
	
	# Declare UI layer variable once for reuse
	var ui_layer: Node
	
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
		ui_layer = get_tree().current_scene.get_node_or_null("UI")
		if ui_layer:
			ui_layer.add_child(scan_circle_instance)
		else:
			get_tree().current_scene.add_child(scan_circle_instance)
		
		scan_circle_instance.hide_scan_circle()
		print("Player: Scan circle loaded and initialized")
	else:
		push_warning("Player: Scan circle scene not found")
	
	# Create ship status UI
	var ship_status_ui_script = load("res://scripts/ship_status_ui.gd")
	var ship_status_ui_instance = Control.new()
	ship_status_ui_instance.set_script(ship_status_ui_script)
	
	# Add to UI layer
	ui_layer = get_tree().current_scene.get_node_or_null("UI")
	if ui_layer:
		ui_layer.add_child(ship_status_ui_instance)
	else:
		get_tree().current_scene.add_child(ship_status_ui_instance)
	
	print("Player: Ship status UI loaded and initialized")
	
	# Load asteroid info display scene
	if ResourceLoader.exists("res://scenes/asteroid_info_display.tscn"):
		asteroid_info_scene = load("res://scenes/asteroid_info_display.tscn")
		asteroid_info_instance = asteroid_info_scene.instantiate()
		
		# Add to UI layer
		ui_layer = get_tree().current_scene.get_node_or_null("UI")
		if ui_layer:
			ui_layer.add_child(asteroid_info_instance)
		else:
			get_tree().current_scene.add_child(asteroid_info_instance)
		
		print("Player: Asteroid info display loaded and initialized")
	else:
		push_warning("Player: Asteroid info display scene not found")

# Ship status methods for UI

func get_hull_integrity() -> float:
	return current_hull_integrity / max_hull_integrity

func get_fuel_level() -> float:
	return current_fuel / max_fuel

func take_hull_damage(damage: float):
	current_hull_integrity = max(0.0, current_hull_integrity - damage)
	if current_hull_integrity <= 0.0:
		ship_explode()

func consume_fuel(amount: float):
	current_fuel = max(0.0, current_fuel - amount)

func repair_hull(amount: float):
	current_hull_integrity = min(max_hull_integrity, current_hull_integrity + amount)

func refuel(amount: float):
	current_fuel = min(max_fuel, current_fuel + amount)

# Ship explosion and game over
func ship_explode():
	print("SHIP DESTROYED! GAME OVER")
	
	# Set game over state
	game_over_active = true
	
	# Disable player movement but keep input processing for restart
	set_physics_process(false)
	
	# Create explosion effect
	create_explosion_effect()
	
	# Show game over screen after delay
	await get_tree().create_timer(2.0).timeout
	show_game_over_screen()

func create_explosion_effect():
	# Create explosion particles if available
	var explosion_scene = load("res://scenes/asteroid_impact_particles.tscn")
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
		explosion.scale = Vector3(3.0, 3.0, 3.0)  # Make it bigger for ship explosion
		
		# Start particle emission
		if explosion.has_method("emitting"):
			explosion.emitting = true
	
	# Hide the ship model
	visible = false
	
	# Add screen shake for dramatic effect
	var camera_rig = get_node_or_null("../CameraRig")
	if camera_rig and camera_rig.has_method("add_trauma"):
		camera_rig.add_trauma(1.0)  # Maximum screen shake

func show_game_over_screen():
	# Create game over UI
	var game_over_ui = Control.new()
	game_over_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Semi-transparent background
	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0, 0, 0, 0.8)
	game_over_ui.add_child(background)
	
	# Game Over title
	var title_label = Label.new()
	title_label.text = "GAME OVER"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color.RED)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title_label.position.y -= 50
	game_over_ui.add_child(title_label)
	
	# Ship destroyed message
	var message_label = Label.new()
	message_label.text = "Your ship has been destroyed!"
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	game_over_ui.add_child(message_label)
	
	# Continue instruction
	var continue_label = Label.new()
	continue_label.text = "Press any button to continue"
	continue_label.add_theme_font_size_override("font_size", 16)
	continue_label.add_theme_color_override("font_color", Color.CYAN)
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	continue_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	continue_label.position.y += 50
	game_over_ui.add_child(continue_label)
	
	# Add to scene
	get_tree().current_scene.add_child(game_over_ui)

# Handle collision with asteroids - using physics process collision detection
func check_asteroid_collisions():
	# Get all bodies in the scene that might be asteroids
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Create a small sphere around the player to detect collisions
	var sphere = SphereShape3D.new()
	sphere.radius = 2.0  # Adjust based on ship size
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = 1  # Adjust based on asteroid collision layer
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result.collider
		if body != self and body.has_method("take_damage") and (body.is_in_group("asteroids") or "asteroid" in body.name.to_lower()):
			# Calculate collision damage based on velocity and asteroid size
			var collision_speed = velocity.length()
			var asteroid_scale = body.scale.length() / sqrt(3.0)  # Normalize scale vector
			
			# Damage to ship (speed * asteroid size factor) - reduced damage
			var ship_damage = max(collision_speed * asteroid_scale * 0.5, 2.0)  # Minimum 2 damage, reduced multiplier
			take_hull_damage(ship_damage)
			
			# Damage to asteroid (speed * ship mass factor) - reduced damage
			var asteroid_damage = collision_speed * 1.5  # Reduced from 5.0 to 1.5
			body.take_damage(asteroid_damage)
			
			print("Collision! Ship damage: %.1f, Asteroid damage: %.1f, Speed: %.1f" % [ship_damage, asteroid_damage, collision_speed])
			
			# Add collision feedback effects
			if collision_speed > 2.0:  # Lower threshold for feedback
				# Screen shake effect (if camera rig exists)
				var camera_rig = get_node_or_null("../CameraRig")
				if camera_rig and camera_rig.has_method("add_trauma"):
					camera_rig.add_trauma(min(collision_speed * 0.1, 1.0))
				
				# Push ship away from asteroid
				var collision_direction = (global_position - body.global_position).normalized()
				velocity += collision_direction * collision_speed * 0.3
			
			break  # Only handle one collision per frame

func _input(event):
	# Handle game over restart
	if game_over_active:
		if event is InputEventKey and event.pressed:
			print("Key pressed - restarting game")
			get_tree().reload_current_scene()
		elif event is InputEventMouseButton and event.pressed:
			print("Mouse clicked - restarting game")
			get_tree().reload_current_scene()
		return
	
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

func _physics_process(delta: float) -> void:
	var dt = delta
	
	# Consume fuel during movement
	if is_thrusting and current_fuel > 0.0:
		consume_fuel(2.5 * delta)  # Consume 2.5 fuel per second while thrusting (reduced by half again)
	
	check_system_boundary()
	update_asteroid_targeting()
	check_asteroid_collisions()  # Check for collisions every frame
	
	# Get raw input
	var turn_input: float = 0.0
	var thrust_input: float = Input.get_action_strength("ui_up") if current_fuel > 0.0 else 0.0  # W key for thrust (disabled when no fuel)
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
			print("Asteroid has mineral_data: ", "mineral_data" in target_asteroid)
			if "mineral_data" in target_asteroid:
				print("Mineral data value: ", target_asteroid.mineral_data)
			else:
				print("ERROR: No mineral_data property found on asteroid")
	
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
		print("Updating scan circle position for: ", current_target_asteroid.name, " at ", current_target_asteroid.global_position)
		scan_circle_instance.set_position_from_world(current_target_asteroid.global_position, camera)
	elif current_target_asteroid and not is_instance_valid(current_target_asteroid):
		# Clean up invalid reference
		current_target_asteroid = null
		scan_circle_instance.hide_scan_circle()
		stop_asteroid_scan()

# Handle asteroid destruction notification
func on_asteroid_destroyed(destroyed_asteroid: Node3D):
	print("Asteroid destroyed: ", destroyed_asteroid.name if destroyed_asteroid else "null")
	
	# If this was our current target, close the scan circle and stop scanning
	if current_target_asteroid == destroyed_asteroid:
		print("Current target asteroid destroyed - closing scan circle")
		current_target_asteroid = null
		
		if scan_circle_instance:
			scan_circle_instance.hide_scan_circle()
		
		if is_scanning_asteroid:
			stop_asteroid_scan()

# Get current cargo space used
func get_cargo_used() -> float:
	var total_used = 0.0
	for amount in inventory.values():
		total_used += amount
	return total_used

# Check if there's enough cargo space for additional minerals
func has_cargo_space(additional_amount: float) -> bool:
	return get_cargo_used() + additional_amount <= max_cargo_space

# Collect minerals from destroyed asteroids (legacy single mineral)
func collect_minerals(mineral: MineralData) -> void:
	if not mineral:
		return
	
	var mineral_name = mineral.display_name
	var amount = mineral.amount
	var credits_earned = int(amount * mineral.value_per_unit)
	
	# Check cargo space
	if not has_cargo_space(amount):
		var available_space = max_cargo_space - get_cargo_used()
		if available_space > 0:
			# Collect what we can
			amount = available_space
			credits_earned = int(amount * mineral.value_per_unit)
			print("Cargo space full! Only collected %.1f units of %s" % [amount, mineral_name])
			show_cargo_full_warning()
		else:
			print("Cargo space full! Cannot collect %s" % mineral_name)
			show_cargo_full_warning()
			return
	
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

# Collect multiple minerals from multi-ore asteroids
func collect_multi_minerals(multi_mineral: MultiMineralData) -> void:
	if not multi_mineral:
		return
	
	var total_credits_earned = 0
	var total_amount_to_collect = multi_mineral.get_total_amount()
	
	# Check if we have space for all minerals
	if not has_cargo_space(total_amount_to_collect):
		var available_space = max_cargo_space - get_cargo_used()
		if available_space <= 0:
			print("Cargo space full! Cannot collect multi-ore asteroid")
			show_cargo_full_warning()
			return
		
		print("Cargo space limited! Collecting %.1f/%.1f units from multi-ore asteroid" % [available_space, total_amount_to_collect])
		show_cargo_full_warning()
		
		# Scale down all minerals proportionally to fit available space
		var scale_factor = available_space / total_amount_to_collect
		for mineral in multi_mineral.minerals:
			mineral.amount *= scale_factor
	
	# Process each mineral in the asteroid
	for mineral in multi_mineral.minerals:
		var mineral_name = mineral.display_name
		var amount = mineral.amount
		var credits_earned = int(amount * mineral.value_per_unit)
		
		# Add to inventory
		if inventory.has(mineral_name):
			inventory[mineral_name] += amount
		else:
			inventory[mineral_name] = amount
		
		total_credits_earned += credits_earned
	
	# Add total credits
	total_credits += total_credits_earned
	
	# Update UI if available
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("update_inventory_display"):
		ui_manager.update_inventory_display()

# Start scanning an asteroid
func start_asteroid_scan():
	print("=== PLAYER START_ASTEROID_SCAN ===")
	print("current_target_asteroid: ", current_target_asteroid)
	print("asteroid_info_instance: ", asteroid_info_instance)
	print("is_scanning_asteroid: ", is_scanning_asteroid)
	
	if not current_target_asteroid:
		print("ERROR: No current_target_asteroid")
		return
		
	if not asteroid_info_instance:
		print("ERROR: No asteroid_info_instance")
		return
	
	if not is_instance_valid(current_target_asteroid):
		print("ERROR: current_target_asteroid is not valid")
		return
		
	is_scanning_asteroid = true
	scan_start_time = Time.get_time_dict_from_system()["second"]
	
	# Lock the scan circle at its current position
	if scan_circle_instance and scan_circle_instance.has_method("lock_scan_circle"):
		scan_circle_instance.lock_scan_circle()
		print("Scan circle locked")
	
	# Position info display at a fixed screen location (top-right corner)
	var viewport_size = get_viewport().get_visible_rect().size
	var fixed_pos = Vector2(viewport_size.x - 320, 50)  # Fixed position in top-right
	asteroid_info_instance.position = fixed_pos
	print("Info display positioned at: ", fixed_pos)
	print("Info display size: ", asteroid_info_instance.size)
	print("Info display parent: ", asteroid_info_instance.get_parent())
	print("Info display z_index: ", asteroid_info_instance.z_index)
	
	# Ensure it's on top
	asteroid_info_instance.z_index = 100
	asteroid_info_instance.move_to_front()
	
	# Start the scanning animation
	print("Starting scan animation...")
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
	summary += "Cargo Space: %.1f/%.1f units\n" % [get_cargo_used(), max_cargo_space]
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

# Show visual warning when cargo is full
func show_cargo_full_warning():
	# Create a temporary warning label
	var warning_label = Label.new()
	warning_label.text = "⚠️ CARGO FULL ⚠️"
	warning_label.add_theme_color_override("font_color", Color.RED)
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 100, 100)
	warning_label.z_index = 1000
	
	# Add to the scene
	get_tree().current_scene.add_child(warning_label)
	
	# Create a tween to fade out and remove the warning
	var tween = create_tween()
	tween.tween_property(warning_label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(warning_label.queue_free)

# Check if player is within system boundaries
func check_system_boundary():
	var distance_from_center = global_position.length()
	
	if distance_from_center > system_boundary:
		# Push player back towards center
		var direction_to_center = -global_position.normalized()
		var push_force = (distance_from_center - system_boundary) * 0.1
		global_position += direction_to_center * push_force
		
		# Show boundary warning
		show_boundary_warning()

# Show visual warning when approaching system boundary
func show_boundary_warning():
	# Create a temporary warning label
	var warning_label = Label.new()
	warning_label.text = "⚠️ SYSTEM BOUNDARY ⚠️"
	warning_label.add_theme_color_override("font_color", Color.YELLOW)
	warning_label.add_theme_font_size_override("font_size", 20)
	warning_label.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 120, 150)
	warning_label.z_index = 1000
	
	# Add to the scene
	get_tree().current_scene.add_child(warning_label)
	
	# Create a tween to fade out and remove the warning
	var tween = create_tween()
	tween.tween_property(warning_label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(warning_label.queue_free)
