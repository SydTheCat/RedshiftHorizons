extends Node3D

@export var recenter_distance := 5000.0
@onready var world_space: Node3D = $WorldSpace
var player: Node3D

func _ready():
	# Set black background color
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))
	
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_dt):
	# Safety check for player
	if not player or not is_instance_valid(player): 
		# Try to find player again
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
	
	# GDScript doesn't support try/except - use if checks instead
	if player and is_instance_valid(player) and world_space:
		var d := Vector2(player.global_position.x, player.global_position.z).length()
		if d > recenter_distance:
			var shift := -player.global_position
			shift.y = 0.0
			for c in world_space.get_children():
				c.global_position += shift
			# CameraRig stays outside WorldSpace so it doesn't move.
