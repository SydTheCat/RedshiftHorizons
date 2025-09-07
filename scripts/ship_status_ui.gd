extends Control

# Ship status UI in bottom left corner
@export var panel_width: float = 250.0
@export var panel_height: float = 140.0

var player: Node3D
var cargo_bar: ProgressBar
var hull_bar: ProgressBar
var fuel_bar: ProgressBar
var cargo_label: Label
var hull_label: Label
var fuel_label: Label
var background_panel: Panel

func _ready():
	# Set up UI panel size and position
	custom_minimum_size = Vector2(panel_width, panel_height)
	size = Vector2(panel_width, panel_height)
	
	# Position in bottom left corner
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	position.x += 20
	position.y -= panel_height + 20
	
	# Create background panel
	background_panel = Panel.new()
	background_panel.size = Vector2(panel_width, panel_height)
	background_panel.add_theme_color_override("bg_color", Color(0, 0, 0, 0.8))
	add_child(background_panel)
	
	# Add title
	var title_label = Label.new()
	title_label.text = "SHIP STATUS"
	title_label.position = Vector2(10, 5)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 12)
	add_child(title_label)
	
	# Create cargo label and bar
	cargo_label = Label.new()
	cargo_label.text = "CARGO"
	cargo_label.position = Vector2(10, 25)
	cargo_label.add_theme_color_override("font_color", Color.CYAN)
	cargo_label.add_theme_font_size_override("font_size", 11)
	add_child(cargo_label)
	
	cargo_bar = ProgressBar.new()
	cargo_bar.position = Vector2(60, 25)
	cargo_bar.size = Vector2(180, 16)
	cargo_bar.min_value = 0.0
	cargo_bar.max_value = 100.0
	cargo_bar.value = 0.0
	# Initial color will be set dynamically
	add_child(cargo_bar)
	
	# Create hull label and bar
	hull_label = Label.new()
	hull_label.text = "HULL"
	hull_label.position = Vector2(10, 50)
	hull_label.add_theme_color_override("font_color", Color.GREEN)
	hull_label.add_theme_font_size_override("font_size", 11)
	add_child(hull_label)
	
	hull_bar = ProgressBar.new()
	hull_bar.position = Vector2(60, 50)
	hull_bar.size = Vector2(180, 16)
	hull_bar.min_value = 0.0
	hull_bar.max_value = 100.0
	hull_bar.value = 100.0
	# Initial color will be set dynamically
	add_child(hull_bar)
	
	# Create fuel label and bar
	fuel_label = Label.new()
	fuel_label.text = "FUEL"
	fuel_label.position = Vector2(10, 75)
	fuel_label.add_theme_color_override("font_color", Color.YELLOW)
	fuel_label.add_theme_font_size_override("font_size", 11)
	add_child(fuel_label)
	
	fuel_bar = ProgressBar.new()
	fuel_bar.position = Vector2(60, 75)
	fuel_bar.size = Vector2(180, 16)
	fuel_bar.min_value = 0.0
	fuel_bar.max_value = 100.0
	fuel_bar.value = 100.0
	# Initial color will be set dynamically
	add_child(fuel_bar)
	
	# Wait for scene to be ready
	await get_tree().process_frame
	
	# Find player reference
	player = get_tree().get_first_node_in_group("player")

func _process(_delta):
	if player and is_instance_valid(player):
		update_ship_status()

func update_ship_status():
	# Update cargo bar
	if player.has_method("get_cargo_used"):
		var cargo_used = player.get_cargo_used()
		var max_cargo = player.max_cargo_space
		var cargo_percent = (cargo_used / max_cargo) * 100.0
		cargo_bar.value = cargo_percent
		
		# Change bar color based on cargo level
		if cargo_percent >= 90.0:
			cargo_bar.modulate = Color.RED
		elif cargo_percent >= 70.0:
			cargo_bar.modulate = Color.ORANGE
		else:
			cargo_bar.modulate = Color.CYAN
	
	# Update hull bar
	if player.has_method("get_hull_integrity"):
		var hull_percent = player.get_hull_integrity() * 100.0
		hull_bar.value = hull_percent
		
		# Change bar color based on damage level
		if hull_percent <= 30.0:
			hull_bar.modulate = Color.RED
		elif hull_percent <= 60.0:
			hull_bar.modulate = Color.ORANGE
		else:
			hull_bar.modulate = Color.GREEN
	else:
		# Default hull display if no damage system
		hull_bar.value = 100.0
		hull_bar.modulate = Color.GREEN
	
	# Update fuel bar
	if player.has_method("get_fuel_level"):
		var fuel_percent = player.get_fuel_level() * 100.0
		fuel_bar.value = fuel_percent
		
		# Change bar color based on fuel level
		if fuel_percent <= 20.0:
			fuel_bar.modulate = Color.RED
		elif fuel_percent <= 50.0:
			fuel_bar.modulate = Color.ORANGE
		else:
			fuel_bar.modulate = Color.YELLOW
	else:
		# Default fuel display if no fuel system
		fuel_bar.value = 100.0
		fuel_bar.modulate = Color.YELLOW
