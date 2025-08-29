extends CharacterBody3D

@export var thrust_force: float = 80.0      # Force applied when thrusting
@export var turn_speed_deg: float = 120.0   # Rotation speed (independent of movement)
@export var max_speed: float = 150.0        # Maximum velocity cap
@export var space_drag: float = 0.98        # Very minimal drag (space has no friction)
@export var thrust_smoothing: float = 6.0   # How smoothly thrust builds up
@export var turn_smoothing: float = 8.0     # How smoothly turning responds



# Smooth input values
var smooth_thrust: float = 0.0
var smooth_turn: float = 0.0

func _physics_process(dt: float) -> void:
	# Get raw input
	var turn_input: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	var thrust_input: float = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	
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
