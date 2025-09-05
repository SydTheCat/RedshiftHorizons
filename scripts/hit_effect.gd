extends Node3D

# Simple hit effect script for laser impacts
# Attach this to objects that can be hit by lasers

@export var hit_effect_color: Color = Color(1.0, 0.3, 0.1, 1.0)
@export var hit_effect_duration: float = 0.3
@export var hit_flash_intensity: float = 2.0

# Original material of the parent mesh
var original_material: Material
var mesh_instance: MeshInstance3D
var hit_timer: float = 0.0
var is_hit: bool = false

func _ready():
	# Find the mesh instance in the parent
	mesh_instance = get_parent().get_node_or_null("MeshInstance3D")
	
	if mesh_instance:
		# Store the original material
		if mesh_instance.mesh and mesh_instance.mesh.get_surface_count() > 0:
			original_material = mesh_instance.mesh.surface_get_material(0)
		else:
			push_error("Mesh has no surfaces")
	else:
		push_error("No MeshInstance3D found in parent")

# Call this when the object is hit by a laser
func take_damage(amount: float):
	if mesh_instance and original_material:
		# Create a new material for the hit effect
		var hit_material = original_material.duplicate()
		
		# Make the material glow with the hit color
		if hit_material is StandardMaterial3D:
			hit_material.emission_enabled = true
			hit_material.emission = hit_effect_color
			hit_material.emission_energy_multiplier = hit_flash_intensity
			
			# Apply the hit material
			mesh_instance.set_surface_override_material(0, hit_material)
			
			# Start the hit timer
			hit_timer = hit_effect_duration
			is_hit = true
		else:
			push_error("Material is not a StandardMaterial3D")

func _process(delta):
	# Handle the hit effect timer
	if is_hit:
		hit_timer -= delta
		
		# When timer expires, restore original material
		if hit_timer <= 0:
			if mesh_instance:
				mesh_instance.set_surface_override_material(0, null)
				is_hit = false
