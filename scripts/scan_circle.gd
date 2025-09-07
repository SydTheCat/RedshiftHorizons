extends Control

# Animation properties
@export var rotation_speed: float = 2.0
@export var pulse_speed: float = 3.0
@export var scan_line_speed: float = 4.0

# Visual properties
@export var outer_ring_color: Color = Color(0.0, 1.0, 1.0, 0.8)  # Cyan
@export var inner_ring_color: Color = Color(0.0, 0.8, 1.0, 0.6)  # Light blue
@export var scan_line_color: Color = Color(1.0, 1.0, 1.0, 0.9)   # White
@export var ring_thickness: float = 3.0

# Animation state
var time: float = 0.0
var is_active: bool = false
var is_locked: bool = false
var locked_position: Vector2

func _ready():
	# Start invisible
	modulate.a = 0.0
	visible = false

func _process(delta):
	if is_active:
		time += delta
		queue_redraw()

func _draw():
	if not is_active:
		return
		
	var center = size / 2.0
	var radius = min(size.x, size.y) / 2.0 - 10.0
	
	# Animated outer ring with rotation
	var outer_segments = 32
	var rotation_offset = time * rotation_speed
	for i in range(outer_segments):
		var angle1 = (i / float(outer_segments)) * TAU + rotation_offset
		var angle2 = ((i + 1) / float(outer_segments)) * TAU + rotation_offset
		
		# Create gaps in the ring for scanning effect
		if (i % 4) != int(time * 2) % 4:
			var p1 = center + Vector2(cos(angle1), sin(angle1)) * radius
			var p2 = center + Vector2(cos(angle2), sin(angle2)) * radius
			var p3 = center + Vector2(cos(angle2), sin(angle2)) * (radius - ring_thickness)
			var p4 = center + Vector2(cos(angle1), sin(angle1)) * (radius - ring_thickness)
			
			var points = PackedVector2Array([p1, p2, p3, p4])
			draw_colored_polygon(points, outer_ring_color)
	
	# Pulsing inner ring
	var inner_radius = radius * 0.7 + sin(time * pulse_speed) * 5.0
	var inner_segments = 24
	for i in range(inner_segments):
		var angle1 = (i / float(inner_segments)) * TAU
		var angle2 = ((i + 1) / float(inner_segments)) * TAU
		
		# Create animated segments
		if (i % 3) == int(time * 3) % 3:
			var p1 = center + Vector2(cos(angle1), sin(angle1)) * inner_radius
			var p2 = center + Vector2(cos(angle2), sin(angle2)) * inner_radius
			var p3 = center + Vector2(cos(angle2), sin(angle2)) * (inner_radius - ring_thickness * 0.7)
			var p4 = center + Vector2(cos(angle1), sin(angle1)) * (inner_radius - ring_thickness * 0.7)
			
			var points = PackedVector2Array([p1, p2, p3, p4])
			draw_colored_polygon(points, inner_ring_color)
	
	# Scanning lines that sweep around
	var scan_angle = time * scan_line_speed
	for i in range(3):
		var line_angle = scan_angle + (i * TAU / 3.0)
		var start_pos = center + Vector2(cos(line_angle), sin(line_angle)) * (radius * 0.3)
		var end_pos = center + Vector2(cos(line_angle), sin(line_angle)) * radius
		
		# Draw scanning line with gradient effect
		var line_color = scan_line_color
		line_color.a = 0.8 - (i * 0.2)  # Fade trailing lines
		draw_line(start_pos, end_pos, line_color, 2.0)
	
	# Central crosshair
	var crosshair_size = 8.0
	draw_line(center + Vector2(-crosshair_size, 0), center + Vector2(crosshair_size, 0), scan_line_color, 2.0)
	draw_line(center + Vector2(0, -crosshair_size), center + Vector2(0, crosshair_size), scan_line_color, 2.0)

func show_scan_circle():
	is_active = true
	visible = true
	is_locked = false  # Ensure it's unlocked when first shown
	print("Showing scan circle - is_locked: ", is_locked)
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func lock_scan_circle():
	# Lock the scan circle at its current position
	is_locked = true
	locked_position = position
	print("Scan circle LOCKED at position: ", locked_position)

func hide_scan_circle():
	is_active = false
	is_locked = false
	# Fade out animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): visible = false)

func set_position_from_world(world_pos: Vector3, camera: Camera3D):
	if camera and is_inside_tree():
		if not is_locked:
			# Follow the asteroid's movement
			var screen_pos = camera.unproject_position(world_pos)
			var new_pos = screen_pos - size / 2.0
			position = new_pos
			print("Scan circle tracking asteroid - screen_pos: ", screen_pos, " new_pos: ", new_pos, " is_locked: ", is_locked)
		else:
			# Stay locked at the locked position
			position = locked_position
			print("Scan circle locked at position: ", locked_position)
