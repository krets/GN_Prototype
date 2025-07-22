# =============================================================================
# TRAFFIC MANAGER - Spawns and manages NPC ships based on system data
# =============================================================================
# TrafficManager.gd
extends Node2D
class_name TrafficManager

@export var spawn_distance: float = 4000.0  # Distance from center to spawn NPCs
@export var debug_mode: bool = false

var current_npcs: Array[NPCShip] = []
var spawn_timer: float = 0.0
var system_traffic_config: Dictionary = {}
var active: bool = false

# Default traffic configuration
var default_config = {
	"spawn_frequency": 15.0,      # Seconds between spawns
	"max_npcs": 3,               # Maximum NPCs in system
	"spawn_frequency_variance": 5.0,  # Random variance in spawn timing
	"npc_config": {
		"thrust_power": 500.0,
		"rotation_speed": 3.0,
		"max_velocity": 400.0,
		"visit_duration_range": [3.0, 8.0]
	}
}

func _ready():
	add_to_group("traffic_manager")
	
	# Connect to system changes
	UniverseManager.system_changed.connect(_on_system_changed)
	
	# Initialize with current system
	_on_system_changed(UniverseManager.current_system_id)

func _process(delta):
	if not active:
		return
	
	update_spawn_timer(delta)
	cleanup_distant_npcs()
	
	if debug_mode:
		queue_redraw()

func update_spawn_timer(delta):
	"""Handle NPC spawning timing"""
	spawn_timer -= delta
	
	if spawn_timer <= 0.0 and should_spawn_npc():
		spawn_npc()
		reset_spawn_timer()

func should_spawn_npc() -> bool:
	"""Check if we should spawn a new NPC"""
	var max_npcs = system_traffic_config.get("max_npcs", default_config.max_npcs)
	var current_count = get_active_npc_count()
	
	return current_count < max_npcs

func get_active_npc_count() -> int:
	"""Get count of active NPCs, cleaning up invalid ones"""
	current_npcs = current_npcs.filter(func(npc): return is_instance_valid(npc))
	return current_npcs.size()

func spawn_npc():
	"""Spawn a new NPC ship from hyperspace"""
	var npc_ship = create_npc_ship()
	if not npc_ship:
		return
	
	# Calculate spawn position (coming from a connected system)
	var spawn_data = calculate_hyperspace_entry()
	
	# Add to scene
	get_parent().add_child(npc_ship)
	current_npcs.append(npc_ship)
	
	# Initialize hyperspace entry
	npc_ship.start_hyperspace_entry(spawn_data.position, spawn_data.velocity, spawn_data.origin_system)
	
	if debug_mode:
		print("TrafficManager: Spawned NPC at ", spawn_data.position, " from ", spawn_data.origin_system)

func create_npc_ship() -> NPCShip:
	"""Create and configure a new NPC ship"""
	var npc_scene = preload("res://scenes/NPCShip.tscn")
	if not npc_scene:
		push_error("Could not load NPCShip.tscn")
		return null
	
	var npc_ship = npc_scene.instantiate()
	
	# Configure with system settings
	var npc_config = system_traffic_config.get("npc_config", default_config.npc_config)
	npc_ship.configure_npc(npc_config)
	
	return npc_ship

func calculate_hyperspace_entry() -> Dictionary:
	"""Calculate where and how an NPC should enter from hyperspace"""
	var system_center = Vector2.ZERO
	
	# Choose origin system from connections
	var current_system = UniverseManager.get_current_system()
	var connections = current_system.get("connections", [])
	var origin_system = ""
	
	if connections.size() > 0:
		origin_system = connections[randi() % connections.size()]
	
	# Get direction from origin system
	var entry_direction = get_entry_direction_from_system(origin_system)
	
	# Calculate spawn position
	var spawn_position = system_center + entry_direction * spawn_distance
	
	# Calculate entry velocity (coming toward system center)
	var entry_velocity = -entry_direction * randf_range(800.0, 1200.0)
	
	return {
		"position": spawn_position,
		"velocity": entry_velocity,
		"origin_system": origin_system
	}

func get_entry_direction_from_system(origin_system: String) -> Vector2:
	"""Get the direction an NPC should come from based on origin system"""
	if origin_system == "":
		# Random direction if no origin
		return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# Use hyperspace map positions to get realistic entry direction
	var system_positions = get_system_positions()
	var current_system_id = UniverseManager.current_system_id
	
	if current_system_id in system_positions and origin_system in system_positions:
		var current_pos = system_positions[current_system_id]
		var origin_pos = system_positions[origin_system]
		# Direction FROM origin TO current (so NPC comes from origin direction)
		return (current_pos - origin_pos).normalized()
	
	# Fallback to random direction
	return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func get_system_positions() -> Dictionary:
	"""Get system positions (same as player ship and hyperspace map)"""
	var map_width = 480
	var map_height = 500
	var margin = 50
	
	return {
		"sol_system": Vector2(margin + map_width * 0.3, margin + map_height * 0.5),
		"alpha_centauri": Vector2(margin + map_width * 0.45, margin + map_height * 0.4),
		"vega_system": Vector2(margin + map_width * 0.2, margin + map_height * 0.3),
		"sirius_system": Vector2(margin + map_width * 0.6, margin + map_height * 0.3),
		"rigel_system": Vector2(margin + map_width * 0.7, margin + map_height * 0.6),
		"arcturus_system": Vector2(margin + map_width * 0.1, margin + map_height * 0.7),
		"deneb_system": Vector2(margin + map_width * 0.4, margin + map_height * 0.8),
		"aldebaran_system": Vector2(margin + map_width * 0.8, margin + map_height * 0.4),
		"antares_system": Vector2(margin + map_width * 0.6, margin + map_height * 0.7),
		"capella_system": Vector2(margin + map_width * 0.2, margin + map_height * 0.6)
	}

func reset_spawn_timer():
	"""Reset the spawn timer with variance"""
	var base_frequency = system_traffic_config.get("spawn_frequency", default_config.spawn_frequency)
	var variance = system_traffic_config.get("spawn_frequency_variance", default_config.spawn_frequency_variance)
	
	var random_offset = randf_range(-variance, variance)
	spawn_timer = max(1.0, base_frequency + random_offset)  # Minimum 1 second between spawns
	
	if debug_mode:
		print("TrafficManager: Next spawn in ", spawn_timer, " seconds")

func cleanup_distant_npcs():
	"""Remove NPCs that have traveled too far from the system"""
	var system_center = Vector2.ZERO
	var cleanup_distance = spawn_distance * 1.5  # Give extra room before cleanup
	
	for i in range(current_npcs.size() - 1, -1, -1):
		var npc = current_npcs[i]
		if not is_instance_valid(npc):
			current_npcs.remove_at(i)
			continue
		
		var distance_from_center = npc.global_position.distance_to(system_center)
		if distance_from_center > cleanup_distance:
			if debug_mode:
				print("TrafficManager: Cleaning up distant NPC at distance ", distance_from_center)
			npc.cleanup_and_remove()
			current_npcs.remove_at(i)

func _on_system_changed(system_id: String):
	"""Handle system changes"""
	# Clear existing NPCs
	cleanup_all_npcs()
	
	# Load new system configuration
	load_system_traffic_config(system_id)
	
	# Activate traffic for new system
	active = true
	
	# Reset spawn timer for new system
	reset_spawn_timer()
	
	if debug_mode:
		print("TrafficManager: System changed to ", system_id, " - Config: ", system_traffic_config)

func load_system_traffic_config(system_id: String):
	"""Load traffic configuration for the specified system"""
	var system_data = UniverseManager.get_current_system()
	system_traffic_config = system_data.get("traffic", {})
	
	# Merge with defaults
	for key in default_config:
		if not system_traffic_config.has(key):
			system_traffic_config[key] = default_config[key]
	
	# Merge NPC config specifically
	if system_traffic_config.has("npc_config") and default_config.has("npc_config"):
		var merged_npc_config = default_config.npc_config.duplicate()
		for key in system_traffic_config.npc_config:
			merged_npc_config[key] = system_traffic_config.npc_config[key]
		system_traffic_config.npc_config = merged_npc_config
	elif not system_traffic_config.has("npc_config"):
		system_traffic_config.npc_config = default_config.npc_config

func cleanup_all_npcs():
	"""Remove all current NPCs (used when changing systems)"""
	for npc in current_npcs:
		if is_instance_valid(npc):
			npc.cleanup_and_remove()
	current_npcs.clear()

func _on_npc_removed(npc: NPCShip):
	"""Called by NPCs when they remove themselves"""
	current_npcs.erase(npc)
	if debug_mode:
		print("TrafficManager: NPC removed, ", current_npcs.size(), " remaining")

func set_debug_mode(enabled: bool):
	"""Enable/disable debug mode"""
	debug_mode = enabled
	queue_redraw()

func _draw():
	"""Debug visualization"""
	if not debug_mode:
		return
	
	var system_center = Vector2.ZERO
	
	# Draw spawn circle
	draw_arc(system_center, spawn_distance, 0, TAU, 64, Color.GREEN, 3.0)
	
	# Draw cleanup circle
	var cleanup_distance = spawn_distance * 1.5
	draw_arc(system_center, cleanup_distance, 0, TAU, 64, Color.RED, 2.0)
	
	# Draw NPC positions and states
	var font = ThemeDB.fallback_font
	for i in range(current_npcs.size()):
		var npc = current_npcs[i]
		if not is_instance_valid(npc):
			continue
		
		var local_pos = to_local(npc.global_position)
		draw_circle(local_pos, 8.0, Color.YELLOW)
		
		# Draw NPC info
		var npc_info = "NPC " + str(i) + "\n" + NPCShip.AIState.keys()[npc.current_ai_state]
		draw_string(font, local_pos + Vector2(10, 0), npc_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	
	# Draw spawn timer info
	var timer_info = "Spawn in: " + str(round(spawn_timer * 10) / 10.0) + "s\nNPCs: " + str(current_npcs.size()) + "/" + str(system_traffic_config.get("max_npcs", 0))
	draw_string(font, Vector2(-200, -200), timer_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.CYAN)
