extends Resource
class_name MultiMineralData

# Container for multiple minerals in a single asteroid
@export var minerals: Array[MineralData] = []
@export var total_hardness: float = 1.0
@export var dominant_mineral: MineralData

# Add a mineral to this asteroid
func add_mineral(mineral: MineralData):
	minerals.append(mineral)
	update_properties()

# Update calculated properties based on all minerals
func update_properties():
	if minerals.is_empty():
		return
	
	# Calculate total hardness as average of all minerals
	var hardness_sum = 0.0
	var total_value = 0.0
	var highest_value_mineral: MineralData = null
	
	for mineral in minerals:
		hardness_sum += mineral.hardness
		var mineral_value = mineral.amount * mineral.value_per_unit
		total_value += mineral_value
		
		if not highest_value_mineral or mineral_value > (highest_value_mineral.amount * highest_value_mineral.value_per_unit):
			highest_value_mineral = mineral
	
	total_hardness = hardness_sum / minerals.size()
	dominant_mineral = highest_value_mineral

# Get total value of all minerals
func get_total_value() -> int:
	var total = 0
	for mineral in minerals:
		total += int(mineral.amount * mineral.value_per_unit)
	return total

# Get total amount of all minerals
func get_total_amount() -> float:
	var total = 0.0
	for mineral in minerals:
		total += mineral.amount
	return total

# Get average hardness of all minerals
func get_average_hardness() -> float:
	if minerals.is_empty():
		return 0.0
	return total_hardness

# Get description of all minerals
func get_description() -> String:
	if minerals.is_empty():
		return "No minerals detected"
	
	var desc = "Multi-ore asteroid containing:\n"
	for mineral in minerals:
		desc += "• %s: %.1f units (%.0f credits)\n" % [
			mineral.display_name,
			mineral.amount,
			mineral.amount * mineral.value_per_unit
		]
	desc += "Total Value: %d credits" % get_total_value()
	return desc

# Generate a multi-mineral asteroid (20% chance for multi-ore)
static func generate_random_multi_mineral() -> MultiMineralData:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var multi_mineral = MultiMineralData.new()
	
	# 20% chance for multi-ore asteroid
	if rng.randf() < 0.2:
		# Generate 2-3 different minerals
		var num_minerals = rng.randi_range(2, 3)
		var used_types: Array[MineralData.MineralType] = []
		
		for i in range(num_minerals):
			var mineral = MineralData.generate_random_mineral()
			
			# Ensure we don't duplicate mineral types
			while mineral.mineral_type in used_types:
				mineral = MineralData.generate_random_mineral()
			
			used_types.append(mineral.mineral_type)
			
			# Reduce amounts slightly for multi-ore asteroids
			mineral.amount *= 0.7
			multi_mineral.add_mineral(mineral)
	else:
		# Single mineral asteroid
		var mineral = MineralData.generate_random_mineral()
		multi_mineral.add_mineral(mineral)
	
	return multi_mineral
