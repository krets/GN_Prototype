extends Node2D

@export var num_layers: int = 2
@export var base_parallax_scale: float = 0.0
@export var scale_increment: float = 20
@export var viewport_margin: float = 200.0

var player_ship: Node2D
var camera: Camera2D
var starfield_layers: Array[ColorRect] = []

func _ready():
	# Ship is at ../../Ship from StarfieldManager's position
	player_ship = get_node_or_null("../../Ship")
	if player_ship:
		camera = player_ship.get_node_or_null("Camera2D")
		print("StarfieldManager: Found ship and camera")
	else:
		print("StarfieldManager: Could not find ship at ../../Ship")
	
	# Create the starfield layers
	create_starfield_layers()
	print("Created ", get_child_count(), " starfield layers")

func create_starfield_layers():
	var shader = load("res://shaders/StarfieldShader.gdshader")
	if not shader:
		print("ERROR: Could not load StarfieldShader.gdshader")
		return
	
	for i in range(num_layers):
		var layer = ColorRect.new()
		var material = ShaderMaterial.new()
		material.shader = shader
		
		# Set star parameters for each layer
		material.set_shader_parameter("star_density", 3 / (i + 1))  # Fewer stars per layer
		material.set_shader_parameter("star_brightness", 1.0 - (i * 0.1))
		material.set_shader_parameter("twinkle_speed", 0.5)
		material.set_shader_parameter("star_size", 2.0 + (i * 5.0))  # 10-30 pixel stars
		material.set_shader_parameter("layer_scale", 2 / (i + 1))
		
		layer.material = material
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Set render order (furthest back first)
		layer.z_index = -100 + i
		
		# Set initial size
		layer.size = Vector2(4000, 4000)
		layer.position = Vector2(-2000, -2000)
		
		add_child(layer)
		starfield_layers.append(layer)
	
	print("Created ", num_layers, " starfield layers with shader")

func _process(_delta):
	if not player_ship or not camera:
		return
	
	var viewport_size = get_viewport().size
	var camera_zoom = camera.zoom.x
	var visible_size = viewport_size / camera_zoom + Vector2(viewport_margin * 2, viewport_margin * 2)
	
	for i in range(starfield_layers.size()):
		var layer = starfield_layers[i]
		var parallax_scale = base_parallax_scale + (scale_increment * i)
		
		# Position the layer to cover the visible area
		layer.global_position = camera.global_position - (visible_size / 2)
		layer.size = visible_size
		
		# Update shader with parallax offset
		var world_offset = camera.global_position * parallax_scale
		layer.material.set_shader_parameter("world_offset", world_offset)
