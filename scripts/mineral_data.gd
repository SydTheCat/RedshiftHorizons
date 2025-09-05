extends Resource
class_name MineralData

# Mineral types available in asteroids
enum MineralType {
	IRON,
	COPPER,
	TITANIUM,
	GOLD,
	PLATINUM,
	RARE_EARTH,
	CRYSTAL_CORE
}

# Mineral properties
@export var mineral_type: MineralType
@export var amount: float
@export var rarity: float # 0.0 to 1.0, where 1.0 is most rare
@export var value_per_unit: int
@export var display_name: String
@export var color: Color
@export var hardness: float # 1.0 to 10.0, affects asteroid destruction difficulty

# Get a description of the mineral's composition
func get_composition_description() -> String:
	match mineral_type:
		MineralType.IRON:
			return "Ferrous oxide with trace carbon"
		MineralType.COPPER:
			return "Native copper with sulfide inclusions"
		MineralType.GOLD:
			return "Pure gold with quartz matrix"
		MineralType.PLATINUM:
			return "Platinum-group metals"
		MineralType.TITANIUM:
			return "Titanium dioxide ore"
		MineralType.RARE_EARTH:
			return "Mixed lanthanide elements"
		_:
			return "Unknown composition"

# Get a string description of the mineral
func get_description() -> String:
	return display_name + " (" + str(amount) + " units, " + str(value_per_unit) + " credits/unit)"

# Static data for different mineral types
static func get_mineral_info(type: MineralType) -> Dictionary:
	match type:
		MineralType.IRON:
			return {
				"name": "Iron Ore",
				"color": Color(0.7, 0.4, 0.2, 1.0),
				"rarity": 0.1,
				"value": 10,
				"min_amount": 5.0,
				"max_amount": 25.0,
				"hardness": 2.0
			}
		MineralType.COPPER:
			return {
				"name": "Copper Ore",
				"color": Color(0.8, 0.5, 0.2, 1.0),
				"rarity": 0.2,
				"value": 15,
				"min_amount": 3.0,
				"max_amount": 18.0,
				"hardness": 3.0
			}
		MineralType.TITANIUM:
			return {
				"name": "Titanium",
				"color": Color(0.6, 0.6, 0.7, 1.0),
				"rarity": 0.4,
				"value": 35,
				"min_amount": 2.0,
				"max_amount": 12.0,
				"hardness": 5.0
			}
		MineralType.GOLD:
			return {
				"name": "Gold",
				"color": Color(1.0, 0.8, 0.0, 1.0),
				"rarity": 0.6,
				"value": 75,
				"min_amount": 1.0,
				"max_amount": 8.0,
				"hardness": 4.0
			}
		MineralType.PLATINUM:
			return {
				"name": "Platinum",
				"color": Color(0.8, 0.8, 0.9, 1.0),
				"rarity": 0.8,
				"value": 120,
				"min_amount": 0.5,
				"max_amount": 5.0,
				"hardness": 6.0
			}
		MineralType.RARE_EARTH:
			return {
				"name": "Rare Earth Elements",
				"color": Color(0.4, 0.8, 0.4, 1.0),
				"rarity": 0.85,
				"value": 200,
				"min_amount": 0.2,
				"max_amount": 3.0,
				"hardness": 8.0
			}
		MineralType.CRYSTAL_CORE:
			return {
				"name": "Crystal Core",
				"color": Color(0.6, 0.2, 0.9, 1.0),
				"rarity": 0.95,
				"value": 500,
				"min_amount": 0.1,
				"max_amount": 1.0,
				"hardness": 10.0
			}
		_:
				return {
				"name": "Unknown",
				"color": Color.WHITE,
				"rarity": 0.0,
				"value": 1,
				"min_amount": 1.0,
				"max_amount": 1.0,
				"hardness": 1.0
			}

# Generate random mineral for an asteroid
static func generate_random_mineral() -> MineralData:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Weighted random selection based on rarity
	var rand_val = rng.randf()
	var selected_type: MineralType
	
	if rand_val < 0.4:  # 40% chance
		selected_type = MineralType.IRON
	elif rand_val < 0.65:  # 25% chance
		selected_type = MineralType.COPPER
	elif rand_val < 0.8:  # 15% chance
		selected_type = MineralType.TITANIUM
	elif rand_val < 0.9:  # 10% chance
		selected_type = MineralType.GOLD
	elif rand_val < 0.96:  # 6% chance
		selected_type = MineralType.PLATINUM
	elif rand_val < 0.99:  # 3% chance
		selected_type = MineralType.RARE_EARTH
	else:  # 1% chance
		selected_type = MineralType.CRYSTAL_CORE
	
	var info = get_mineral_info(selected_type)
	var mineral = MineralData.new()
	
	mineral.mineral_type = selected_type
	mineral.display_name = info.name
	mineral.color = info.color
	mineral.rarity = info.rarity
	mineral.value_per_unit = info.value
	mineral.amount = rng.randf_range(info.min_amount, info.max_amount)
	mineral.hardness = info.hardness
	
	return mineral
