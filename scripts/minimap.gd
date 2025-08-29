extends Control

@export var minimap_size: float = 150.0
@export var scale_factor: float = 0.02
@export var min_scale: float = 0.005
@export var max_scale: float = 0.2

var player: Node3D
var planets: Array[Node3D] = []
var m_key_held: bool = false

func _ready():
	# Set up minimap size and position
	custom_minimum_size = Vector2(minimap_size, minimap_size)
	size = Vector2(minimap_size, minimap_size)
	
	# Position in top right corner
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	position.x -= minimap_size + 20
	position.y += 20
	
	# Find objects
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	# Find all planets
	var world_space = get_node("../../WorldSpace") if get_node_or_null("../../WorldSpace") else null
	if world_space:
		for child in world_space.get_children():
			if "Planet" in child.name:
				planets.append(child)
	
	print("Minimap found ", planets.size(), " planets - BRIGHT COLORS LOADED!")

func _draw():
	# Draw super bright background
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)  # Pure black for maximum contrast
	
	# Change border color when M key is held
	var border_color = Color(0, 2, 2) if not m_key_held else Color(2, 2, 0)  # Cyan normal, Yellow when M held
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 4.0)
	
	# Show zoom indicator when M key is held
	if m_key_held:
		var zoom_text = "ZOOM: " + str(round(1.0 / scale_factor))
		# Simple text indicator in top-left of minimap
		draw_rect(Rect2(5, 5, 60, 15), Color(0, 0, 0, 0.7))  # Semi-transparent background
	
	var center = size * 0.5
	
	# Draw player in center - extremely bright
	draw_circle(center, 8, Color(2, 2, 0))      # Super bright yellow outer
	draw_circle(center, 6, Color(2, 2, 2))      # Super bright white middle
	draw_circle(center, 4, Color(0, 2, 0))      # Super bright green center
	
	# Draw planets relative to player - extremely bright
	if player:
		for planet in planets:
			if is_instance_valid(planet):
				var planet_pos = world_to_minimap(planet.global_position)
				var screen_pos = center + planet_pos
				
				# Only draw if on screen
				if screen_pos.x >= 0 and screen_pos.x <= size.x and screen_pos.y >= 0 and screen_pos.y <= size.y:
					draw_circle(screen_pos, 12, Color(2, 0, 2))    # Super bright magenta outer
					draw_circle(screen_pos, 9, Color(2, 2, 2))     # Super bright white middle
					draw_circle(screen_pos, 6, Color(2, 1, 0))     # Super bright orange center

func world_to_minimap(world_pos: Vector3) -> Vector2:
	if not player:
		return Vector2.ZERO
	
	var player_pos = player.global_position
	var relative_pos = world_pos - player_pos
	return Vector2(relative_pos.x * scale_factor, relative_pos.z * scale_factor)

func _input(event):
	# Track M key held state
	if event is InputEventKey and event.keycode == KEY_M:
		m_key_held = event.pressed
		if event.pressed:
			print("Hold M + mouse wheel to zoom minimap")
	
	# Mouse wheel zoom only when M key is held
	if m_key_held and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			scale_factor = clamp(scale_factor * 0.8, min_scale, max_scale)  # Zoom in
			print("Minimap zoom in: ", scale_factor)
			get_viewport().set_input_as_handled()  # Prevent other nodes from processing this input
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			scale_factor = clamp(scale_factor * 1.25, min_scale, max_scale)  # Zoom out
			print("Minimap zoom out: ", scale_factor)
			get_viewport().set_input_as_handled()  # Prevent other nodes from processing this input

func _process(_delta):
	queue_redraw()
