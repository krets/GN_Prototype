# =============================================================================
# PLANET ANIMATOR - Handles procedural parameter animations for planets
# =============================================================================
# PlanetAnimator.gd
extends Node
class_name PlanetAnimator

# Animation data structure for a single parameter
class ParameterAnimation:
	var parameter_name: String
	var animation_type: String = "linear"  # linear, sine, cosine, pulse, circular
	var rate: float = 1.0                 # Speed multiplier
	var amplitude: float = 1.0            # For oscillating animations
	var offset_x: float = 0.0             # For circular animations (X component)
	var offset_y: float = 0.0             # For circular animations (Y component)
	var base_value                        # Starting value from library (any type)
	var current_time: float = 0.0         # Internal timer
	var random_start_offset: float = 0.0  # Random offset so planets aren't synchronized
	
	func _init(param_name: String, base_val, anim_data: Dictionary):
		parameter_name = param_name
		base_value = base_val
		
		# Parse animation configuration
		rate = anim_data.get("rate", 1.0)
		animation_type = anim_data.get("type", "linear")
		amplitude = anim_data.get("amplitude", 1.0)
		offset_x = anim_data.get("offset_x", 0.0)  # For circular animations
		offset_y = anim_data.get("offset_y", 0.0)
		
		# Random start offset to desynchronize planets
		random_start_offset = randf() * TAU
		
		print("Created animation for ", parameter_name, " - Type: ", animation_type, " Rate: ", rate)

var target_material: ShaderMaterial
var animations: Array[ParameterAnimation] = []
var is_active: bool = false

func _ready():
	set_process(false)  # Start inactive

func setup_animations(material: ShaderMaterial, animation_data: Dictionary):
	"""Initialize animations from JSON configuration"""
	target_material = material
	animations.clear()
	
	if animation_data.is_empty():
		return
	
	# Create animation objects for each parameter
	for param_name in animation_data:
		var anim_config = animation_data[param_name]
		
		# Get the base value from the current material
		var base_value = material.get_shader_parameter(param_name)
		if base_value == null:
			push_warning("Parameter '" + param_name + "' not found in material for animation")
			continue
		
		# Create animation
		var param_anim = ParameterAnimation.new(param_name, base_value, anim_config)
		animations.append(param_anim)
	
	if animations.size() > 0:
		print("Setup ", animations.size(), " parameter animations")
		start_animations()

func start_animations():
	"""Start the animation system"""
	is_active = true
	set_process(true)

func stop_animations():
	"""Stop the animation system"""
	is_active = false
	set_process(false)

func _process(delta):
	if not is_active or not target_material or animations.is_empty():
		return
	
	# Update all parameter animations
	for anim in animations:
		update_parameter_animation(anim, delta)

func update_parameter_animation(anim: ParameterAnimation, delta: float):
	"""Update a single parameter animation"""
	anim.current_time += delta
	var total_time = anim.current_time + anim.random_start_offset
	
	var new_value
	
	# Calculate new value based on animation type
	match anim.animation_type:
		"linear":
			new_value = calculate_linear_animation(anim, total_time)
		
		"sine":
			new_value = calculate_sine_animation(anim, total_time)
		
		"cosine":
			new_value = calculate_cosine_animation(anim, total_time)
		
		"pulse":
			new_value = calculate_pulse_animation(anim, total_time)
		
		"circular":
			new_value = calculate_circular_animation(anim, total_time)
		
		_:
			push_warning("Unknown animation type: " + anim.animation_type)
			new_value = anim.base_value
	
	# Apply the new value to the material
	target_material.set_shader_parameter(anim.parameter_name, new_value)

func calculate_linear_animation(anim: ParameterAnimation, time: float):
	"""Linear motion: value = base + rate * time"""
	if anim.base_value is float:
		return anim.base_value + (anim.rate * time)
	elif anim.base_value is Vector2:
		return Vector2(
			anim.base_value.x + (anim.rate * time),
			anim.base_value.y + (anim.offset_x * time)  # Use offset_x for Y component rate
		)
	elif anim.base_value is Color:
		# Animate hue for colors
		var hsv = anim.base_value.to_hsv()
		hsv.r = fmod(hsv.r + (anim.rate * time * 0.1), 1.0)  # Slow hue rotation
		return Color.from_hsv(hsv.r, hsv.g, hsv.b, hsv.a)
	else:
		return anim.base_value

func calculate_sine_animation(anim: ParameterAnimation, time: float):
	"""Sine wave: value = base + amplitude * sin(rate * time)"""
	var wave = sin(anim.rate * time) * anim.amplitude
	
	if anim.base_value is float:
		return anim.base_value + wave
	elif anim.base_value is Vector2:
		return Vector2(
			anim.base_value.x + wave,
			anim.base_value.y + (cos(anim.rate * time) * anim.offset_x)  # Use offset_x as Y amplitude
		)
	elif anim.base_value is Color:
		# Oscillate brightness
		var brightness_mod = 1.0 + (wave * 0.2)  # ±20% brightness variation
		return anim.base_value * brightness_mod
	else:
		return anim.base_value

func calculate_cosine_animation(anim: ParameterAnimation, time: float):
	"""Cosine wave: value = base + amplitude * cos(rate * time)"""
	var wave = cos(anim.rate * time) * anim.amplitude
	
	if anim.base_value is float:
		return anim.base_value + wave
	elif anim.base_value is Vector2:
		return Vector2(
			anim.base_value.x + wave,
			anim.base_value.y + (sin(anim.rate * time) * anim.offset_x)
		)
	elif anim.base_value is Color:
		# Oscillate saturation
		var sat_mod = 1.0 + (wave * 0.3)  # ±30% saturation variation
		var hsv = anim.base_value.to_hsv()
		hsv.g = clamp(hsv.g * sat_mod, 0.0, 1.0)
		return Color.from_hsv(hsv.r, hsv.g, hsv.b, hsv.a)
	else:
		return anim.base_value

func calculate_pulse_animation(anim: ParameterAnimation, time: float):
	"""Pulse: value = base + amplitude * (1 + sin(rate * time)) / 2"""
	var pulse = (1.0 + sin(anim.rate * time)) / 2.0 * anim.amplitude
	
	if anim.base_value is float:
		return anim.base_value + pulse
	elif anim.base_value is Vector2:
		return Vector2(
			anim.base_value.x + pulse,
			anim.base_value.y + ((1.0 + cos(anim.rate * time)) / 2.0 * anim.offset_x)
		)
	elif anim.base_value is Color:
		# Pulse overall brightness
		var brightness = 1.0 + pulse * 0.5  # Up to +50% brighter
		return anim.base_value * brightness
	else:
		return anim.base_value

func calculate_circular_animation(anim: ParameterAnimation, time: float):
	"""Circular motion for Vector2 parameters"""
	if anim.base_value is Vector2:
		var angle = anim.rate * time
		return Vector2(
			anim.base_value.x + cos(angle) * anim.amplitude + anim.offset_x,
			anim.base_value.y + sin(angle) * anim.amplitude + anim.offset_y
		)
	elif anim.base_value is float:
		# For floats, circular becomes a sine wave
		return anim.base_value + sin(anim.rate * time) * anim.amplitude
	elif anim.base_value is Color:
		# For colors, rotate through hue
		var hsv = anim.base_value.to_hsv()
		hsv.r = fmod(hsv.r + (anim.rate * time * 0.05), 1.0)  # Slow hue rotation
		return Color.from_hsv(hsv.r, hsv.g, hsv.b, hsv.a)
	else:
		return anim.base_value

"""
ANIMATION TYPE DOCUMENTATION:

1. LINEAR: 
   - Continuous motion in one direction
   - Parameters: rate (units per second)
   - Good for: Planet rotation (uv_offset_x), cloud drift
   - Example: "uv_offset_x": {"type": "linear", "rate": 2.0}

2. SINE:
   - Smooth oscillation, starts at middle, goes up first
   - Parameters: rate (frequency), amplitude (range)
   - Good for: Gentle swaying, atmospheric effects
   - Example: "rim_light_intensity": {"type": "sine", "rate": 1.0, "amplitude": 0.2}

3. COSINE:
   - Smooth oscillation, starts at maximum
   - Parameters: rate (frequency), amplitude (range) 
   - Good for: Phase-shifted oscillations
   - Example: "light_intensity": {"type": "cosine", "rate": 0.5, "amplitude": 0.3}

4. PULSE:
   - Always positive pulsing (0 to 1 range)
   - Parameters: rate (frequency), amplitude (strength)
   - Good for: Breathing effects, energy fields
   - Example: "core_color": {"type": "pulse", "rate": 2.0, "amplitude": 0.4}

5. CIRCULAR:
   - For Vector2: circular motion around base point
   - For float/Color: becomes sine wave/hue rotation
   - Parameters: rate (rotation speed), amplitude (radius), offset_x/y (center offset)
   - Good for: Light source orbiting, complex UV motion
   - Example: "light_direction": {"type": "circular", "rate": 0.3, "amplitude": 0.5}

PARAMETER TYPE SUPPORT:
- Float: Direct mathematical operations
- Vector2: X/Y component handling, circular motion support
- Color: Hue/saturation/brightness modulation

PERFORMANCE NOTES:
- Animations only run for planets in current system
- Random start offsets prevent synchronization
- Base values preserved from planet library settings
"""
