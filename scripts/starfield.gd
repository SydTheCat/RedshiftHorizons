extends Node3D

# Configuration parameters - Generate all stars at startup
@export var total_stars: int = 500  # Total stars to generate across the system
@export var system_radius: float = 4000.0  # Match asteroid spawner system size
@export var background_y_offset: float = -1500.0  # Position stars much further behind planets
@export var y_variation: float = 50.0  # Limited Y variation to keep stars as background
@export var star_scale_min: float = 0.3
@export var star_scale_max: float = 0.7

# System parameters
var player: Node3D = null
var stars_container: Node3D = null
var initialized: bool = false
var _rng = RandomNumberGenerator.new()

# Simple star properties
var star_material = null
var star_mesh = null

# Called when the node enters the scene tree for the first time.
func _ready():
	_rng.randomize()
	
	# Create shared resources for stars
	create_shared_resources()
	
	# Find player node
	find_player_node()
	
	# Create container for all stars
	stars_container = Node3D.new()
	stars_container.name = "StarsContainer"
	add_child(stars_container)
	
	# Generate all stars at startup
	generate_all_stars()
	
	# Flag as initialized
	initialized = true
	print("Starfield initialized with %d stars" % total_stars)

# Create shared resources used by all stars
func create_shared_resources() -> void:
	# Create shared material
	star_material = StandardMaterial3D.new()
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.albedo_color = Color(1, 1, 1)  # White
	star_material.emission_enabled = true
	star_material.emission = Color(1, 1, 1)  # White emission
	star_material.emission_energy_multiplier = 2.0
	
	# Create shared mesh
	star_mesh = SphereMesh.new()
	star_mesh.radius = 0.5
	star_mesh.height = 1.0
	star_mesh.material = star_material

# Find the player node
func find_player_node() -> void:
	# Find the player
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		# Try finding by common player node names
		var root = get_tree().current_scene
		player = root.find_child("Player", true, false)
		if player == null:
			player = root.find_child("player", true, false)

# Generate all stars at startup like asteroid spawner
func generate_all_stars() -> void:
	print("Generating %d stars across system..." % total_stars)
	
	for i in range(total_stars):
		# Generate random position within system bounds
		var angle = _rng.randf() * TAU
		var distance = _rng.randf() * system_radius
		
		var pos = Vector3(
			cos(angle) * distance,
			background_y_offset + (_rng.randf() * y_variation),
			sin(angle) * distance
		)
		
		# Create the star
		create_star(pos)
	
	print("Star generation complete!")

# No continuous processing needed - all stars generated at startup
func _process(delta):
	# Stars are static background elements, no processing needed
	pass
		
# Get total number of stars generated
func get_star_count() -> int:
	return stars_container.get_child_count() if stars_container else 0

# Create a single star at the given position
func create_star(pos: Vector3) -> void:
	# Create a mesh instance for the star using shared resources
	var star = MeshInstance3D.new()
	star.mesh = star_mesh
	star.position = pos
	
	# Random scale variation
	var scale_factor = star_scale_min + _rng.randf() * (star_scale_max - star_scale_min)
	star.scale = Vector3(scale_factor, scale_factor, scale_factor)
	
	# Random color tint for variety
	var material = star_material.duplicate()
	var color_tint = Color(0.9 + _rng.randf() * 0.1, 0.9 + _rng.randf() * 0.1, 1.0)
	material.albedo_color = color_tint
	material.emission = color_tint
	star.material_override = material
	
	# Add to stars container
	stars_container.add_child(star)
