extends Node3D

var highlight_mesh: MeshInstance3D

# Rotation settings
@export var rotation_speed: float = 0.3  # Rotation speed in radians per second

# Planet data variables
@export var planet_name: String = "Earth"
@export var planet_type: String = "Terrestrial"
@export var atmosphere: String = "Nitrogen, Oxygen"
@export var habitable: bool = true
@export var temperature: float = 15.0  # Celsius
@export var resources: String = "Water, Minerals, Fossil Fuels"
@export var description: String = "The cradle of humanity with advanced orbital infrastructure."

# Fuel depot properties
@export var has_fuel_depot: bool = false
@export var fuel_cost_per_unit: float = 2.0
@export var depot_name: String = "Fuel Depot"

# Ore market properties
@export var has_ore_market: bool = false

# Repair bay properties
@export var has_repair_bay: bool = false
@export var repair_cost_per_unit: float = 3.0
@export var repair_bay_name: String = "Repair Bay"

# Refinery properties
@export var has_refinery: bool = false
@export var refinery_name: String = "Orbital Refinery"

# Scanning state
var is_scanned: bool = false
var in_scan_range: bool = false

#Planet Variables
@export var classification = "Terestrial Planet"
@export var size = "12,756"
@export var mass = "5.97 x 10"
@export var gravity = "9.8 m/s"

# Reference to the planet model
var planet_model: Node3D

func _ready():
	# Connect the Area3D's signals to our collision handler functions
	$Area3D.body_entered.connect(_on_body_entered)
	$Area3D.body_exited.connect(_on_body_exited)
	
	# Store reference to the planet model that will rotate
	planet_model = $Planet
	
	# Create the highlight mesh
	_create_highlight_mesh()
	
	# Add to the planets group for easier scanning detection
	add_to_group("planets")
	
	# Configure Earth-specific services
	if planet_name.contains("Earth") or planet_name == "Earth":
		has_fuel_depot = true
		has_repair_bay = true
		has_refinery = true
		fuel_cost_per_unit = 2.0
		repair_cost_per_unit = 3.0
		print("DEBUG: Earth services configured - refinery enabled")
	
	# Planet initialized - Added to 'planets' group
	
func _create_highlight_mesh():
	# Create a highlight mesh that's slightly larger than the planet
	# We'll add it to the root node (not to the planet model), so it won't rotate with the planet
	highlight_mesh = MeshInstance3D.new()
	add_child(highlight_mesh)
	
	# Use a sphere mesh to match the collision shape size
	var sphere = SphereMesh.new()
	sphere.radius = 11.0  # Smaller glow around the planet (was 20.0)
	sphere.height = 5.0  # Twice the radius
	highlight_mesh.mesh = sphere
	
	# Create a material with emission for the glow effect
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.2)  # White with 20% opacity
	material.emission_enabled = true
	material.emission = Color(0.0, 0.9, 1.0, 1.0)  # Bright blue glow with full opacity
	material.emission_energy = 40.0  # Significantly increased emission
	material.flags_transparent = true
	material.flags_unshaded = true
	
	highlight_mesh.material_override = material
	
	# Hide highlight by default
	highlight_mesh.visible = false
	
func _on_body_entered(body):
	# Check if the colliding body is the player
	if body.is_in_group("player"):
		# Show the highlight
		highlight_mesh.visible = true
		# Set in scan range flag
		in_scan_range = true
		
		# Notify player that planet is in scan range
		if body.has_method("on_planet_scan_range_entered"):
			body.on_planet_scan_range_entered(self)
		
func _on_body_exited(body):
	# Check if the exiting body is the player
	if body.is_in_group("player"):
		# Hide the highlight
		highlight_mesh.visible = false
		# Clear scan range flag
		in_scan_range = false
		
		# Notify player that planet is out of scan range
		if body.has_method("on_planet_scan_range_exited"):
			body.on_planet_scan_range_exited(self)

# Called every frame to handle rotation
func _process(delta):
	# Rotate only the planet model around the z axis, not the entire node
	planet_model.rotate_z(rotation_speed * delta)
	
	# Make sure highlight visibility matches scan range status
	if in_scan_range and not highlight_mesh.visible:
		highlight_mesh.visible = true
	elif not in_scan_range and highlight_mesh.visible:
		highlight_mesh.visible = false
