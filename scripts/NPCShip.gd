# =============================================================================
# NPC SHIP - Stage 1: Basic traffic AI with hyperspace mechanics
# =============================================================================
# NPCShip.gd
extends RigidBody2D
class_name NPCShip

@export var thrust_power: float = 500.0
@export var rotation_speed: float = 3.0
@export var max_velocity: float = 400.0
@export var hyperspace_thrust_power: float = 1500.0
@export var hyperspace_entry_speed: float = 800.0

@onready var sprite = $Sprite2D
@onready var engine_particles = $EngineParticles

# NPC Configuration (loaded from JSON or defaults)
var npc_config: Dictionary = {}
var ship_hue_shift: float = 0.0

# AI State Management
enum AIState {
	HYPERSPACE_ENTRY,    # Coming in from hyperspace
	FLYING_TO_TARGET,    # Moving toward a celestial body
	VISITING_BODY,       # Paused at a celestial body
	FLYING_TO_EXIT,      # Moving toward hyperspace exit
	HYPERSPACE_EXIT      # Leaving via hyperspace
}

enum HyperspacePhase {
	DECELERATION,
	ROTATION,
	ACCELERATION,
	FLASH,
	ENTRY
}

var current_ai_state: AIState = AIState.HYPERSPACE_ENTRY
var hyperspace_phase: HyperspacePhase = HyperspacePhase.DECELERATION
var target_celestial_body: Node2D = null
var target_position: Vector2 = Vector2.ZERO
var visit_timer: float = 0.0
var visit_duration: float = 5.0  # How long to pause at celestial bodies
var state_timer: float = 0.0
var hyperspace_timer: float = 0.0

# Hyperspace sequence variables (same as player)
var target_rotation: float = 0.0
var acceleration_timer: float = 0.0
var flash_timer: float = 0.0
var rotation_timer: float = 0.0
var deceleration_timer: float = 0.0
var jump_direction: Vector2 = Vector2.ZERO
var hyperspace_destination: String = ""

# Movement parameters
var arrival_distance: float = 100.0  # How close to get to targets
var turn_rate_modifier: float = 1.0
var thrust_modifier: float = 1.0

func _ready():
	# Add to NPC group for minimap detection
	add_to_group("npc_ships")
	
	# Set random hue shift for visual variety
	ship_hue_shift = randf() * 360.0
	apply_hue_shift()
	
	# Set initial random stats variation
	randomize_ship_stats()
	
	# Connect to system changes to clean up if needed
	UniverseManager.system_changed.connect(_on_system_changed)
	
	print("NPC Ship spawned with hue shift: ", ship_hue_shift, " visit duration: ", visit_duration)

func apply_hue_shift():
	"""Apply random hue shift to make ships visually distinct"""
	if sprite and sprite.texture:
		sprite.modulate = Color.WHITE
		# Create a hue-shifted tint
		var hue_color = Color.from_hsv(ship_hue_shift / 360.0, 0.6, 1.0)
		sprite.modulate = hue_color

func randomize_ship_stats():
	"""Add some variety to ship performance"""
	thrust_modifier = randf_range(0.6, 1.2)
	turn_rate_modifier = randf_range(0.6, 1.2)
	visit_duration = randf_range(4.0, 10.0)  # Increased visit duration
	
	# Apply modifiers
	thrust_power *= thrust_modifier
	rotation_speed *= turn_rate_modifier

func configure_npc(config: Dictionary):
	"""Configure NPC from JSON data"""
	npc_config = config
	
	# Override defaults with config values
	if config.has("thrust_power"):
		thrust_power = config.thrust_power
	if config.has("rotation_speed"):
		rotation_speed = config.rotation_speed
	if config.has("max_velocity"):
		max_velocity = config.max_velocity
	if config.has("visit_duration_range"):
		var duration_range = config.visit_duration_range
		visit_duration = randf_range(duration_range[0], duration_range[1])

func start_hyperspace_entry(entry_position: Vector2, entry_velocity: Vector2, destination_system: String = ""):
	"""Initialize NPC coming in from hyperspace"""
	global_position = entry_position
	linear_velocity = entry_velocity
	hyperspace_destination = destination_system
	current_ai_state = AIState.HYPERSPACE_ENTRY
	hyperspace_phase = HyperspacePhase.ENTRY
	
	print("NPC starting hyperspace entry at: ", entry_position)

func _integrate_forces(state):
	match current_ai_state:
		AIState.HYPERSPACE_ENTRY:
			handle_hyperspace_entry(state)
		AIState.FLYING_TO_TARGET:
			handle_flying_to_target(state)
		AIState.VISITING_BODY:
			handle_visiting_body(state)
		AIState.FLYING_TO_EXIT:
			handle_flying_to_exit(state)
		AIState.HYPERSPACE_EXIT:
			handle_hyperspace_exit(state)
	
	limit_velocity(state)

func handle_hyperspace_entry(state):
	"""Handle deceleration from hyperspace entry"""
	var current_speed = state.linear_velocity.length()
	state_timer += get_physics_process_delta_time()
	
	# Decelerate to normal speed
	if current_speed > max_velocity * 1.2:
		var decel_direction = -state.linear_velocity.normalized()
		var decel_force = decel_direction * thrust_power * 1.5
		state.apply_central_force(decel_force)
		engine_particles.emitting = true
	else:
		# Entry complete, choose a target
		engine_particles.emitting = false
		choose_target_celestial_body()
		transition_to_state(AIState.FLYING_TO_TARGET)

func handle_flying_to_target(state):
	"""Fly toward the chosen celestial body"""
	if not target_celestial_body:
		# No target, go to exit
		transition_to_state(AIState.FLYING_TO_EXIT)
		return
	
	var target_pos = target_celestial_body.global_position
	var distance_to_target = global_position.distance_to(target_pos)
	
	# Check if we've arrived
	if distance_to_target <= arrival_distance:
		transition_to_state(AIState.VISITING_BODY)
		return
	
	# Navigate toward target with deceleration
	navigate_to_position_with_decel(state, target_pos, arrival_distance)

func handle_visiting_body(state):
	"""Pause at the celestial body"""
	visit_timer += get_physics_process_delta_time()
	
	# Apply gentle braking to stay near the body
	if state.linear_velocity.length() > 20.0:  # Lower threshold for smoother stop
		var brake_force = -state.linear_velocity.normalized() * thrust_power * 0.3  # Gentler braking
		state.apply_central_force(brake_force)
		engine_particles.emitting = true
	else:
		engine_particles.emitting = false
	
	# Safety timeout - force exit if stuck too long
	if visit_timer >= visit_duration * 2.0:  # Double the intended duration as safety
		print("NPC visit timeout - forcing exit after ", visit_timer, " seconds")
		transition_to_state(AIState.FLYING_TO_EXIT)
		return
	
	# Normal visit completion
	if visit_timer >= visit_duration:
		print("NPC finished visiting after ", visit_timer, " seconds, heading to exit")
		transition_to_state(AIState.FLYING_TO_EXIT)

func handle_flying_to_exit(state):
	"""Fly away from system center toward hyperspace exit"""
	# Choose a random direction away from system center, but prefer actual connections
	var system_center = Vector2.ZERO
	var exit_direction = choose_hyperspace_exit_direction()
	var exit_distance = 3500.0
	target_position = system_center + exit_direction * exit_distance
	
	var distance_to_exit = global_position.distance_to(target_position)
	
	# Start hyperspace sequence when close to exit point
	if distance_to_exit <= 500.0:
		transition_to_state(AIState.HYPERSPACE_EXIT)
		return
	
	# Navigate toward exit point with gentler thrust
	navigate_to_position_relaxed(state, target_position)

func handle_hyperspace_exit(state):
	"""Handle hyperspace exit sequence (simplified version of player's)"""
	hyperspace_timer += get_physics_process_delta_time()
	
	match hyperspace_phase:
		HyperspacePhase.DECELERATION:
			handle_exit_deceleration(state)
		HyperspacePhase.ROTATION:
			handle_exit_rotation(state)
		HyperspacePhase.ACCELERATION:
			handle_exit_acceleration(state)
		HyperspacePhase.FLASH:
			handle_exit_flash(state)

func handle_exit_deceleration(state):
	"""Decelerate for hyperspace exit"""
	deceleration_timer += get_physics_process_delta_time()
	var current_speed = state.linear_velocity.length()
	
	if current_speed <= 50.0 or deceleration_timer > 2.0:
		state.linear_velocity = Vector2.ZERO
		engine_particles.emitting = false
		hyperspace_phase = HyperspacePhase.ROTATION
		rotation_timer = 0.0
		calculate_exit_rotation()
		return
	
	# Apply braking
	var brake_direction = -state.linear_velocity.normalized()
	state.apply_central_force(brake_direction * thrust_power * 1.5)
	engine_particles.emitting = true

func handle_exit_rotation(state):
	"""Rotate to face hyperspace exit direction"""
	rotation_timer += get_physics_process_delta_time()
	var angle_diff = angle_difference(rotation, target_rotation)
	
	if abs(angle_diff) > 0.1 and rotation_timer < 1.0:
		var turn_speed = rotation_speed * 2.0
		state.angular_velocity = sign(angle_diff) * -turn_speed
	else:
		state.angular_velocity = 0.0
		rotation = target_rotation
		hyperspace_phase = HyperspacePhase.ACCELERATION
		acceleration_timer = 0.0

func handle_exit_acceleration(state):
	"""Accelerate away for hyperspace exit"""
	acceleration_timer += get_physics_process_delta_time()
	
	# Apply massive thrust
	var thrust_vector = Vector2(0, -hyperspace_thrust_power).rotated(rotation)
	state.apply_central_force(thrust_vector)
	engine_particles.emitting = true
	
	var current_speed = state.linear_velocity.length()
	
	# After acceleration, trigger flash and removal
	if acceleration_timer >= 2.0 or current_speed >= hyperspace_entry_speed * 2:
		hyperspace_phase = HyperspacePhase.FLASH
		flash_timer = 0.0

func handle_exit_flash(state):
	"""Flash effect and cleanup"""
	flash_timer += get_physics_process_delta_time()
	
	# Continue accelerating
	var thrust_vector = Vector2(0, -hyperspace_thrust_power).rotated(rotation)
	state.apply_central_force(thrust_vector)
	
	if flash_timer >= 0.5:
		# NPC has left the system
		cleanup_and_remove()

func navigate_to_position_with_decel(state: PhysicsDirectBodyState2D, target_pos: Vector2, stop_distance: float):
	"""Navigate toward a target position with deceleration as we approach"""
	var direction_to_target = (target_pos - global_position).normalized()
	var distance_to_target = global_position.distance_to(target_pos)
	var current_speed = state.linear_velocity.length()
	
	# Calculate desired facing direction
	var desired_rotation = direction_to_target.angle() - PI/2
	var angle_diff = angle_difference(rotation, desired_rotation)
	
	# Smooth turning - only turn if the angle difference is significant
	if abs(angle_diff) > 0.2:  # Larger threshold to reduce jittery movement
		var turn_direction = sign(angle_diff) * -1
		var turn_speed = rotation_speed * 0.7  # Slower turning for smoothness
		state.angular_velocity = turn_direction * turn_speed
	else:
		# Gradually reduce angular velocity for smoother movement
		state.angular_velocity *= 0.8
	
	# Calculate if we need to decelerate
	var decel_distance = stop_distance * 3.0  # Start decelerating 3x the stop distance away
	var facing_direction = Vector2(0, -1).rotated(rotation)
	var dot_product = facing_direction.dot(direction_to_target)
	
	if dot_product > 0.3:  # Facing within ~70 degrees (more lenient)
		if distance_to_target > decel_distance:
			# Far away - normal thrust
			var thrust_vector = Vector2(0, -thrust_power * 0.8).rotated(rotation)  # Reduced thrust
			state.apply_central_force(thrust_vector)
			engine_particles.emitting = true
		elif distance_to_target > stop_distance:
			# Close - decelerate
			var decel_strength = (distance_to_target - stop_distance) / (decel_distance - stop_distance)
			decel_strength = clamp(decel_strength, 0.1, 1.0)
			
			# Apply forward or reverse thrust based on speed
			if current_speed > max_velocity * 0.3:  # If moving too fast, brake
				var brake_vector = -state.linear_velocity.normalized() * thrust_power * 0.6
				state.apply_central_force(brake_vector)
			else:
				# Gentle forward thrust
				var thrust_vector = Vector2(0, -thrust_power * decel_strength * 0.3).rotated(rotation)
				state.apply_central_force(thrust_vector)
			engine_particles.emitting = true
		else:
			# Very close - just brake
			if current_speed > 30.0:
				var brake_vector = -state.linear_velocity.normalized() * thrust_power * 0.4
				state.apply_central_force(brake_vector)
				engine_particles.emitting = true
			else:
				engine_particles.emitting = false
	else:
		engine_particles.emitting = false

func navigate_to_position_relaxed(state: PhysicsDirectBodyState2D, target_pos: Vector2):
	"""Navigate toward a target position with relaxed, less aggressive movement"""
	var direction_to_target = (target_pos - global_position).normalized()
	var distance_to_target = global_position.distance_to(target_pos)
	
	# Calculate desired facing direction
	var desired_rotation = direction_to_target.angle() - PI/2
	var angle_diff = angle_difference(rotation, desired_rotation)
	
	# Very smooth turning
	if abs(angle_diff) > 0.3:  # Even larger threshold
		var turn_direction = sign(angle_diff) * -1
		var turn_speed = rotation_speed * 0.5  # Even slower turning
		state.angular_velocity = turn_direction * turn_speed
	else:
		# Gradually reduce angular velocity
		state.angular_velocity *= 0.7
	
	# Thrust if facing roughly the right direction
	var facing_direction = Vector2(0, -1).rotated(rotation)
	var dot_product = facing_direction.dot(direction_to_target)
	
	if dot_product > 0.4:  # More lenient facing requirement
		# Gentle, consistent thrust
		var thrust_multiplier = 0.6  # Reduced thrust for relaxed flight
		
		var thrust_vector = Vector2(0, -thrust_power * thrust_multiplier).rotated(rotation)
		state.apply_central_force(thrust_vector)
		engine_particles.emitting = true
	else:
		engine_particles.emitting = false

func choose_target_celestial_body():
	"""Choose a random celestial body to visit"""
	var system_scene = get_tree().get_first_node_in_group("system_scene")
	if not system_scene:
		return
	
	var celestial_container = system_scene.get_node_or_null("CelestialBodies")
	if not celestial_container:
		return
	
	var available_bodies = []
	for child in celestial_container.get_children():
		if child != self and child.has_method("can_interact"):
			available_bodies.append(child)
	
	if available_bodies.size() > 0:
		target_celestial_body = available_bodies[randi() % available_bodies.size()]
		print("NPC chose target: ", target_celestial_body.celestial_data.get("name", "Unknown"))

func choose_hyperspace_exit_direction() -> Vector2:
	"""Choose direction for hyperspace exit, preferring actual system connections"""
	var current_system = UniverseManager.get_current_system()
	var connections = current_system.get("connections", [])
	
	if connections.size() > 0:
		# Choose a random connected system and get direction to it
		var target_system = connections[randi() % connections.size()]
		var system_positions = get_system_positions()
		var current_system_id = UniverseManager.current_system_id
		
		if current_system_id in system_positions and target_system in system_positions:
			var current_pos = system_positions[current_system_id]
			var target_pos = system_positions[target_system]
			return (target_pos - current_pos).normalized()
	
	# Fallback to random direction
	return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func get_system_positions() -> Dictionary:
	"""Get system positions from hyperspace map (same as player ship)"""
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

func calculate_exit_rotation():
	"""Calculate rotation for hyperspace exit"""
	var exit_direction = choose_hyperspace_exit_direction()
	target_rotation = exit_direction.angle() - PI/2

func angle_difference(current: float, target: float) -> float:
	"""Calculate the shortest angle difference between two angles"""
	var diff = target - current
	while diff > PI:
		diff -= 2 * PI
	while diff < -PI:
		diff += 2 * PI
	return diff

func transition_to_state(new_state: AIState):
	"""Transition to a new AI state"""
	print("NPC transitioning from ", AIState.keys()[current_ai_state], " to ", AIState.keys()[new_state])
	current_ai_state = new_state
	state_timer = 0.0
	visit_timer = 0.0
	
	# Reset hyperspace timers when entering hyperspace exit
	if new_state == AIState.HYPERSPACE_EXIT:
		hyperspace_timer = 0.0
		hyperspace_phase = HyperspacePhase.DECELERATION
		deceleration_timer = 0.0

func limit_velocity(state):
	"""Limit velocity to maximum (except during hyperspace)"""
	if current_ai_state == AIState.HYPERSPACE_EXIT and hyperspace_phase == HyperspacePhase.ACCELERATION:
		return  # Don't limit during hyperspace acceleration
	
	if state.linear_velocity.length() > max_velocity:
		state.linear_velocity = state.linear_velocity.normalized() * max_velocity

func cleanup_and_remove():
	"""Clean up and remove this NPC"""
	print("NPC completing hyperspace exit and removing")
	
	# Notify traffic manager that this NPC is leaving (with safety check)
	var tree = get_tree()
	if tree:
		var traffic_manager = tree.get_first_node_in_group("traffic_manager")
		if traffic_manager and traffic_manager.has_method("_on_npc_removed"):
			traffic_manager._on_npc_removed(self)
	
	queue_free()

func _on_system_changed(_system_id: String):
	"""Clean up if system changes while NPC exists"""
	# Use call_deferred to avoid tree access issues during system transitions
	call_deferred("queue_free")

# Debug visualization
func _draw():
	if not Engine.is_editor_hint() and not OS.is_debug_build():
		return
		
	# Only draw if traffic manager has debug mode enabled
	var traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	if not traffic_manager or not traffic_manager.debug_mode:
		return
	
	# Draw target line
	if target_celestial_body:
		var local_target = to_local(target_celestial_body.global_position)
		draw_line(Vector2.ZERO, local_target, Color.YELLOW, 2.0)
	elif target_position != Vector2.ZERO:
		var local_target = to_local(target_position)
		draw_line(Vector2.ZERO, local_target, Color.CYAN, 2.0)
	
	# Draw state text
	var font = ThemeDB.fallback_font
	var state_text = AIState.keys()[current_ai_state]
	draw_string(font, Vector2(0, -40), state_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)
