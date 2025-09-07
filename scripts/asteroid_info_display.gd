extends Control

# UI References - using get_node instead of @onready to handle missing nodes gracefully
var scan_status: Label
var scan_icon: Label
var progress_bar: ProgressBar
var mineral_type_label: Label
var composition_label: Label
var amount_label: Label
var value_label: Label
var hardness_label: Label

# Animation properties
@export var scan_duration: float = 2.5
@export var line_reveal_delay: float = 0.4

# State
var current_asteroid: Node3D = null
var scan_progress: float = 0.0
var is_scanning: bool = false
var info_lines: Array[Dictionary] = []
var current_line_index: int = 0

# Scanning animation icons
var scan_icons: Array[String] = ["◉", "◎", "○", "◌"]
var icon_index: int = 0

func _ready():
	print("AsteroidInfoDisplay _ready() called")
	
	# Get UI node references safely
	scan_status = get_node_or_null("Background/VBoxContainer/ScanHeader/ScanStatus")
	scan_icon = get_node_or_null("Background/VBoxContainer/ScanHeader/ScanIcon")
	progress_bar = get_node_or_null("Background/VBoxContainer/ProgressBar")
	mineral_type_label = get_node_or_null("Background/VBoxContainer/InfoContainer/MineralType")
	composition_label = get_node_or_null("Background/VBoxContainer/InfoContainer/Composition")
	amount_label = get_node_or_null("Background/VBoxContainer/InfoContainer/Amount")
	value_label = get_node_or_null("Background/VBoxContainer/InfoContainer/Value")
	hardness_label = get_node_or_null("Background/VBoxContainer/InfoContainer/Hardness")
	
	print("UI nodes found:")
	print("  scan_status: ", scan_status)
	print("  scan_icon: ", scan_icon)
	print("  progress_bar: ", progress_bar)
	print("  mineral_type_label: ", mineral_type_label)
	print("  composition_label: ", composition_label)
	print("  amount_label: ", amount_label)
	print("  value_label: ", value_label)
	print("  hardness_label: ", hardness_label)
	
	hide()
	# Start with all info labels hidden
	hide_all_info()

func _process(delta):
	if is_scanning:
		update_scan_animation(delta)

func start_scan(asteroid: Node3D):
	print("=== STARTING SCAN ===")
	print("Asteroid: ", asteroid.name if asteroid else "null")
	print("Asteroid valid: ", is_instance_valid(asteroid))
	
	if not asteroid:
		print("ERROR: No asteroid provided")
		return
	
	if not is_instance_valid(asteroid):
		print("ERROR: Asteroid instance is not valid")
		return
	
	# Debug asteroid properties
	print("Asteroid groups: ", asteroid.get_groups())
	print("Asteroid has mineral_data property: ", "mineral_data" in asteroid)
	print("Asteroid has get method: ", asteroid.has_method("get"))
	
	# Check if asteroid has mineral_data property directly
	if not asteroid.has_method("get") and not "mineral_data" in asteroid:
		print("ERROR: Asteroid has no mineral_data property or get method")
		return
	
	# Try to access mineral_data directly first, then via get method
	var mineral_data = null
	if "mineral_data" in asteroid:
		mineral_data = asteroid.mineral_data
		print("Got mineral_data directly: ", mineral_data)
	elif asteroid.has_method("get"):
		mineral_data = asteroid.get("mineral_data")
		print("Got mineral_data via get(): ", mineral_data)
	
	if not mineral_data:
		print("ERROR: Asteroid has no mineral_data - ", asteroid.name)
		print("Asteroid script: ", asteroid.get_script())
		return
		
	current_asteroid = asteroid
	if mineral_data and mineral_data.has_method("get_total_value"):
		print("Mineral data found: Multi-ore asteroid with ", mineral_data.minerals.size(), " minerals")
	elif mineral_data:
		print("Mineral data found: ", mineral_data.display_name)
	else:
		print("Mineral data found: null")
	
	# Check if UI nodes are available
	if not scan_status or not progress_bar:
		print("ERROR: UI nodes not found, using fallback display")
		show_fallback_display(mineral_data)
		return
	
	# Prepare info lines to reveal
	setup_info_lines(mineral_data)
	
	# Reset state
	scan_progress = 0.0
	current_line_index = 0
	is_scanning = true
	
	# Show the display
	visible = true
	show()
	modulate.a = 0.0
	print("Display shown, visible: ", visible, " modulate: ", modulate)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	print("Tween started for fade in")
	
	# Reset UI
	scan_status.text = "SCANNING..."
	progress_bar.value = 0.0
	hide_all_info()

func setup_info_lines(mineral_data):
	info_lines.clear()
	
	# Check if it's multi-mineral data
	if mineral_data.has_method("get_total_value"):
		print("Setting up info lines for multi-mineral asteroid")
		setup_multi_mineral_info_lines(mineral_data)
	else:
		print("Setting up info lines for single mineral: ", mineral_data.display_name)
		setup_single_mineral_info_lines(mineral_data)
	
	print("Setup ", info_lines.size(), " info lines")

func setup_single_mineral_info_lines(mineral_data: MineralData):
	# Prepare all the information lines for single mineral
	info_lines.append({
		"label": mineral_type_label,
		"text": "Mineral Type: " + mineral_data.display_name,
		"delay": 0.5
	})
	
	info_lines.append({
		"label": composition_label,
		"text": "Composition: " + mineral_data.composition,
		"delay": 1.0
	})
	
	info_lines.append({
		"label": amount_label,
		"text": "Amount: %.1f units" % mineral_data.amount,
		"delay": 1.5
	})
	
	info_lines.append({
		"label": value_label,
		"text": "Value: %d credits/unit" % mineral_data.value_per_unit,
		"delay": 2.0
	})
	
	var hardness_desc = get_hardness_description(mineral_data.hardness)
	info_lines.append({
		"label": hardness_label,
		"text": "Hardness: " + hardness_desc + " (" + str(mineral_data.hardness) + ")",
		"delay": 2.5
	})

func setup_multi_mineral_info_lines(multi_mineral_data: MultiMineralData):
	# Show multi-ore asteroid header
	info_lines.append({
		"label": mineral_type_label,
		"text": "Multi-Ore Asteroid (%d types)" % multi_mineral_data.minerals.size(),
		"delay": 0.5
	})
	
	# Show composition summary
	var composition_text = "Contains: "
	for i in range(multi_mineral_data.minerals.size()):
		if i > 0:
			composition_text += ", "
		composition_text += multi_mineral_data.minerals[i].display_name
	
	info_lines.append({
		"label": composition_label,
		"text": composition_text,
		"delay": 1.0
	})
	
	# Show total amount
	info_lines.append({
		"label": amount_label,
		"text": "Total Amount: %.1f units" % multi_mineral_data.get_total_amount(),
		"delay": 1.5
	})
	
	# Show total value
	info_lines.append({
		"label": value_label,
		"text": "Total Value: %d credits" % multi_mineral_data.get_total_value(),
		"delay": 2.0
	})
	
	# Show average hardness
	info_lines.append({
		"label": hardness_label,
		"text": "Avg Hardness: %.1f" % multi_mineral_data.get_average_hardness(),
		"delay": 2.5
	})
	print("Created ", info_lines.size(), " info lines")

func get_hardness_description(hardness: float) -> String:
	if hardness <= 2.0:
		return "Very Soft"
	elif hardness <= 4.0:
		return "Soft"
	elif hardness <= 6.0:
		return "Medium"
	elif hardness <= 8.0:
		return "Hard"
	else:
		return "Very Hard"

func update_scan_animation(delta):
	# Update progress
	scan_progress += delta / scan_duration
	progress_bar.value = scan_progress * 100.0
	
	# Animate scan icon
	icon_index = int(Time.get_time_dict_from_system()["second"] * 4) % scan_icons.size()
	scan_icon.text = scan_icons[icon_index]
	
	# Reveal info lines based on progress
	for i in range(info_lines.size()):
		var line_data = info_lines[i]
		var reveal_time = line_data.delay / scan_duration
		
		if scan_progress >= reveal_time and i >= current_line_index:
			print("Revealing line ", i, " at progress ", scan_progress)
			reveal_info_line(i)
			current_line_index = i + 1
	
	# Complete scan
	if scan_progress >= 1.0:
		complete_scan()

func reveal_info_line(index: int):
	if index >= info_lines.size():
		return
		
	var line_data = info_lines[index]
	var label = line_data.label
	
	# Show the label with typewriter effect
	label.visible = true
	label.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	
	# Set the text directly and ensure label is properly sized
	var full_text = line_data.text
	label.text = full_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	print("Setting label text to: ", full_text)

func complete_scan():
	is_scanning = false
	scan_status.text = "SCAN COMPLETE"
	scan_icon.text = "✓"
	progress_bar.value = 100.0
	
	# Auto-hide after a delay
	var hide_timer = Timer.new()
	add_child(hide_timer)
	hide_timer.wait_time = 3.0
	hide_timer.one_shot = true
	hide_timer.timeout.connect(hide_display)
	hide_timer.start()

func hide_display():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): hide())

func hide_all_info():
	mineral_type_label.visible = false
	composition_label.visible = false
	amount_label.visible = false
	value_label.visible = false
	hardness_label.visible = false

func stop_scan():
	is_scanning = false
	hide_display()

func show_fallback_display(multi_mineral_data):
	# Create a simple label-based display as fallback
	print("Creating fallback display for multi-mineral asteroid")
	
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	
	# Create a simple background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.size = Vector2(350, 250)
	add_child(bg)
	
	# Create info text for multiple minerals
	var info_label = Label.new()
	var text = "SCAN COMPLETE\n\nMulti-Ore Asteroid:\n"
	
	if multi_mineral_data and multi_mineral_data.minerals:
		for mineral in multi_mineral_data.minerals:
			text += "• %s: %.1f units (%d credits)\n" % [
				mineral.display_name,
				mineral.amount,
				int(mineral.amount * mineral.value_per_unit)
			]
		text += "\nTotal Value: %d credits" % multi_mineral_data.get_total_value()
	else:
		text += "No mineral data available"
	
	info_label.text = text
	info_label.position = Vector2(10, 10)
	info_label.size = Vector2(330, 230)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info_label)
	
	# Show the display
	visible = true
	show()
	modulate.a = 1.0
	print("Fallback display shown")
	
	# Auto-hide after delay
	var hide_timer = Timer.new()
	add_child(hide_timer)
	hide_timer.wait_time = 5.0
	hide_timer.one_shot = true
	hide_timer.timeout.connect(hide_display)
	hide_timer.start()

func set_position_near_cursor(cursor_pos: Vector2):
	# Position the info display near the cursor but not overlapping
	var display_size = size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Default position to the right of cursor
	var new_pos = cursor_pos + Vector2(20, -display_size.y / 2)
	
	# Adjust if going off screen
	if new_pos.x + display_size.x > viewport_size.x:
		new_pos.x = cursor_pos.x - display_size.x - 20
	
	if new_pos.y < 0:
		new_pos.y = 10
	elif new_pos.y + display_size.y > viewport_size.y:
		new_pos.y = viewport_size.y - display_size.y - 10
	
	position = new_pos
