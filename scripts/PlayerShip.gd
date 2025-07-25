# =============================================================================
# PLAYER SHIP - Main player controller with hyperspace sequence
# =============================================================================
# PlayerShip.gd
extends RigidBody2D
class_name PlayerShip

@export var thrust_power: float = 500.0
@export var rotation_speed: float = 3.0
@export var max_velocity: float = 400.0
@export var hyperspace_thrust_power: float = 1500.0
@export var hyperspace_entry_speed: float = 800.0

@onready var sprite = $Sprite2D
@onready var engine_particles = $EngineParticles
@onready var interaction_area = $InteractionArea
@onready var camera = $Camera2D

var current_target: Node = null
var flash_overlay: ColorRect

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
var rotation_timer: float = 0.0
var deceleration_timer: float = 0.0
var entry_position: Vector2 = Vector2.ZERO
var entry_target: Vector2 = Vector2.ZERO
var jump_direction: Vector2 = Vector2.ZERO
var map_direction: Vector2 = Vector2.ZERO  # Store the direction from the map

func _ready():
	UniverseManager.player_ship = self
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	interaction_area.body_exited.connect(_on_interaction_area_exited)
	
	# Create flash overlay for hyperspace effect
	create_flash_overlay()

func _integrate_forces(state):
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
	
	# Force camera to stay locked during hyperspace
	if camera:
		camera.global_position = global_position
	
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
	"""Phase 1: Automatically decelerate to a stop"""
	deceleration_timer += get_physics_process_delta_time()
	
	var velocity = state.linear_velocity
	var speed = velocity.length()
	
	# If already stopped or nearly stopped, skip to rotation
	if speed <= 20.0 or deceleration_timer < 0.1:  # Check on first frame
		if speed <= 20.0:
			print("Already stopped (speed: ", speed, "), moving to rotation phase")
			state.linear_velocity = Vector2.ZERO  # Full stop
			engine_particles.emitting = false
			hyperspace_phase = HyperspacePhase.ROTATION
			rotation_timer = 0.0
			calculate_target_rotation()
			return
	
	# Timeout check
	if deceleration_timer > 3.0:
		print("Deceleration timeout, forcing stop")
		state.linear_velocity = Vector2.ZERO
		engine_particles.emitting = false
		hyperspace_phase = HyperspacePhase.ROTATION
		rotation_timer = 0.0
		calculate_target_rotation()
		return
	
	# Apply reverse thrust to slow down
	var reverse_direction = -velocity.normalized()
	var decel_force = reverse_direction * thrust_power * 2.0
	state.apply_central_force(decel_force)
	engine_particles.emitting = true
	
	print("Decelerating... Speed: ", speed)

func handle_rotation_phase(state):
	"""Phase 2: Rotate to face the destination system"""
	rotation_timer += get_physics_process_delta_time()
	
	var angle_diff = angle_difference(rotation, target_rotation)
	var rotation_threshold = 0.1  # About 6 degrees
	
	# Timeout check
	if rotation_timer > 1.0:
		print("Rotation timeout - continuing to acceleration")
		state.angular_velocity = 0.0
		hyperspace_phase = HyperspacePhase.ACCELERATION
		acceleration_timer = 0.0
		return
	
	if abs(angle_diff) > rotation_threshold:
		# Smooth rotation with damping
		var turn_speed = rotation_speed * 1.5
		var desired_angular_velocity = sign(angle_diff) * -turn_speed
		
		# Add damping as we get closer
		var damping_factor = min(abs(angle_diff) / 0.5, 1.0)
		state.angular_velocity = desired_angular_velocity * damping_factor
		
		print("Rotating... Angle diff: ", rad_to_deg(angle_diff), " degrees")
	else:
		# Rotation complete
		print("Rotation complete, starting acceleration")
		state.angular_velocity = 0.0
		rotation = target_rotation  # Snap to exact angle
		hyperspace_phase = HyperspacePhase.ACCELERATION
		acceleration_timer = 0.0

func handle_acceleration_phase(state):
	"""Phase 3: Dramatically accelerate toward destination"""
	acceleration_timer += get_physics_process_delta_time()
	
	# Apply massive forward thrust
	var thrust_vector = Vector2(0, -hyperspace_thrust_power).rotated(rotation)
	state.apply_central_force(thrust_vector)
	engine_particles.emitting = true
	
	var current_speed = state.linear_velocity.length()
	
	# Save actual travel direction
	if current_speed > 100.0:
		jump_direction = state.linear_velocity.normalized()
	
	print("Accelerating... Speed: ", current_speed)
	
	# After 3 seconds or high speed, trigger flash
	if acceleration_timer >= 3.5 or current_speed >= hyperspace_entry_speed * 4:
		print("Acceleration complete, flash time!")
		hyperspace_phase = HyperspacePhase.FLASH
		flash_timer = 0.0

func handle_flash_phase(state):
	"""Phase 4: Flash effect and system transition"""
	flash_timer += get_physics_process_delta_time()
	
	if flash_timer < 0.3:
		# Show white flash
		if flash_overlay:
			var alpha = sin(flash_timer * PI / 0.3)  # Fade in/out
			flash_overlay.color = Color(1, 1, 1, alpha)
			flash_overlay.visible = true
	else:
		# Flash complete, transition to new system
		print("Flash complete, transitioning to new system")
		if flash_overlay:
			flash_overlay.visible = false
		
		transition_to_new_system()
		hyperspace_phase = HyperspacePhase.ENTRY

func handle_entry_phase(state):
	"""Phase 5: Enter new system and decelerate"""
	var distance_to_target = global_position.distance_to(entry_target)
	var current_speed = state.linear_velocity.length()
	
	print("Entry phase - Speed: ", current_speed, " Distance: ", distance_to_target)
	
	# Complete when close enough or slow enough
	if distance_to_target < 800 or current_speed < max_velocity:
		print("Entry complete - returning control")
		engine_particles.emitting = false
		complete_hyperspace_sequence()
		return
	
	# Apply gentle deceleration
	if current_speed > max_velocity:
		var velocity_direction = state.linear_velocity.normalized()
		var decel_force = -velocity_direction * thrust_power * 1.2
		state.apply_central_force(decel_force)
		engine_particles.emitting = true

func transition_to_new_system():
	"""Handle the actual system change and ship positioning"""
	print("Transitioning to new system: ", hyperspace_destination)
	
	# Calculate entry position based on map direction
	var system_center = Vector2.ZERO
	var edge_distance = 3000.0
	
	# Use the stored map direction (reverse it to enter from opposite side)
	var entry_direction = -map_direction
	entry_position = system_center + entry_direction * edge_distance
	entry_target = system_center
	
	# Set velocity toward center
	linear_velocity = -entry_direction * hyperspace_entry_speed
	
	# Keep the ship's rotation
	print("Entry position: ", entry_position)
	print("Entry velocity: ", linear_velocity)
	print("Ship rotation: ", rad_to_deg(rotation), " degrees")
	
	# Force position update BEFORE changing system
	global_position = entry_position
	
	# Force camera to new position
	if camera:
		camera.global_position = global_position
		camera.reset_smoothing()  # This should reset any interpolation
	
	# Now change the system
	UniverseManager.change_system(hyperspace_destination)
	
	# Force another camera update after system change
	if camera:
		await get_tree().process_frame  # Wait one frame
		camera.global_position = global_position
		camera.force_update_scroll()

func calculate_target_rotation():
	"""Calculate which direction the ship should face based on map"""
	# Get the direction from hyperspace map
	var system_positions = get_system_positions()
	var current_system = UniverseManager.current_system_id
	
	if current_system in system_positions and hyperspace_destination in system_positions:
		var current_pos = system_positions[current_system]
		var target_pos = system_positions[hyperspace_destination]
		
		# Calculate direction to target
		map_direction = (target_pos - current_pos).normalized()
		
		# Convert to rotation (ship faces up by default, which is -Y direction)
		# So we need to subtract PI/2 instead of adding it
		target_rotation = map_direction.angle() - PI/2
		
		print("Direction to ", hyperspace_destination, ": ", map_direction)
		print("Target rotation: ", rad_to_deg(target_rotation), " degrees")
		print("Current rotation: ", rad_to_deg(rotation), " degrees")
	else:
		# Fallback
		target_rotation = 0.0
		map_direction = Vector2(0, -1)

func get_system_positions() -> Dictionary:
	"""Get the system positions used by the hyperspace map"""
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
	if hyperspace_state == HyperspaceState.HYPERSPACE_SEQUENCE:
		return
		
	if state.linear_velocity.length() > max_velocity:
		state.linear_velocity = state.linear_velocity.normalized() * max_velocity

func _input(event):
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

func start_hyperspace_sequence(destination_system: String):
	"""Begin the hyperspace jump sequence"""
	print("Starting hyperspace sequence to: ", destination_system)
	
	# Disable camera smoothing for the entire sequence
	if camera:
		camera.position_smoothing_enabled = false
		camera.global_position = global_position
	
	# Reset all state
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
	print("Hyperspace sequence complete")
	
	# Re-enable camera smoothing
	if camera:
		camera.position_smoothing_enabled = true
	
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
	map_direction = Vector2.ZERO

func create_flash_overlay():
	"""Create the white flash overlay for hyperspace effect"""
	# Create a CanvasLayer to ensure it renders above everything
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "FlashLayer"
	canvas_layer.layer = 10  # High layer to be above everything
	add_child(canvas_layer)
	
	# Create the flash overlay
	flash_overlay = ColorRect.new()
	flash_overlay.name = "FlashOverlay"
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.visible = false
	
	# Make it full screen
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add to canvas layer
	canvas_layer.add_child(flash_overlay)
	
	print("Flash overlay created in CanvasLayer")
