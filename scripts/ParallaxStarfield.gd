# =============================================================================
# PARALLAX STARFIELD - Manages layered star backgrounds
# =============================================================================
# ParallaxStarfield.gd
extends ParallaxBackground
class_name ParallaxStarfield

@export var base_scroll_speed: Vector2 = Vector2(50, 30)
@export var enable_auto_scroll: bool = false

@onready var background_layer = $BackgroundLayer
@onready var star_layers = [
	$StarLayer1,
	$StarLayer2, 
	$StarLayer3,
	$StarLayer4
]

var star_rects: Array[ColorRect] = []
var starfield_shader: Shader

func _ready():
	print("ParallaxStarfield _ready() called")
	
	# Load the shader
	starfield_shader = load("res://shaders/StarfieldShader.gdshader")
	if not starfield_shader:
		push_error("Could not load StarfieldShader.gdshader")
		return
	else:
		print("Loaded starfield shader successfully")
	
	# Setup background
	setup_background()
	
	# Setup star layers
	setup_star_layers()
	
	# CRITICAL: Find and assign the camera
	call_deferred("find_and_assign_camera")
	
	print("ParallaxStarfield initialized with ", star_layers.size(), " star layers")
	print("Background layer: ", background_layer)
	print("Star rects created: ", star_rects.size())

func find_and_assign_camera():
	# Wait a frame for everything to be in the scene tree
	await get_tree().process_frame
	
	# Try to find the player ship and its camera
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = UniverseManager.player_ship
	
	if player:
		var player_camera = player.get_node("Camera2D")  # Renamed to avoid shadowing
		if player_camera:
			# This doesn't work directly, but we can work around it
			print("Found camera: ", player_camera.global_position)
		else:
			print("No Camera2D found on player")
	else:
		print("No player found")

func setup_background():
	var bg_rect = background_layer.get_node("BackgroundRect")
	if bg_rect:
		bg_rect.color = Color.GREEN  # Make it green for testing
		bg_rect.size = Vector2(4000, 4000)
		bg_rect.position = Vector2(-2000, -2000)
		print("Setup background rect - Color: ", bg_rect.color, " Size: ", bg_rect.size)
	else:
		push_error("Could not find BackgroundRect node")

func setup_star_layers():
	# Layer configurations: [density, brightness, size, twinkle_speed]
	# Better values that should show stars
	var layer_configs = [
		[0.01, 0.3, 1.0, 0.2],   # Distant stars - sparse, dim, tiny
		[0.015, 0.5, 1.5, 0.4],  # Mid-distance stars
		[0.02, 0.7, 2.0, 0.6],   # Closer stars
		[0.025, 1.0, 2.5, 0.8]   # Nearest stars - densest and brightest
	]
	
	for i in range(star_layers.size()):
		if i >= layer_configs.size():
			break
			
		var star_layer = star_layers[i]
		var star_rect = star_layer.get_node("StarRect" + str(i + 1))
		
		if star_rect:
			setup_star_rect(star_rect, layer_configs[i])
			star_rects.append(star_rect)
			print("Setup star layer ", i, " - Density: ", layer_configs[i][0], " Size: ", layer_configs[i][2])

func setup_star_rect(rect: ColorRect, config: Array):
	# Create shader material
	var material = ShaderMaterial.new()
	material.shader = starfield_shader
	
	# Apply configuration with reasonable values
	material.set_shader_parameter("star_density", config[0])  # Use density as-is
	material.set_shader_parameter("star_brightness", config[1]) 
	material.set_shader_parameter("star_size", config[2])      # Use size as-is
	material.set_shader_parameter("twinkle_speed", config[3])
	material.set_shader_parameter("layer_scale", 1.0)
	material.set_shader_parameter("tile_size", 200.0)
	material.set_shader_parameter("world_offset", Vector2.ZERO)
	
	print("Star rect config - Density: ", config[0], " Brightness: ", config[1], " Size: ", config[2])
	
	# Set material and size
	rect.material = material
	rect.size = Vector2(8000, 8000)
	rect.position = Vector2(-4000, -4000)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

var camera: Camera2D

func _process(delta):
	# Manual camera following
	if not camera:
		find_camera()
	
	if camera:
		# Manually update parallax offset based on camera position
		scroll_offset = camera.global_position
	
	if enable_auto_scroll:
		scroll_offset += base_scroll_speed * delta
	
	# Update shader offsets for proper tiling
	update_shader_offsets()

func find_camera():
	# Just use the UniverseManager reference
	var player = UniverseManager.player_ship
	
	if player:
		camera = player.get_node("Camera2D")
		if camera:
			print("ParallaxStarfield found camera: ", camera)
		else:
			print("Player found but no Camera2D child")
	else:
		print("No player ship found in UniverseManager")

func update_shader_offsets():
	for rect in star_rects:
		if rect and rect.material:
			# Calculate world offset based on scroll
			var world_offset = scroll_offset
			rect.material.set_shader_parameter("world_offset", world_offset)

func load_system_starfield(system_data: Dictionary):
	"""Configure the starfield based on system data from universe.json"""
	var starfield_config = system_data.get("starfield", {})
	
	if starfield_config.is_empty():
		return  # Use default settings
	
	# Apply system-specific settings
	var layer_count = starfield_config.get("layer_count", 4)
	var base_density = starfield_config.get("base_density", 150) / 100000.0  # Convert to shader scale
	var _base_color = Color(starfield_config.get("base_color", "#FFFFFF"))  # Prefixed with underscore
	var parallax_speeds = starfield_config.get("parallax_speeds", [0.1, 0.3, 0.6, 0.9])
	var brightness_falloff = starfield_config.get("brightness_falloff", [1.0, 0.8, 0.6, 0.4])
	var size_range = starfield_config.get("size_range", [2.0, 8.0])
	var twinkle_enabled = starfield_config.get("twinkle_enabled", true)
	
	# Update existing layers
	for i in range(min(star_layers.size(), layer_count)):
		var star_layer = star_layers[i]  # Renamed to avoid shadowing
		var rect = star_rects[i] if i < star_rects.size() else null
		
		if star_layer and rect and rect.material:
			# Update parallax motion
			star_layer.motion_scale = Vector2.ONE * parallax_speeds[i]
			
			# Update shader parameters
			var density = base_density * (i + 1)  # Increase density for closer layers
			var brightness = brightness_falloff[i] if i < brightness_falloff.size() else 0.5
			var star_size = size_range[0] + (size_range[1] - size_range[0]) * (float(i) / layer_count)
			var twinkle_speed = 0.5 if twinkle_enabled else 0.0
			
			rect.material.set_shader_parameter("star_density", density)
			rect.material.set_shader_parameter("star_brightness", brightness)
			rect.material.set_shader_parameter("star_size", star_size) 
			rect.material.set_shader_parameter("twinkle_speed", twinkle_speed)
	
	print("Loaded starfield for system: ", system_data.get("name", "Unknown"))
