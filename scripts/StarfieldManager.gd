# =============================================================================
# STARFIELD MANAGER - Handles procedural parallax starfield generation
# =============================================================================
# StarfieldManager.gd
extends Node2D
class_name StarfieldManager

@export var viewport_size: Vector2 = Vector2(2048, 2048)  # Size of star generation area
@export var buffer_zone: float = 512.0  # Extra area around viewport

var starfield_layers: Array[Node2D] = []
var current_config: Dictionary = {}
var player_reference: Node2D = null

# Default starfield configuration
var default_config = {
	"layer_count": 4,
	"base_density": 100,  # Stars per 1000x1000 area on closest layer
	"base_color": "#FFFFFF",
	"parallax_speeds": [1.0, 0.7, 0.4, 0.2],  # Speed multipliers per layer (closest to farthest)
	"brightness_falloff": [1.0, 0.8, 0.6, 0.4],  # Brightness per layer
	"size_range": [1.0, 3.0],  # Min/max star size
	"twinkle_enabled": false,
	"colored_stars": false,
	"star_colors": ["#FFFFFF", "#FFFFAA", "#AAAAFF", "#FFAAAA"]
}

func _ready():
	# Wait for player to be available
	await get_tree().create_timer(0.1).timeout
	player_reference = UniverseManager.player_ship
	
	if player_reference:
		setup_starfield()
	
	# Listen for system changes
	UniverseManager.system_changed.connect(_on_system_changed)

func _process(delta):
	if player_reference and starfield_layers.size() > 0:
		update_parallax()

func setup_starfield():
	var system_data = UniverseManager.get_current_system()
	current_config = merge_configs(default_config, system_data.get("starfield", {}))
	
	clear_starfield()
	generate_starfield_layers()

func merge_configs(base: Dictionary, override: Dictionary) -> Dictionary:
	var merged = base.duplicate(true)
	for key in override:
		merged[key] = override[key]
	return merged

func clear_starfield():
	for layer in starfield_layers:
		layer.queue_free()
	starfield_layers.clear()

func generate_starfield_layers():
	var layer_count = current_config.layer_count
	
	for i in range(layer_count):
		var layer = Node2D.new()
		layer.name = "StarLayer_" + str(i)
		add_child(layer)
		starfield_layers.append(layer)
		
		generate_stars_for_layer(layer, i)

func generate_stars_for_layer(layer: Node2D, layer_index: int):
	var layer_count = current_config.layer_count
	var base_density = current_config.base_density
	var parallax_speeds = current_config.get("parallax_speeds", default_config.parallax_speeds)
	var brightness_values = current_config.get("brightness_falloff", default_config.brightness_falloff)
	
	# Calculate density for this layer (deeper layers have more stars)
	var depth_multiplier = 1.0 + (layer_index * 0.5)  # Each layer back gets 50% more stars
	var layer_density = base_density * depth_multiplier
	
	# Calculate area and number of stars
	var area = viewport_size.x * viewport_size.y
	var star_count = int((area / 1000000.0) * layer_density)  # Normalize to 1000x1000 area
	
	# Get brightness for this layer
	var brightness = brightness_values[layer_index] if layer_index < brightness_values.size() else 0.2
	
	# Generate stars
	for i in range(star_count):
		create_star(layer, layer_index, brightness)

func create_star(layer: Node2D, layer_index: int, brightness: float):
	var star = Node2D.new()
	var sprite = Sprite2D.new()
	
	# Create star texture procedurally
	var star_texture = create_star_texture(layer_index, brightness)
	sprite.texture = star_texture
	
	# Random position within expanded viewport
	var half_size = viewport_size * 0.5
	var buffer = buffer_zone
	star.position = Vector2(
		randf_range(-half_size.x - buffer, half_size.x + buffer),
		randf_range(-half_size.y - buffer, half_size.y + buffer)
	)
	
	# Random rotation for visual variety
	star.rotation = randf() * TAU
	
	# Add twinkle animation if enabled
	if current_config.get("twinkle_enabled", false):
		add_twinkle_animation(sprite, layer_index)
	
	star.add_child(sprite)
	layer.add_child(star)

func create_star_texture(layer_index: int, brightness: float) -> ImageTexture:
	var size_range = current_config.get("size_range", default_config.size_range)
	var star_size = int(randf_range(size_range[0], size_range[1]))
	
	# Ensure minimum size of 1
	star_size = max(1, star_size)
	
	var image = Image.create(star_size * 2, star_size * 2, false, Image.FORMAT_RGBA8)
	var center = Vector2(star_size, star_size)
	
	# Get star color
	var star_color = get_star_color(layer_index, brightness)
	
	# Draw star (simple filled circle)
	for x in range(star_size * 2):
		for y in range(star_size * 2):
			var distance = Vector2(x, y).distance_to(center)
			if distance <= star_size:
				# Create soft edge with alpha falloff
				var alpha = 1.0 - (distance / star_size)
				alpha = clamp(alpha, 0.0, 1.0)
				
				var pixel_color = star_color
				pixel_color.a = alpha * brightness
				image.set_pixel(x, y, pixel_color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func get_star_color(layer_index: int, brightness: float) -> Color:
	var base_color_str = current_config.get("base_color", "#FFFFFF")
	var base_color = Color(base_color_str)
	
	if current_config.get("colored_stars", false):
		var colors = current_config.get("star_colors", default_config.star_colors)
		var color_str = colors[randi() % colors.size()]
		base_color = Color(color_str)
	
	# Apply brightness
	base_color.r *= brightness
	base_color.g *= brightness  
	base_color.b *= brightness
	
	return base_color

func add_twinkle_animation(sprite: Sprite2D, layer_index: int):
	var tween = create_tween()
	tween.set_loops()
	
	var twinkle_speed = 1.0 + randf() * 2.0  # Random twinkle speed
	var min_alpha = 0.3 + (layer_index * 0.1)  # Deeper layers twinkle less
	
	tween.tween_property(sprite, "modulate:a", min_alpha, twinkle_speed)
	tween.tween_property(sprite, "modulate:a", 1.0, twinkle_speed)

func update_parallax():
	if not player_reference:
		return
		
	var player_pos = player_reference.global_position
	var parallax_speeds = current_config.get("parallax_speeds", default_config.parallax_speeds)
	
	for i in range(starfield_layers.size()):
		var layer = starfield_layers[i]
		var speed = parallax_speeds[i] if i < parallax_speeds.size() else 0.1
		
		# Simple parallax: multiply player movement by speed
		# speed = 0.0: no movement (static relative to screen)
		# speed = 1.0: full movement (moves with planets)
		layer.position = -player_pos * speed

func _on_system_changed(system_id: String):
	# Small delay to ensure system is fully loaded
	await get_tree().create_timer(0.1).timeout
	setup_starfield()
