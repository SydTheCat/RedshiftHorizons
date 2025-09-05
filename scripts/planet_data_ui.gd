extends Control

# References to UI elements
@onready var planet_name_label = $PlanetDataPanel/VBoxContainer/PlanetName
@onready var planet_data_panel = $PlanetDataPanel
@onready var classification_label = $PlanetDataPanel/VBoxContainer/Classification/Value
@onready var size_label = $PlanetDataPanel/VBoxContainer/Size/Value
@onready var mass_label = $PlanetDataPanel/VBoxContainer/Mass/Value
@onready var gravity_label = $PlanetDataPanel/VBoxContainer/Gravity/Value
@onready var atmosphere_label = $PlanetDataPanel/VBoxContainer/Atmosphere/Value
@onready var resources_label = $PlanetDataPanel/VBoxContainer/Resources/Value
@onready var habitable_label = $PlanetDataPanel/VBoxContainer/Habitable/Value
@onready var temperature_label = $PlanetDataPanel/VBoxContainer/Temperature/Value
@onready var scan_button = $ScanButton

var current_planet = null

func _ready():
	# Force the control to be visible and process
	visible = true
	show()
	show_behind_parent = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set z-index for the entire control
	z_index = 100
	
	# Ensure scan button is visible and on top
	if scan_button:
		scan_button.visible = true
		scan_button.show()
		scan_button.z_index = 100
		scan_button.pressed.connect(_on_scan_button_pressed)
	else:
		push_error("Scan button not found!")
	
	# Set up data panel
	if planet_data_panel:
		planet_data_panel.z_index = 100
		planet_data_panel.hide() # Hide initially but we made sure it can be shown later
	else:
		push_error("Planet data panel not found!")
	
	# Force update the CanvasItem
	queue_redraw()

# Called when scan button is pressed
func _on_scan_button_pressed():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
		
	# Find closest planet in scan range
	var closest_planet = null
	var closest_distance = 2000.0  # Increased maximum scan distance
	
	# Get all planet nodes
	var planets = get_tree().get_nodes_in_group("planets")
	
	if planets.size() == 0:
		push_error("No planets found in the 'planets' group!")
		return
	
	# Find closest planet that is in scan range (determined by Area3D collision)
	for planet in planets:
		if planet.in_scan_range:
			var distance = player.global_position.distance_to(planet.global_position)
			
			if distance < closest_distance:
				closest_distance = distance
				closest_planet = planet
	
	# If we have a closest_planet, make sure it's marked as in range
	if closest_planet:
		if not closest_planet.in_scan_range:
			closest_planet.in_scan_range = true
	
	if closest_planet:
		display_planet_data(closest_planet)
		closest_planet.is_scanned = true
		
# Display planet data on UI
func display_planet_data(planet):
	# Store reference to the current planet
	current_planet = planet
	
	# Mark planet as scanned
	planet.is_scanned = true
	
	# Force UI to be visible first
	visible = true
	show()
	
	# Check if we have UI elements initialized
	if planet_data_panel and planet_name_label and classification_label and size_label:
		planet_name_label.text = planet.get("planet_name") if planet.get("planet_name") != null else planet.name
		
		# Use get() for safe property access and direct use
		if planet.get("classification") != null:
			classification_label.text = str(planet.get("classification"))
		else:
			classification_label.text = "Unknown"
		
		if planet.get("size") != null:
			size_label.text = str(planet.get("size")) + " km"
		else:
			size_label.text = "Unknown"
		
		if planet.get("mass") != null:
			mass_label.text = str(planet.get("mass")) + " kg"
		else:
			mass_label.text = "Unknown"
		
		if planet.get("gravity") != null:
			gravity_label.text = str(planet.get("gravity"))
		else:
			gravity_label.text = "Unknown"
		
		if planet.get("atmosphere") != null:
			atmosphere_label.text = str(planet.get("atmosphere"))
		else:
			atmosphere_label.text = "Unknown"
		
		if planet.get("resources") != null:
			resources_label.text = str(planet.get("resources"))
		else:
			resources_label.text = "Unknown"
		
		if planet.get("habitable") != null:
			habitable_label.text = "Yes" if planet.get("habitable") else "No"
		else:
			habitable_label.text = "Unknown"
		
		if planet.get("temperature") != null:
			temperature_label.text = str(planet.get("temperature")) + " °C"
		else:
			temperature_label.text = "Unknown"
		
		# Show the data panel
		planet_data_panel.visible = true
		planet_data_panel.show()
		# Ensure it stays on top
		planet_data_panel.z_index = 100
		# Make sure all children are visible
		for child in planet_data_panel.find_children("*"):
			child.visible = true
	else:
		push_error("UI elements not found!")

# Clear displayed data
func clear_planet_data():
	current_planet = null
	planet_data_panel.hide()

# Process function to continuously check UI visibility
func _process(delta):
	# Make sure scan button is always visible
	if scan_button and not scan_button.visible:
		scan_button.visible = true
		scan_button.show()
	
	# If we have a current planet displayed
	if current_planet:
		# Check if planet is still in scan range
		if not current_planet.in_scan_range and planet_data_panel.visible:
			clear_planet_data()
		
		# If it is in range but panel is hidden, make sure panel remains visible
		elif planet_data_panel and not planet_data_panel.visible:
			planet_data_panel.visible = true
			planet_data_panel.show()
