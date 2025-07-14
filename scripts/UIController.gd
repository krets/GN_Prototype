# =============================================================================
# UPDATED UI CONTROLLER - Now uses visual hyperspace map
# =============================================================================
# UIController.gd
extends Control

@onready var hyperspace_map = $HyperspaceMap

func _ready():
	add_to_group("ui")
	setup_ui()

func setup_ui():
	# Hide map initially
	if hyperspace_map:
		hyperspace_map.visible = false
	
	# Make sure process mode allows UI to work when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_hyperspace_menu():
	"""Show the visual hyperspace map"""
	if hyperspace_map and hyperspace_map.has_method("show_map"):
		hyperspace_map.show_map()

func _input(event):
	if event.is_action_pressed("ui_cancel") and hyperspace_map and hyperspace_map.visible:
		hyperspace_map.hide_map()
		get_viewport().set_input_as_handled()
