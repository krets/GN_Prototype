# =============================================================================
# HYPERSPACE MAP - Visual galaxy map for system navigation
# =============================================================================
# HyperspaceMap.gd
extends Control

@onready var info_label = $InfoPanel/VBox/InfoLabel
@onready var jump_button = $InfoPanel/VBox/JumpButton
@onready var cancel_button = $InfoPanel/VBox/CancelButton
@onready var flavor_panel = $FlavorPanel
@onready var flavor_label = $FlavorPanel/FlavorLabel

var systems_data: Dictionary = {}
var system_positions: Dictionary = {}
var system_connections: Dictionary = {}
var selected_system: String = ""
var current_system: String = ""

# Visual settings - retro DOS green theme
var bg_color = Color(0.0, 0.2, 0.0, 0.25)  # Dark green with 75% transparency
var line_color = Color(0.0, 0.8, 0.0, 1.0)  # Bright green
var system_color = Color(0.0, 1.0, 0.0, 1.0)  # Bright green
var current_system_color = Color(1.0, 1.0, 0.0, 1.0)  # Yellow
var selected_system_color = Color(1.0, 0.5, 0.0, 1.0)  # Orange
var unavailable_color = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray

var system_radius = 8.0
var line_width = 2.0

func _ready():
	# Don't force full rect - let the parent control the size
	setup_systems()
	current_system = UniverseManager.current_system_id
	
	# Debug: Check if nodes are found
	print("InfoPanel found: ", $InfoPanel != null)
	print("FlavorPanel found: ", $FlavorPanel != null)
	if $FlavorPanel != null:
		print("FlavorLabel found: ", $FlavorPanel.get_node("FlavorLabel") != null)
	
	jump_button.pressed.connect(_on_jump_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	update_ui()

func setup_systems():
	"""Define system positions and connections for the map"""
	# Use the actual control size for positioning
	var control_size = size
	if control_size.x == 0 or control_size.y == 0:
		# If size isn't set yet, use reasonable defaults
		control_size = Vector2(800, 600)
	
	var margin = 50
	var map_width = control_size.x - (margin * 2) - 320  # Leave space for info panel
	var map_height = control_size.y - (margin * 2)
	
	# Define system positions (distributed across the map)
	system_positions = {
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
	
	# Define connections (simple network, 2-3 connections per system)
	system_connections = {
		"sol_system": ["alpha_centauri", "vega_system"],
		"alpha_centauri": ["sol_system", "sirius_system", "rigel_system"],
		"vega_system": ["sol_system", "arcturus_system", "capella_system"],
		"sirius_system": ["alpha_centauri", "aldebaran_system"],
		"rigel_system": ["alpha_centauri", "antares_system", "aldebaran_system"],
		"arcturus_system": ["vega_system", "capella_system", "deneb_system"],
		"deneb_system": ["arcturus_system", "capella_system", "antares_system"],
		"aldebaran_system": ["sirius_system", "rigel_system"],
		"antares_system": ["rigel_system", "deneb_system"],
		"capella_system": ["vega_system", "arcturus_system", "deneb_system"]
	}
	
	systems_data = UniverseManager.universe_data.systems

func _draw():
	# Draw background - fill the entire control
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)
	
	# Debug: print control size
	if size.x == 0 or size.y == 0:
		print("HyperspaceMap has zero size: ", size)
		return
	
	# Draw connection lines first (so they appear behind systems)
	for system_id in system_connections:
		if system_id in system_positions:
			var system_pos = system_positions[system_id]
			var connections = system_connections[system_id]
			
			for connected_id in connections:
				if connected_id in system_positions:
					var connected_pos = system_positions[connected_id]
					draw_line(system_pos, connected_pos, line_color, line_width)
	
	# Draw systems
	for system_id in system_positions:
		var pos = system_positions[system_id]
		var color = system_color
		
		# Color coding
		if system_id == current_system:
			color = current_system_color
		elif system_id == selected_system:
			color = selected_system_color
		elif not can_travel_to(system_id):
			color = unavailable_color
		
		# Draw system circle
		draw_circle(pos, system_radius, color)
		
		# Draw system name
		var system_name = systems_data.get(system_id, {}).get("name", system_id)
		var font = ThemeDB.fallback_font
		var font_size = 16
		var text_size = font.get_string_size(system_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = pos + Vector2(-text_size.x / 2, system_radius + 20)
		draw_string(font, text_pos, system_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_system = get_system_at_position(event.position)
			if clicked_system != "":
				select_system(clicked_system)

func get_system_at_position(pos: Vector2) -> String:
	"""Find which system was clicked based on mouse position"""
	for system_id in system_positions:
		var system_pos = system_positions[system_id]
		var distance = pos.distance_to(system_pos)
		if distance <= system_radius + 10:  # Small margin for easier clicking
			return system_id
	return ""

func select_system(system_id: String):
	"""Select a system and update UI"""
	selected_system = system_id
	update_ui()
	queue_redraw()

func update_ui():
	"""Update the info panel based on current selection"""
	var flavor_text = ""
	
	if selected_system == "":
		info_label.text = "Select a destination system"
		jump_button.disabled = true
		flavor_text = "Navigate the galaxy using the hyperspace network. Click on connected systems to plan your route."
	elif selected_system == current_system:
		info_label.text = "Current location: " + get_system_name(selected_system)
		jump_button.disabled = true
		flavor_text = get_system_flavor(selected_system)
	elif can_travel_to(selected_system):
		info_label.text = "Jump to: " + get_system_name(selected_system)
		jump_button.disabled = false
		flavor_text = get_system_flavor(selected_system)
	else:
		info_label.text = get_system_name(selected_system) + " - Not accessible"
		jump_button.disabled = true
		flavor_text = get_system_flavor(selected_system)
	
	# Set flavor text with debug
	if flavor_label != null:
		flavor_label.text = flavor_text
		print("Setting flavor text: ", flavor_text)
	else:
		print("ERROR: flavor_label is null!")

func get_system_flavor(system_id: String) -> String:
	"""Get the flavor text for a system"""
	var system_data = systems_data.get(system_id, {})
	var flavor = system_data.get("flavor_text", "No information available about this system.")
	print("Getting flavor for ", system_id, ": ", flavor)
	return flavor

func get_system_name(system_id: String) -> String:
	return systems_data.get(system_id, {}).get("name", system_id)

func can_travel_to(system_id: String) -> bool:
	"""Check if we can travel to the specified system"""
	if current_system == "":
		return false
	var connections = system_connections.get(current_system, [])
	return system_id in connections

func _on_jump_pressed():
	if selected_system != "" and can_travel_to(selected_system):
		# Start hyperspace sequence instead of instant jump
		var player_ship = UniverseManager.player_ship
		if player_ship and player_ship.has_method("start_hyperspace_sequence"):
			player_ship.start_hyperspace_sequence(selected_system)
			hide_map()
		else:
			# Fallback to instant jump if player ship not found
			UniverseManager.change_system(selected_system)
			hide_map()

func _on_cancel_pressed():
	hide_map()

func show_map():
	"""Show the hyperspace map"""
	# Recalculate system positions based on current size
	setup_systems()
	
	# Position panels relative to this control's size
	var control_size = size
	var panel_width = 300
	var info_panel_height = 120
	var flavor_panel_height = 150
	var panel_spacing = 10
	var margin = 20
	
	# Get panel references
	var info_panel = $InfoPanel
	var flavor_panel = $FlavorPanel
	
	# Calculate positions from bottom-right corner
	var info_panel_x = control_size.x - panel_width - margin
	var info_panel_y = control_size.y - info_panel_height - margin
	
	var flavor_panel_x = control_size.x - panel_width - margin  
	var flavor_panel_y = info_panel_y - flavor_panel_height - panel_spacing
	
	# Position info panel at bottom right
	info_panel.position = Vector2(info_panel_x, info_panel_y)
	info_panel.size = Vector2(panel_width, info_panel_height)
	
	# Position flavor panel above info panel
	flavor_panel.position = Vector2(flavor_panel_x, flavor_panel_y)
	flavor_panel.size = Vector2(panel_width, flavor_panel_height)
	
	print("Control size: ", control_size)
	print("Info panel pos: ", info_panel.position, " size: ", info_panel.size)
	print("Flavor panel pos: ", flavor_panel.position, " size: ", flavor_panel.size)
	
	current_system = UniverseManager.current_system_id
	selected_system = ""
	update_ui()
	visible = true
	get_tree().paused = true
	
	# Force a redraw with new positions
	queue_redraw()

func hide_map():
	"""Hide the hyperspace map"""
	visible = false
	get_tree().paused = false

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		hide_map()
		get_viewport().set_input_as_handled()
