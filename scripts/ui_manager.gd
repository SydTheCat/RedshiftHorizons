extends Control
class_name UIManager

# UI elements for mining system
var tooltip_label: Label
var notification_label: Label
var inventory_panel: Panel
var inventory_label: Label

# Tooltip management
var tooltip_visible: bool = false
var notification_timer: Timer
var inventory_update_timer: Timer

func _ready():
	# Add to UI manager group for easy access
	add_to_group("ui_manager")
	
	# Set up UI elements
	setup_tooltip()
	setup_notifications()
	setup_inventory_display()
	
	# Set up notification timer
	notification_timer = Timer.new()
	notification_timer.one_shot = true
	notification_timer.timeout.connect(_on_notification_timeout)
	add_child(notification_timer)
	
	# Set up inventory update timer for live updates
	inventory_update_timer = Timer.new()
	inventory_update_timer.wait_time = 0.1  # Update 10 times per second
	inventory_update_timer.timeout.connect(_on_inventory_update_timer_timeout)
	add_child(inventory_update_timer)

func setup_tooltip():
	# Create tooltip label
	tooltip_label = Label.new()
	tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	tooltip_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	tooltip_label.add_theme_constant_override("shadow_offset_x", 2)
	tooltip_label.add_theme_constant_override("shadow_offset_y", 2)
	tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tooltip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tooltip_label.visible = false
	tooltip_label.z_index = 100
	add_child(tooltip_label)

func setup_notifications():
	# Create notification label
	notification_label = Label.new()
	notification_label.add_theme_color_override("font_color", Color.YELLOW)
	notification_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	notification_label.add_theme_constant_override("shadow_offset_x", 2)
	notification_label.add_theme_constant_override("shadow_offset_y", 2)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.anchors_preset = Control.PRESET_TOP_WIDE
	notification_label.position.y = 50
	notification_label.visible = false
	notification_label.z_index = 100
	add_child(notification_label)

func setup_inventory_display():
	# Create inventory panel (initially hidden)
	inventory_panel = Panel.new()
	inventory_panel.add_theme_color_override("bg_color", Color(0, 0, 0, 0.8))
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	inventory_panel.size = Vector2(350, 250)
	inventory_panel.position = Vector2(20, 20)
	inventory_panel.visible = false
	inventory_panel.z_index = 50
	add_child(inventory_panel)
	
	# Create inventory label
	inventory_label = Label.new()
	inventory_label.add_theme_color_override("font_color", Color.WHITE)
	inventory_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	inventory_label.add_theme_constant_override("shadow_offset_x", 1)
	inventory_label.add_theme_constant_override("shadow_offset_y", 1)
	inventory_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_label.add_theme_constant_override("margin_left", 10)
	inventory_label.add_theme_constant_override("margin_right", 10)
	inventory_label.add_theme_constant_override("margin_top", 10)
	inventory_label.add_theme_constant_override("margin_bottom", 10)
	inventory_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_panel.add_child(inventory_label)

func _input(event):
	# Toggle inventory with Tab key
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			toggle_inventory()

func show_tooltip(text: String, world_position: Vector3):
	if not tooltip_label:
		return
		
	tooltip_label.text = text
	tooltip_label.visible = true
	tooltip_visible = true
	
	# Convert world position to screen position
	var camera = get_viewport().get_camera_3d()
	if camera:
		var screen_pos = camera.unproject_position(world_position)
		# Offset tooltip above the cursor
		screen_pos.y -= 60
		tooltip_label.position = screen_pos - tooltip_label.size / 2

func hide_tooltip():
	if tooltip_label:
		tooltip_label.visible = false
		tooltip_visible = false

func show_collection_notification(message: String):
	if not notification_label:
		return
		
	notification_label.text = message
	notification_label.visible = true
	
	# Hide after 3 seconds
	notification_timer.start(3.0)

func _on_notification_timeout():
	if notification_label:
		notification_label.visible = false

func toggle_inventory():
	if not inventory_panel:
		print("ERROR: inventory_panel is null")
		return
		
	inventory_panel.visible = not inventory_panel.visible
	print("Inventory panel visibility: ", inventory_panel.visible)
	
	if inventory_panel.visible:
		update_inventory_display()
		# Start live updates when inventory is shown
		inventory_update_timer.start()
	else:
		# Stop live updates when inventory is hidden
		inventory_update_timer.stop()

func update_inventory_display():
	if not inventory_label:
		print("ERROR: inventory_label is null")
		return
		
	# Get player inventory
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_inventory_summary"):
		var summary = player.get_inventory_summary()
		inventory_label.text = summary
	else:
		inventory_label.text = "Player inventory not available\nPress Tab to toggle this panel\nShoot asteroids to collect minerals!"

func _on_inventory_update_timer_timeout():
	# Only update if inventory is visible
	if inventory_panel and inventory_panel.visible:
		update_inventory_display()

func _process(delta):
	# Update tooltip position if visible
	if tooltip_visible and tooltip_label and tooltip_label.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		tooltip_label.position = mouse_pos + Vector2(10, -60)
	
	# Check for asteroid hover using raycast
	check_asteroid_hover()

func check_asteroid_hover():
	# Only show tooltips when right mouse button is pressed
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if tooltip_visible:
			hide_tooltip()
		return
	
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Default collision layer
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.get("collider")
		if collider and collider.has_method("show_mineral_tooltip"):
			# Show tooltip for this asteroid
			if not tooltip_visible:
				collider.show_mineral_tooltip()
		else:
			# Hide tooltip if not hovering over asteroid
			if tooltip_visible:
				hide_tooltip()
	else:
		# Hide tooltip if not hitting anything
		if tooltip_visible:
			hide_tooltip()
