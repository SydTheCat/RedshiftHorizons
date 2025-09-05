extends Node3D

@export var height := 20.0  # Camera height above scene
@export var follow_smooth := 20.0
@export var zoom_speed := 5.0  # Increased for better ortho zooming
@export var min_height := 3.0
@export var max_height := 50.0

# Orthographic camera settings
@export var ortho_size := 100.0  # Initial size, same as in scene file
@export var min_ortho_size := 20.0  # Minimum zoom (close)
@export var max_ortho_size := 200.0  # Maximum zoom (far)

var player: Node3D

func _ready():
	# Wait a frame to ensure all nodes are initialized
	await get_tree().process_frame
	
	# Force the camera to be current
	$Camera3D.current = true
	
	# Set initial orthographic size
	$Camera3D.size = ortho_size
	
	# Find the player
	player = get_tree().get_first_node_in_group("player")
	
	# Position the camera directly above the player
	if player:
		global_position = Vector3(player.global_position.x, height, player.global_position.z)
	
	# Don't modify camera rotation here - use the transform in the scene file

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in (decrease orthographic size)
			ortho_size = clamp(ortho_size - zoom_speed * 5, min_ortho_size, max_ortho_size)
			$Camera3D.size = ortho_size
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out (increase orthographic size)
			ortho_size = clamp(ortho_size + zoom_speed * 5, min_ortho_size, max_ortho_size)
			$Camera3D.size = ortho_size
			get_viewport().set_input_as_handled()

func _physics_process(delta):
	# First, check if camera exists
	var camera = get_node_or_null("Camera3D")
	if not camera:
		return
		
	# Always make sure the camera is current
	if not camera.current:
		camera.current = true
		
	if not player or not is_instance_valid(player): 
		# Try to find player again if not found initially
		player = get_tree().get_first_node_in_group("player")
		if player:
			global_position = Vector3(player.global_position.x, height, player.global_position.z)
		return
	
	# GDScript doesn't support try/except - use if checks instead
	if player and is_instance_valid(player):
		# Follow above player at constant height
		var target := Vector3(player.global_position.x, height, player.global_position.z)
		# Only lerp the X and Z position, keep Y (height) immediate for zoom responsiveness
		global_position.x = lerp(global_position.x, target.x, 1.0 - exp(-follow_smooth * delta))
		global_position.z = lerp(global_position.z, target.z, 1.0 - exp(-follow_smooth * delta))
		global_position.y = height  # Always use exact height for immediate zoom response
	else:
		# If any error occurs, keep the camera stable
		pass
	
	# Camera position and rotation updated
