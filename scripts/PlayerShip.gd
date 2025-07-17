# =============================================================================
# PLAYER SHIP - Main player controller with hyperspace sequence
# =============================================================================
# PlayerShip.gd
extends RigidBody2D
class_name PlayerShip

@export var thrust_power: float = 500.0
@export var rotation_speed: float = 3.0
@export var max_velocity: float = 400.0
@export var hyperspace_thrust_power: float = 1500.0  # Much stronger thrust for hyperspace
@export var hyperspace_entry_speed: float = 800.0   # Speed when entering new system

@onready var sprite = $Sprite2D
@onready var engine_particles = $EngineParticles
@onready var interaction_area = $InteractionArea

var current_target: Node = null
var flash_overlay: ColorRect  # Created dynamically

# Hyperspace sequence states
enum HyperspaceState {
	NORMAL,
	HYPERSPACE_SEQUENCE
}

enum HyperspacePhase {
	DECELERATION,
	ROTATION,
	ACCELERATION,
	FLASH,
	ENTRY
}

var hyperspace_state: HyperspaceState = HyperspaceState.NORMAL
var hyperspace_phase: HyperspacePhase = HyperspacePhase.DECELERATION
var hyperspace_destination: String = ""
var hyperspace_timer: float = 0.0
var target_rotation: float = 0.0
var acceleration_timer: float = 0.0
var flash_timer: float = 0.0
var rotation_timer: float = 0.0  # Track rotation phase time
var deceleration_timer: float = 0.0  # Track deceleration phase time
var entry_position: Vector2 = Vector2.ZERO
var entry_target: Vector2 = Vector2.ZERO
var jump_direction: Vector2 = Vector2.ZERO  # Direction ship was traveling during jump

func _ready():
	UniverseManager.player_ship = self
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	interaction_area.body_exited.connect(_on_interaction_area_exited)
	
	# Create flash overlay for hyperspace effect
	create_flash_overlay()

func _integrate_forces(state):
	# Only handle normal input if not in hyperspace sequence
	if hyperspace_state == HyperspaceState.NORMAL:
		handle_input(state)
	else:
		handle_hyperspace_sequence(state)
	
	limit_velocity(state)

func handle_input(state):
	# Rotation
	var rotation_input = Input.get_axis("turn_left", "turn_right")
	state.angular_velocity = rotation_input * rotation_speed
	
	# Thrust
	if Input.is_action_pressed("thrust"):
		var thrust_vector = Vector2(0, -thrust_power).rotated(rotation)
		state.apply_central_force(thrust_vector)
		engine_particles.emitting = true
	else:
		engine_particles.emitting = false

func handle_hyperspace_sequence(state):
	"""Handle ship behavior during hyperspace sequence"""
	hyperspace_timer += get_physics_process_delta_time()
	
	match hyperspace_phase:
		HyperspacePhase.DECELERATION:
			handle_deceleration_phase(state)
		HyperspacePhase.ROTATION:
			handle_rotation_phase(state)
		HyperspacePhase.ACCELERATION:
			handle_acceleration_phase(state)
		HyperspacePhase.FLASH:
			handle_flash_phase(state)
		HyperspacePhase.ENTRY:
			handle_entry_phase(state)

func handle_deceleration_phase(state):
	"""Phase 1: Automatically decelerate to a stop - SIMPLIFIED"""
	deceleration_timer += get_physics_process_delta_time()
	
	var velocity = state.linear_velocity
	var speed = velocity.length()
	
	# Much more aggressive timeout and threshold
	if deceleration_timer > 2.0 or speed <= 15.0:
		# We've stopped, move to rotation phase
		print("Deceleration done (speed: ", speed, ", time: ", deceleration_timer, ")")
		engine_particles.emitting = false
		
		# OPTION: Skip rotation entirely if it keeps causing problems
		# Uncomment these lines and comment out the rotation lines below:
		# hyperspace_phase = HyperspacePhase.ACCELERATION
		# acceleration_timer = 0.0
		# return
		
		hyperspace_phase = HyperspacePhase.ROTATION
		rotation_timer = 0.0
		calculate_target_rotation()
		return
	
	# Apply reverse thrust to slow down
	if speed > 0.1:  # Avoid division by zero
		var reverse_direction = -velocity.normalized()
		var decel_force = reverse_direction * thrust_power * 2.0  # Stronger deceleration
		state.apply_central_force(decel_force)
		engine_particles.emitting = true
	
	print("Decelerating... Speed: ", speed)

func handle_rotation_phase(state):
	"""Phase 2: Rotate to face the destination system"""
	rotation_timer += get_physics_process_delta_time()
	
	var angle_diff = angle_difference(rotation, target_rotation)
	var rotation_threshold = 0.5  # Much more forgiving - about 30 degrees
	
	# Safety timeout - if rotation takes too long, just move on
	if rotation_timer > 3.0:
		print("Rotation timeout - continuing to acceleration")
		state.angular_velocity = 0.0
		hyperspace_phase = HyperspacePhase.ACCELERATION
		acceleration_timer = 0.0
		return
	
	if abs(angle_diff) > rotation_threshold:
		# Simple rotation - just turn toward target
		var turn_speed = rotation_speed * 1.2
		var desired_angular_velocity = sign(angle_diff) * -turn_speed
		state.angular_velocity = desired_angular_velocity
		
		print("Rotating... Remaining: ", rad_to_deg(abs(angle_diff)), " degrees")
	else:
		# Close enough! Move to acceleration phase
		print("Rotation close enough, starting acceleration")
		state.angular_velocity = 0.0
		hyperspace_phase = HyperspacePhase.ACCELERATION
		acceleration_timer = 0.0

func handle_acceleration_phase(state):
	"""Phase 3: Dramatically accelerate toward destination - SIMPLIFIED"""
	acceleration_timer += get_physics_process_delta_time()
	
	# Apply massive forward thrust
	var thrust_vector = Vector2(0, -hyperspace_thrust_power).rotated(rotation)
	state.apply_central_force(thrust_vector)
	engine_particles.emitting = true
	
	var current_speed = state.linear_velocity.length()
	
	# Make sure we save the direction we're actually traveling
	if current_speed > 100.0:  # Only save direction when moving fast enough
		jump_direction = state.linear_velocity.normalized()
	
	print("Accelerating... Speed: ", current_speed, " Direction: ", jump_direction)
	
	# After 4 seconds or high speed, trigger flash
	if acceleration_timer >= 4.0 or current_speed >= hyperspace_entry_speed * 1.5:
		print("Acceleration complete, flash time!")
		hyperspace_phase = HyperspacePhase.FLASH
		flash_timer = 0.0

func handle_flash_phase(state):
	"""Phase 4: Flash effect and system transition"""
	flash_timer += get_physics_process_delta_time()
	
	print("Flash phase... Timer: ", flash_timer)
	
	if flash_timer < 0.5:  # Extended flash duration
		# Show white flash
		if flash_overlay:
			flash_overlay.color = Color(1, 1, 1, 1)  # Full white, full opacity
			flash_overlay.visible = true
			print("Flash overlay active")
		else:
			print("ERROR: Flash overlay is null!")
	else:
		# Flash complete, transition to new system
		print("Flash complete, transitioning to new system")
		if flash_overlay:
			flash_overlay.visible = false
		
		# Change system and position ship at edge
		transition_to_new_system()
		hyperspace_phase = HyperspacePhase.ENTRY

func handle_entry_phase(state):
	"""Phase 5: Enter new system and decelerate - SIMPLIFIED"""
	var distance_to_target = global_position.distance_to(entry_target)
	var current_speed = state.linear_velocity.length()
	
	print("Entry phase - Speed: ", current_speed, " Distance to center: ", distance_to_target)
	
	# Simple deceleration when getting close to center
	if distance_to_target < 1200 or current_speed < max_velocity * 1.5:
		print("Entry deceleration complete - returning control to player")
		engine_particles.emitting = false
		complete_hyperspace_sequence()
		return
	
	# Apply gentle deceleration
	if current_speed > max_velocity:
		var velocity_direction = state.linear_velocity.normalized()
		var decel_force = -velocity_direction * thrust_power * 1.5
		state.apply_central_force(decel_force)
		engine_particles.emitting = true

func transition_to_new_system():
	"""Handle the actual system change and ship positioning - SIMPLIFIED"""
	print("Transitioning to new system...")
	
	# Change the system first
	UniverseManager.change_system(hyperspace_destination)
	
	# Simple positioning: enter from edge in the direction we were traveling
	var system_center = Vector2.ZERO
	var edge_distance = 2000.0
	
	# Use the saved direction from the map calculation
	var travel_direction = jump_direction
	if travel_direction.length() == 0:
		travel_direction = Vector2(0, -1)  # Default upward
	
	# Position ship at edge, opposite to where we want to go
	entry_position = system_center - travel_direction * edge_distance
	global_position = entry_position
	
	# Set velocity toward center
	linear_velocity = travel_direction * hyperspace_entry_speed
	
	# Keep the ship's current rotation - don't change it!
	# The ship should maintain the angle it had when accelerating
	print("Keeping current ship rotation: ", rad_to_deg(rotation), " degrees")
	
	# Force camera to follow ship immediately
	var camera = get_node("Camera2D")
	if camera:
		camera.global_position = global_position
		camera.force_update_scroll()
	
	print("Ship positioned at: ", entry_position)
	print("Moving toward center with velocity: ", linear_velocity)
	print("Ship rotation unchanged: ", rad_to_deg(rotation), " degrees")
	
	entry_target = system_center

func calculate_target_rotation():
	"""Calculate which direction the ship should face - SIMPLIFIED"""
	# Get system positions from the hyperspace map
	var current_system = UniverseManager.current_system_id
	var system_positions = get_system_positions()
	
	if current_system in system_positions and hyperspace_destination in system_positions:
		var current_pos = system_positions[current_system]
		var target_pos = system_positions[hyperspace_destination]
		
		# Simple direction calculation
		var direction = (target_pos - current_pos).normalized()
		
		# Save this direction for later use
		jump_direction = direction
		
		# Simple angle conversion - ship sprite faces up (negative Y)
		target_rotation = direction.angle() + PI/2
		
		print("Simple direction to ", hyperspace_destination, ": ", direction)
		print("Target rotation: ", rad_to_deg(target_rotation), " degrees")
	else:
		# Just face up as fallback
		target_rotation = 0.0
		jump_direction = Vector2(0, -1)
		print("Using fallback direction: up")

func get_system_positions() -> Dictionary:
	"""Get the system positions used by the hyperspace map"""
	# This recreates the same positions used in HyperspaceMap
	# TODO: Later we might want to centralize this in UniverseManager
	var viewport_size = get_viewport().size
	var map_width = 800 - 100 - 320  # Match HyperspaceMap calculations
	var map_height = 600 - 100
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

func angle_difference(current: float, target: float) -> float:
	"""Calculate the shortest angle difference between two angles"""
	var diff = target - current
	# Normalize to [-PI, PI]
	while diff > PI:
		diff -= 2 * PI
	while diff < -PI:
		diff += 2 * PI
	return diff

func limit_velocity(state):
	# Don't limit velocity during hyperspace sequence
	if hyperspace_state == HyperspaceState.HYPERSPACE_SEQUENCE:
		return
		
	if state.linear_velocity.length() > max_velocity:
		state.linear_velocity = state.linear_velocity.normalized() * max_velocity

func _input(event):
	# Only respond to input if not in hyperspace sequence
	if hyperspace_state != HyperspaceState.NORMAL:
		return
		
	if event.is_action_pressed("interact") and current_target:
		interact_with_target()
	elif event.is_action_pressed("hyperspace"):
		open_hyperspace_menu()

func interact_with_target():
	if current_target.has_method("interact"):
		current_target.interact()

func open_hyperspace_menu():
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("show_hyperspace_menu"):
		ui.show_hyperspace_menu()

func _on_interaction_area_entered(body):
	if body.has_method("can_interact") and body.can_interact():
		current_target = body
		print("Can interact with: ", body.celestial_data.name)

func _on_interaction_area_exited(body):
	if body == current_target:
		current_target = null

# =============================================================================
# HYPERSPACE SEQUENCE METHODS
# =============================================================================

func start_hyperspace_sequence(destination_system: String):
	"""Begin the hyperspace jump sequence"""
	print("Starting hyperspace sequence to: ", destination_system)
	
	hyperspace_state = HyperspaceState.HYPERSPACE_SEQUENCE
	hyperspace_phase = HyperspacePhase.DECELERATION
	hyperspace_destination = destination_system
	hyperspace_timer = 0.0
	target_rotation = 0.0
	acceleration_timer = 0.0
	flash_timer = 0.0
	rotation_timer = 0.0
	deceleration_timer = 0.0
	entry_position = Vector2.ZERO
	entry_target = Vector2.ZERO
	jump_direction = Vector2.ZERO
	
	print("Phase 1: Beginning deceleration")

func complete_hyperspace_sequence():
	"""Complete the hyperspace sequence and return control to player"""
	print("Hyperspace sequence complete - control returned to player")
	
	# Reset to normal state
	hyperspace_state = HyperspaceState.NORMAL
	hyperspace_phase = HyperspacePhase.DECELERATION
	hyperspace_destination = ""
	hyperspace_timer = 0.0
	target_rotation = 0.0
	acceleration_timer = 0.0
	flash_timer = 0.0
	rotation_timer = 0.0
	deceleration_timer = 0.0
	entry_position = Vector2.ZERO
	entry_target = Vector2.ZERO
	jump_direction = Vector2.ZERO

func create_flash_overlay():
	"""Create the white flash overlay for hyperspace effect"""
	# Wait a frame to ensure scene is ready
	await get_tree().process_frame
	
	var flash = ColorRect.new()
	flash.name = "FlashOverlay"
	flash.color = Color(1, 1, 1, 0)  # White, transparent initially
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.visible = false
	flash.z_index = 1000  # Very high Z to appear above everything
	
	# Make it full screen
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add to the UI layer instead of root to ensure it's visible
	var main_scene = get_tree().get_first_node_in_group("ui")
	if main_scene:
		main_scene.add_child(flash)
		flash_overlay = flash
		print("Flash overlay created and added to UI")
	else:
		# Fallback to root
		get_tree().root.add_child(flash)
		flash_overlay = flash
		print("Flash overlay created and added to root")
