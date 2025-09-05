extends Control

# UI References
@onready var scan_status: Label = $Background/VBoxContainer/ScanHeader/ScanStatus
@onready var scan_icon: Label = $Background/VBoxContainer/ScanHeader/ScanIcon
@onready var progress_bar: ProgressBar = $Background/VBoxContainer/ProgressBar
@onready var mineral_type_label: Label = $Background/VBoxContainer/InfoContainer/MineralType
@onready var composition_label: Label = $Background/VBoxContainer/InfoContainer/Composition
@onready var amount_label: Label = $Background/VBoxContainer/InfoContainer/Amount
@onready var value_label: Label = $Background/VBoxContainer/InfoContainer/Value
@onready var hardness_label: Label = $Background/VBoxContainer/InfoContainer/Hardness

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
	hide()
	# Start with all info labels hidden
	hide_all_info()

func _process(delta):
	if is_scanning:
		update_scan_animation(delta)

func start_scan(asteroid: Node3D):
	print("Starting scan for asteroid: ", asteroid.name if asteroid else "null")
	if not asteroid:
		print("No asteroid provided")
		return
	
	# Check if asteroid has mineral_data property directly
	if not asteroid.has_method("get") and not "mineral_data" in asteroid:
		print("Asteroid has no mineral_data property or get method")
		return
	
	# Try to access mineral_data directly first, then via get method
	var mineral_data = null
	if "mineral_data" in asteroid:
		mineral_data = asteroid.mineral_data
	elif asteroid.has_method("get"):
		mineral_data = asteroid.get("mineral_data")
	
	if not mineral_data:
		print("Asteroid has no mineral_data")
		return
		
	current_asteroid = asteroid
	print("Mineral data found: ", mineral_data.display_name if mineral_data else "null")
	
	# Prepare info lines to reveal
	setup_info_lines(mineral_data)
	
	# Reset state
	scan_progress = 0.0
	current_line_index = 0
	is_scanning = true
	
	# Show the display
	show()
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	# Reset UI
	scan_status.text = "SCANNING..."
	progress_bar.value = 0.0
	hide_all_info()

func setup_info_lines(mineral_data: MineralData):
	info_lines.clear()
	print("Setting up info lines for mineral: ", mineral_data.display_name)
	
	# Prepare all the information lines
	info_lines.append({
		"label": mineral_type_label,
		"text": "Mineral Type: " + mineral_data.display_name,
		"delay": 0.5
	})
	
	info_lines.append({
		"label": composition_label, 
		"text": "Composition: " + mineral_data.get_composition_description(),
		"delay": 0.8
	})
	
	info_lines.append({
		"label": amount_label,
		"text": "Estimated Amount: " + str(int(mineral_data.amount)) + " units",
		"delay": 1.2
	})
	
	var total_value = int(mineral_data.amount * mineral_data.value_per_unit)
	info_lines.append({
		"label": value_label,
		"text": "Estimated Value: " + str(total_value) + " credits",
		"delay": 1.6
	})
	
	var hardness_desc = get_hardness_description(mineral_data.hardness)
	info_lines.append({
		"label": hardness_label,
		"text": "Hardness: " + hardness_desc + " (" + str(mineral_data.hardness) + ")",
		"delay": 2.0
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
