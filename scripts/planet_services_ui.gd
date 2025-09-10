extends Control

@onready var refuel_button: Button = get_node_or_null("ServicePanel/VBoxContainer/RefuelButton")
@onready var repair_button: Button = get_node_or_null("ServicePanel/VBoxContainer/RepairButton")
@onready var sell_ore_button: Button = get_node_or_null("ServicePanel/VBoxContainer/SellOreButton")
@onready var status_label: Label = get_node_or_null("ServicePanel/VBoxContainer/StatusLabel")
@onready var service_panel: Panel = get_node_or_null("ServicePanel")

var current_planet: Node3D = null
var player_reference: Node3D = null

func _ready():
	# Connect button signals with null checks
	if refuel_button:
		refuel_button.pressed.connect(_on_refuel_pressed)
	if repair_button:
		repair_button.pressed.connect(_on_repair_pressed)
	if sell_ore_button:
		sell_ore_button.pressed.connect(_on_sell_ore_pressed)
	
	# Initially hide the panel
	visible = false


func show_services(planet: Node3D, player: Node3D):
	print("DEBUG: show_services called for planet:", planet.planet_name if planet.has_method("get") and planet.get("planet_name") else "Unknown")
	current_planet = planet
	player_reference = player
	
	# Check available services
	var has_fuel_depot = planet.get("has_fuel_depot") and planet.has_fuel_depot
	var has_repair_bay = planet.get("has_repair_bay") and planet.has_repair_bay
	var has_ore_market = planet.get("has_ore_market") and planet.has_ore_market
	
	print("DEBUG: Services - Fuel:", has_fuel_depot, "Repair:", has_repair_bay, "Ore Market:", has_ore_market)
	
	# Update refuel button
	if has_fuel_depot:
		var fuel_needed = player.max_fuel - player.current_fuel
		var cost_per_unit = planet.get("fuel_cost_per_unit") if planet.get("fuel_cost_per_unit") else 2
		var total_cost = int(fuel_needed * cost_per_unit)
		
		if fuel_needed <= 0.1:
			if refuel_button:
				refuel_button.text = "FUEL TANK FULL"
				refuel_button.disabled = true
		elif player.total_credits >= total_cost:
			if refuel_button:
				refuel_button.text = "REFUEL (%d credits)" % total_cost
				refuel_button.disabled = false
		else:
			if refuel_button:
				refuel_button.text = "REFUEL (%d credits) - INSUFFICIENT FUNDS" % total_cost
				refuel_button.disabled = true
	else:
		if refuel_button:
			refuel_button.text = "NO FUEL DEPOT"
			refuel_button.disabled = true
	
	# Update repair button
	if has_repair_bay:
		var hull_damage = player.max_hull_integrity - player.current_hull_integrity
		var repair_cost_per_unit = planet.get("repair_cost_per_unit") if planet.get("repair_cost_per_unit") else 3
		var total_repair_cost = int(hull_damage * repair_cost_per_unit)
		
		if hull_damage <= 0.1:
			if repair_button:
				repair_button.text = "HULL INTACT"
				repair_button.disabled = true
		elif player.total_credits >= total_repair_cost:
			if repair_button:
				repair_button.text = "REPAIR HULL (%d credits)" % total_repair_cost
				repair_button.disabled = false
		else:
			if repair_button:
				repair_button.text = "REPAIR HULL (%d credits) - INSUFFICIENT FUNDS" % total_repair_cost
				repair_button.disabled = true
	else:
		if repair_button:
			repair_button.text = "NO REPAIR BAY"
			repair_button.disabled = true
	
	# Update sell ore button
	if has_ore_market:
		var player_ore_count = 0
		var total_ore_value = 0
		if player.has_method("get_mineral_inventory"):
			var minerals = player.get_mineral_inventory()
			for mineral in minerals:
				if mineral.amount > 0:
					player_ore_count += 1
					total_ore_value += int(mineral.amount * mineral.value_per_unit)
		
		if player_ore_count > 0:
			if sell_ore_button:
				sell_ore_button.text = "SELL ORE (%d credits)" % total_ore_value
				sell_ore_button.disabled = false
		else:
			if sell_ore_button:
				sell_ore_button.text = "SELL ORE - NO ORES"
				sell_ore_button.disabled = true
	else:
		if sell_ore_button:
			sell_ore_button.text = "NO ORE MARKET"
			sell_ore_button.disabled = true
	
	# Update status label
	var services = []
	if has_fuel_depot:
		services.append("Fuel Depot")
	if has_repair_bay:
		services.append("Repair Bay")
	
	if has_ore_market:
		services.append("Ore Market")
	
	if services.size() > 0:
		if status_label:
			status_label.text = "Available: " + ", ".join(services)
	else:
		if status_label:
			status_label.text = "No services available"
	
	# Show the panel
	visible = true

func hide_services():
	visible = false
	current_planet = null
	player_reference = null

func _on_refuel_pressed():
	if current_planet and player_reference:
		player_reference.attempt_refuel(current_planet)
		# Update the display after refuel attempt
		show_services(current_planet, player_reference)

func _on_repair_pressed():
	if current_planet and player_reference:
		player_reference.attempt_repair(current_planet)
		# Update the display after repair attempt
		show_services(current_planet, player_reference)

func _on_sell_ore_pressed():
	print("DEBUG: Sell ore button pressed - starting ore sale process")
	
	if not current_planet or not player_reference:
		return
	
	# Check if planet has ore market
	if not (current_planet.get("has_ore_market") and current_planet.has_ore_market):
		print("No ore market available on this planet")
		return
	
	# Get player's mineral inventory
	var minerals = []
	if player_reference.has_method("get_mineral_inventory"):
		minerals = player_reference.get_mineral_inventory()
	
	print("DEBUG: Found ", minerals.size(), " mineral entries in inventory")
	
	if minerals.size() == 0:
		print("No ores to sell")
		return
	
	var total_credits_earned = 0
	var ores_sold = []
	
	# Group minerals by name to avoid duplicates
	var mineral_groups = {}
	for mineral in minerals:
		if mineral.amount > 0:
			var name = mineral.display_name
			if not mineral_groups.has(name):
				mineral_groups[name] = {"total_amount": 0, "value_per_unit": mineral.value_per_unit}
			mineral_groups[name].total_amount += mineral.amount
	
	# Calculate credits and prepare sale data
	for mineral_name in mineral_groups.keys():
		var group = mineral_groups[mineral_name]
		var credits_for_ore = int(group.total_amount * group.value_per_unit)
		total_credits_earned += credits_for_ore
		ores_sold.append({
			"name": mineral_name,
			"amount": group.total_amount,
			"credits": credits_for_ore
		})
	
	# Remove all sold ores from inventory
	print("DEBUG: Inventory before removal: ", player_reference.mineral_inventory.size())
	for mineral_name in mineral_groups.keys():
		if player_reference.has_method("remove_mineral"):
			player_reference.remove_mineral(mineral_name, -1)  # -1 means remove all
	print("DEBUG: Inventory after removal: ", player_reference.mineral_inventory.size())
	
	# Clear the entire mineral inventory to ensure ores are gone
	player_reference.mineral_inventory.clear()
	print("DEBUG: Inventory after clear: ", player_reference.mineral_inventory.size())
	
	# Clear legacy inventory dictionary as well (for any UIs still referencing it)
	if "inventory" in player_reference:
		player_reference.inventory.clear()
		print("DEBUG: Legacy inventory dict cleared")
	
	# Update ship status UI to reflect cargo changes
	var ship_status_ui = get_node("/root/Main/UI/ShipStatusUI")
	if ship_status_ui and ship_status_ui.has_method("update_ship_status"):
		ship_status_ui.update_ship_status()

	# Update inventory panel if UIManager is present
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("update_inventory_display"):
		ui_manager.update_inventory_display()
	
	# Update the sell ore button state after clearing inventory
	show_services(current_planet, player_reference)
	
	# Add credits to player
	player_reference.total_credits += total_credits_earned
	
	# Print transaction summary
	print("=== ORE SALE COMPLETE ===")
	for ore in ores_sold:
		print("Sold %.1f units of %s for %d credits" % [ore.amount, ore.name, ore.credits])
	print("Total credits earned: %d" % total_credits_earned)
	print("New credit balance: %d" % player_reference.total_credits)
	
	# Update the display
	show_services(current_planet, player_reference)
