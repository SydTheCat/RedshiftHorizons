extends Node3D

@export var height := 20.0  # Reduced height to be closer to the scene
@export var follow_smooth := 8.0
@export var zoom_speed := 2.0
@export var min_height := 3.0
@export var max_height := 50.0

var player: Node3D

func _ready():
	# Wait a frame to ensure all nodes are initialized
	await get_tree().process_frame
	
	# Force the camera to be current
	$Camera3D.current = true
	print("Camera current status: ", $Camera3D.current)
	
	# Find the player
	player = get_tree().get_first_node_in_group("player")
	print("Camera _ready called, player found: ", player != null)
	
	# Position the camera directly above the player
	if player:
		global_position = Vector3(player.global_position.x, height, player.global_position.z)
		print("Camera positioned at: ", global_position)
	
	# Don't modify camera rotation here - use the transform in the scene file
	print("Camera rotation: ", $Camera3D.rotation_degrees)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in (reduce height)
			height = clamp(height - zoom_speed, min_height, max_height)
			print("Zooming in - new height: ", height)
			# Immediately update camera position
			if player:
				global_position.y = height
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out (increase height)
			height = clamp(height + zoom_speed, min_height, max_height)
			print("Zooming out - new height: ", height)
			# Immediately update camera position
			if player:
				global_position.y = height
			get_viewport().set_input_as_handled()

func _physics_process(delta):
	if not player: 
		# Try to find player again if not found initially
		player = get_tree().get_first_node_in_group("player")
		if player:
			print("Player found in _physics_process")
			global_position = Vector3(player.global_position.x, height, player.global_position.z)
		return
		
	# Follow above player at constant height
	var target := Vector3(player.global_position.x, height, player.global_position.z)
	# Only lerp the X and Z position, keep Y (height) immediate for zoom responsiveness
	global_position.x = lerp(global_position.x, target.x, 1.0 - exp(-follow_smooth * delta))
	global_position.z = lerp(global_position.z, target.z, 1.0 - exp(-follow_smooth * delta))
	global_position.y = height  # Always use exact height for immediate zoom response
	
	# Debug output every few seconds
	if Engine.get_frames_drawn() % 60 == 0:
		print("Camera position: ", global_position)
		print("Player position: ", player.global_position)
		print("Camera rotation: ", $Camera3D.rotation_degrees)
