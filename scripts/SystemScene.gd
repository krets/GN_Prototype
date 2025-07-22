# =============================================================================
# SYSTEM SCENE - Now manages planet animations per system
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
	# Pause animations in old system before switching
	pause_all_planet_animations()
	setup_system(UniverseManager.get_current_system())

func setup_system(system_data: Dictionary):
	clear_system()
	spawn_celestial_bodies(system_data.get("celestial_bodies", []))
	
	# Only position player at spawn if it's not a hyperspace transition
	var player = UniverseManager.player_ship
	if player and player_spawn:
		# Check if player is in hyperspace sequence
		if player.hyperspace_state == player.HyperspaceState.NORMAL:
			# Normal spawn (e.g., game start)
			player.global_position = player_spawn.global_position
			player.linear_velocity = Vector2.ZERO
			player.angular_velocity = 0.0
			
			# Force camera update
			var camera = player.get_node("Camera2D")
			if camera:
				camera.global_position = player.global_position
				camera.force_update_scroll()
		# If in hyperspace, let the player ship handle its own positioning

func clear_system():
	for child in celestial_bodies_container.get_children():
		child.queue_free()

func spawn_celestial_bodies(bodies_data: Array):
	for body_data in bodies_data:
		var celestial_body = preload("res://scenes/CelestialBody.tscn").instantiate()
		celestial_body.celestial_data = body_data
		celestial_body.position = Vector2(body_data.position.x, body_data.position.y)
		
		# Apply scale if specified for procedural planets
		if body_data.has("scale") and body_data.get("type") == "planet":
			celestial_body.scale = Vector2(body_data.scale, body_data.scale)
		
		celestial_bodies_container.add_child(celestial_body)

func pause_all_planet_animations():
	"""Pause animations on all planets (performance optimization when leaving system)"""
	for child in celestial_bodies_container.get_children():
		if child.has_method("pause_animations"):
			child.pause_animations()

func resume_all_planet_animations():
	"""Resume animations on all planets (when entering system)"""
	for child in celestial_bodies_container.get_children():
		if child.has_method("resume_animations"):
			child.resume_animations()

# Called when the system becomes active (e.g., after hyperspace)
func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		# Resume animations when system becomes visible
		call_deferred("resume_all_planet_animations")
