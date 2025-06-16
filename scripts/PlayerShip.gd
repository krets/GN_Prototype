# =============================================================================
# PLAYER SHIP - Main player controller
# =============================================================================
# PlayerShip.gd
extends RigidBody2D
class_name PlayerShip

@export var thrust_power: float = 500.0
@export var rotation_speed: float = 3.0
@export var max_velocity: float = 400.0

@onready var sprite = $Sprite2D
@onready var engine_particles = $EngineParticles
@onready var interaction_area = $InteractionArea

var current_target: Node = null

func _ready():
	UniverseManager.player_ship = self
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	interaction_area.body_exited.connect(_on_interaction_area_exited)

func _integrate_forces(state):
	handle_input(state)
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

func limit_velocity(state):
	if state.linear_velocity.length() > max_velocity:
		state.linear_velocity = state.linear_velocity.normalized() * max_velocity

func _input(event):
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
