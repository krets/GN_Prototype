# =============================================================================
# UPDATED SYSTEMSCENE.GD - Replace your existing SystemScene.gd with this
# =============================================================================
# SystemScene.gd
extends Node2D
class_name SystemScene

@onready var celestial_bodies_container = $CelestialBodies
@onready var player_spawn = $PlayerSpawn

var parallax_starfield: ParallaxStarfield

func _ready():
	UniverseManager.system_changed.connect(_on_system_changed)
	setup_system(UniverseManager.get_current_system())

func _on_system_changed(system_id: String):
	setup_system(UniverseManager.get_current_system())

func setup_system(system_data: Dictionary):
	clear_system()
	setup_parallax_starfield(system_data)
	spawn_celestial_bodies(system_data.get("celestial_bodies", []))
	
	# Spawn player at designated location
	var player = UniverseManager.player_ship
	if player and player_spawn:
		player.global_position = player_spawn.global_position
		player.linear_velocity = Vector2.ZERO
		player.angular_velocity = 0.0

func clear_system():
	for child in celestial_bodies_container.get_children():
		child.queue_free()
	
	# Remove old starfield
	if parallax_starfield:
		parallax_starfield.queue_free()
		parallax_starfield = null

func setup_parallax_starfield(system_data: Dictionary):
	# Load and instantiate the parallax starfield scene
	var starfield_scene = preload("res://scenes/ParallaxStarfield.tscn")
	parallax_starfield = starfield_scene.instantiate()
	
	# Add it as the first child (renders behind everything)
	add_child(parallax_starfield)
	move_child(parallax_starfield, 0)
	
	# Configure the starfield for this system
	parallax_starfield.load_system_starfield(system_data)
	
	print("Setup parallax starfield for system: ", system_data.get("name", "Unknown"))

func spawn_celestial_bodies(bodies_data: Array):
	for body_data in bodies_data:
		var celestial_body = preload("res://scenes/CelestialBody.tscn").instantiate()
		celestial_body.celestial_data = body_data
		celestial_body.position = Vector2(body_data.position.x, body_data.position.y)
		celestial_bodies_container.add_child(celestial_body)
