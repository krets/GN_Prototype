# =============================================================================
# CELESTIAL BODY - Generic space object with procedural planet support
# =============================================================================
# CelestialBody.gd
extends StaticBody2D
class_name CelestialBody

@export var celestial_data: Dictionary = {}
@onready var sprite = $Sprite2D
@onready var label = $Label

var procedural_planet: ColorRect = null

func _ready():
	if celestial_data.has("type") and celestial_data.type == "planet":
		create_procedural_planet()
	elif celestial_data.has("sprite"):
		load_sprite(celestial_data.sprite)
	
	if celestial_data.has("name"):
		label.text = celestial_data.name

func create_procedural_planet():
	"""Create a procedural planet using the shader system"""
	# Load the planet shader
	var planet_shader = load("res://shaders/PlanetShader_Stage9.gdshader")
	if not planet_shader:
		push_error("Could not load PlanetShader_Stage9.gdshader")
		return
	
	# Create ColorRect for the procedural planet
	procedural_planet = ColorRect.new()
	procedural_planet.name = "ProceduralPlanet"
	
	# Set size to 512x512
	var planet_size = Vector2(512, 512)
	procedural_planet.size = planet_size
	procedural_planet.position = -planet_size / 2  # Center the planet
	procedural_planet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create shader material with default settings
	var material = ShaderMaterial.new()
	material.shader = planet_shader
	
	# Apply color variations based on planet data
	apply_planet_variations(material)
	
	procedural_planet.material = material
	
	# Hide the original sprite and add the procedural planet
	sprite.visible = false
	add_child(procedural_planet)
	
	# Update collision shape to match new planet size
	update_collision_shape(planet_size)

func apply_planet_variations(material: ShaderMaterial):
	"""Apply color and scale variations based on celestial body data"""
	var planet_id = celestial_data.get("id", "")
	var system_id = UniverseManager.current_system_id
	
	# Base seed from planet and system for consistent generation
	var base_seed = hash(planet_id + system_id) % 1000
	
	# Color variations based on planet type/name
	match planet_id:
		"earth":
			# Earth-like: blue oceans, green/brown land
			material.set_shader_parameter("deep_ocean_color", Color(0.1, 0.2, 0.6))
			material.set_shader_parameter("shallow_water_color", Color(0.2, 0.4, 0.7))
			material.set_shader_parameter("lowland_color", Color(0.2, 0.6, 0.3))
			material.set_shader_parameter("highland_color", Color(0.3, 0.5, 0.2))
			material.set_shader_parameter("mountain_color", Color(0.5, 0.4, 0.3))
			material.set_shader_parameter("continent_seed", float(base_seed))
			
		"mars", "rigel_beta":
			# Mars-like: red/orange desert world
			material.set_shader_parameter("deep_ocean_color", Color(0.3, 0.1, 0.1))
			material.set_shader_parameter("shallow_water_color", Color(0.4, 0.2, 0.1))
			material.set_shader_parameter("lowland_color", Color(0.6, 0.3, 0.2))
			material.set_shader_parameter("highland_color", Color(0.7, 0.4, 0.2))
			material.set_shader_parameter("mountain_color", Color(0.5, 0.3, 0.2))
			material.set_shader_parameter("desert_color", Color(0.8, 0.4, 0.2))
			material.set_shader_parameter("desert_intensity", 2.0)
			material.set_shader_parameter("continent_threshold", 0.3)  # More land
			material.set_shader_parameter("continent_seed", float(base_seed + 100))
			
		"proxima_b", "new_geneva":
			# Alien world: purple/blue tints
			material.set_shader_parameter("deep_ocean_color", Color(0.2, 0.1, 0.4))
			material.set_shader_parameter("shallow_water_color", Color(0.3, 0.2, 0.6))
			material.set_shader_parameter("lowland_color", Color(0.4, 0.3, 0.6))
			material.set_shader_parameter("highland_color", Color(0.5, 0.3, 0.5))
			material.set_shader_parameter("mountain_color", Color(0.4, 0.3, 0.4))
			material.set_shader_parameter("continent_seed", float(base_seed + 200))
			
		"vega_prime":
			# Mining world: gray/brown rocky
			material.set_shader_parameter("deep_ocean_color", Color(0.2, 0.2, 0.1))
			material.set_shader_parameter("shallow_water_color", Color(0.3, 0.3, 0.2))
			material.set_shader_parameter("lowland_color", Color(0.4, 0.4, 0.3))
			material.set_shader_parameter("highland_color", Color(0.5, 0.4, 0.3))
			material.set_shader_parameter("mountain_color", Color(0.6, 0.5, 0.4))
			material.set_shader_parameter("terrain_strength", 1.2)  # More mountainous
			material.set_shader_parameter("continent_seed", float(base_seed + 300))
			
		"sirius_major":
			# Wealthy trade world: golden/yellow tints
			material.set_shader_parameter("deep_ocean_color", Color(0.1, 0.2, 0.3))
			material.set_shader_parameter("shallow_water_color", Color(0.2, 0.3, 0.4))
			material.set_shader_parameter("lowland_color", Color(0.5, 0.5, 0.3))
			material.set_shader_parameter("highland_color", Color(0.6, 0.5, 0.3))
			material.set_shader_parameter("mountain_color", Color(0.7, 0.6, 0.4))
			material.set_shader_parameter("continent_seed", float(base_seed + 400))
			
		_:
			# Default variation: randomize colors based on seed
			var rng = RandomNumberGenerator.new()
			rng.seed = base_seed
			
			# Generate coherent color palette
			var hue_base = rng.randf()
			var saturation = rng.randf_range(0.3, 0.8)
			var brightness = rng.randf_range(0.4, 0.7)
			
			var base_color = Color.from_hsv(hue_base, saturation, brightness)
			var ocean_color = Color.from_hsv(fmod(hue_base + 0.3, 1.0), saturation * 0.8, brightness * 0.6)
			
			material.set_shader_parameter("deep_ocean_color", ocean_color * 0.7)
			material.set_shader_parameter("shallow_water_color", ocean_color)
			material.set_shader_parameter("lowland_color", base_color)
			material.set_shader_parameter("highland_color", base_color * 0.8)
			material.set_shader_parameter("mountain_color", base_color * 0.6)
			material.set_shader_parameter("continent_seed", float(base_seed))
	
	# System-wide variations
	apply_system_variations(material, system_id, base_seed)

func apply_system_variations(material: ShaderMaterial, system_id: String, base_seed: int):
	"""Apply variations based on the star system"""
	var system_rng = RandomNumberGenerator.new()
	system_rng.seed = hash(system_id)
	
	# Vary terrain seeds for system coherence but planet uniqueness
	material.set_shader_parameter("terrain_seed", float(base_seed + system_rng.randi() % 500))
	material.set_shader_parameter("detail_seed", float(base_seed + system_rng.randi() % 500))
	material.set_shader_parameter("river_seed", float(base_seed + system_rng.randi() % 500))
	
	# System-based lighting variations (different star types)
	match system_id:
		"sol_system":
			# Yellow star - warm light
			material.set_shader_parameter("light_color", Color(1.0, 0.95, 0.8))
			material.set_shader_parameter("ambient_color", Color(0.4, 0.6, 1.0))
			
		"sirius_system":
			# Blue-white star - cool bright light
			material.set_shader_parameter("light_color", Color(0.9, 0.95, 1.0))
			material.set_shader_parameter("light_intensity", 1.2)
			material.set_shader_parameter("ambient_color", Color(0.6, 0.7, 1.0))
			
		"antares_system":
			# Red supergiant - warm red light
			material.set_shader_parameter("light_color", Color(1.0, 0.7, 0.5))
			material.set_shader_parameter("ambient_color", Color(0.8, 0.4, 0.3))
			
		"rigel_system":
			# Blue supergiant - intense blue-white light
			material.set_shader_parameter("light_color", Color(0.8, 0.9, 1.0))
			material.set_shader_parameter("light_intensity", 1.4)
			material.set_shader_parameter("ambient_color", Color(0.5, 0.6, 1.0))
			
		_:
			# Default star lighting with slight variations
			var light_tint = system_rng.randf_range(0.8, 1.2)
			material.set_shader_parameter("light_color", Color(light_tint, 0.95, 0.9))

func update_collision_shape(planet_size: Vector2):
	"""Update collision shapes to match the new planet size"""
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		circle_shape.radius = planet_size.x / 8  # Reasonable collision size
	
	# Update interaction area
	var interaction_area = $CollisionShape2D/InteractionArea/CollisionShape2D
	if interaction_area and interaction_area.shape is CircleShape2D:
		var interaction_circle = interaction_area.shape as CircleShape2D
		interaction_circle.radius = planet_size.x / 2  # Larger interaction range

func load_sprite(sprite_path: String):
	"""Load static sprite for non-planet celestial bodies"""
	var texture = load(sprite_path)
	if texture:
		sprite.texture = texture

func can_interact() -> bool:
	return celestial_data.get("can_land", false)

func interact():
	print("Landing on: ", celestial_data.name)
	UniverseManager.celestial_body_approached.emit(celestial_data)
	# Here you would transition to planet surface or show services menu
