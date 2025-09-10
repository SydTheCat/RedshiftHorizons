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

var current_planet = null

func _ready():
	# Force the control to be visible and process
	visible = true
	show()
	show_behind_parent = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set z-index for the entire control
	z_index = 100
	
	
	# Set up data panel
	if planet_data_panel:
		planet_data_panel.z_index = 100
		planet_data_panel.hide() # Hide initially but we made sure it can be shown later
	else:
		push_error("Planet data panel not found!")
	
	# Force update the CanvasItem
	queue_redraw()

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
		
		# Add fuel depot information if available
		print("Checking fuel depot - has_fuel_depot: ", planet.get("has_fuel_depot"))
		if planet.get("has_fuel_depot") != null and planet.get("has_fuel_depot"):
			var depot_name = planet.get("depot_name") if planet.get("depot_name") else "Fuel Depot"
			var cost_per_unit = planet.get("fuel_cost_per_unit") if planet.get("fuel_cost_per_unit") else 2
			
			print("Adding fuel depot info: ", depot_name, " at ", cost_per_unit, " credits/unit")
			# Update resources to include fuel depot info
			var current_resources = resources_label.text
			resources_label.text = current_resources + "\n🛸 " + depot_name + " (" + str(cost_per_unit) + " credits/unit)"
		else:
			print("No fuel depot found on planet")
		
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
func _process(_delta):
	
	# If we have a current planet displayed
	if current_planet:
		# Check if planet is still in scan range
		if not current_planet.in_scan_range and planet_data_panel.visible:
			clear_planet_data()
		
		# If it is in range but panel is hidden, make sure panel remains visible
		elif planet_data_panel and not planet_data_panel.visible:
			planet_data_panel.visible = true
			planet_data_panel.show()
