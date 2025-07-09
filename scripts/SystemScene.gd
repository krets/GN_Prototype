# =============================================================================
# UPDATED SYSTEMSCENE.GD - Replace your existing SystemScene.gd with this
# =============================================================================
# SystemScene.gd
extends Node2D
class_name SystemScene

@onready var celestial_bodies_container = $CelestialBodies
@onready var player_spawn = $PlayerSpawn

func _ready():
	UniverseManager.system_changed.connect(_on_system_changed)
	setup_system(UniverseManager.get_current_system())

func _on_system_changed(system_id: String):
	setup_system(UniverseManager.get_current_system())

func setup_system(system_data: Dictionary):
	clear_system()
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


func spawn_celestial_bodies(bodies_data: Array):
	for body_data in bodies_data:
		var celestial_body = preload("res://scenes/CelestialBody.tscn").instantiate()
		celestial_body.celestial_data = body_data
		celestial_body.position = Vector2(body_data.position.x, body_data.position.y)
		celestial_bodies_container.add_child(celestial_body)
