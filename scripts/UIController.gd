# =============================================================================
# EXACT NODE STRUCTURE FOR UI
# =============================================================================
# Main Scene Structure:
# Main (Node2D)
# └── UI (CanvasLayer)
#     └── UIController (Control) - attach UIController.gd script here
#         └── HyperspaceMenu (Panel)
#             └── VBoxContainer
#                 ├── Title (Label) - text: "Hyperspace Navigation"
#                 ├── SystemList (ItemList)
#                 ├── HBoxContainer
#                 │   ├── TravelButton (Button) - text: "Jump"
#                 │   └── CancelButton (Button) - text: "Cancel"
#                 └── InfoLabel (Label) - text: "Select destination system"

# =============================================================================
# IMPROVED UI CONTROLLER
# =============================================================================
# UIController.gd
extends Control

@onready var hyperspace_menu = $HyperspaceMenu
@onready var system_list = $HyperspaceMenu/VBoxContainer/SystemList
@onready var travel_button = $HyperspaceMenu/VBoxContainer/HBoxContainer/TravelButton
@onready var cancel_button = $HyperspaceMenu/VBoxContainer/HBoxContainer/CancelButton
@onready var info_label = $HyperspaceMenu/VBoxContainer/InfoLabel

func _ready():
	add_to_group("ui")
	setup_ui()
	connect_signals()

func setup_ui():
	# Hide menu initially
	hyperspace_menu.visible = false
	
	# Set up the hyperspace menu panel
	hyperspace_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hyperspace_menu.size = Vector2(300, 400)
	
	# Configure system list
	system_list.custom_minimum_size = Vector2(250, 200)
	
	# Make sure process mode allows UI to work when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func connect_signals():
	travel_button.pressed.connect(_on_travel_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	system_list.item_selected.connect(_on_system_selected)

func show_hyperspace_menu():
	populate_system_list()
	hyperspace_menu.visible = true
	get_tree().paused = true
	
	# Clear selection and update buttons
	system_list.deselect_all()
	travel_button.disabled = true
	info_label.text = "Select destination system"

func hide_hyperspace_menu():
	hyperspace_menu.visible = false
	get_tree().paused = false

func populate_system_list():
	system_list.clear()
	var current_system = UniverseManager.get_current_system()
	var connections = current_system.get("connections", [])
	
	print("Current system connections: ", connections)  # Debug
	
	for system_id in connections:
		var system_data = UniverseManager.universe_data.systems.get(system_id, {})
		var system_name = system_data.get("name", system_id)
		system_list.add_item(system_name)
		system_list.set_item_metadata(system_list.get_item_count() - 1, system_id)
		print("Added system: ", system_name, " (", system_id, ")")  # Debug

func _on_system_selected(index: int):
	travel_button.disabled = false
	var system_id = system_list.get_item_metadata(index)
	var system_data = UniverseManager.universe_data.systems.get(system_id, {})
	var system_name = system_data.get("name", system_id)
	info_label.text = "Jump to: " + system_name

func _on_travel_button_pressed():
	var selected = system_list.get_selected_items()
	if selected.size() > 0:
		var system_id = system_list.get_item_metadata(selected[0])
		print("Traveling to: ", system_id)  # Debug
		UniverseManager.change_system(system_id)
		hide_hyperspace_menu()

func _on_cancel_button_pressed():
	hide_hyperspace_menu()

func _input(event):
	if event.is_action_pressed("ui_cancel") and hyperspace_menu.visible:
		hide_hyperspace_menu()
		get_viewport().set_input_as_handled()

# =============================================================================
# MANUAL UI SETUP STEPS (if you prefer not to rebuild):
# =============================================================================
# 1. Select your UIController (Control node)
# 2. Set Layout → Full Rect (so it covers the full screen)
# 3. Add Panel as child, rename to "HyperspaceMenu"
# 4. Set HyperspaceMenu anchors to Center, size to 300x400
# 5. Add VBoxContainer as child of HyperspaceMenu
# 6. Set VBoxContainer to Full Rect of the Panel
# 7. Add margins: 20 pixels on all sides
# 8. Add these children to VBoxContainer:
#    - Label (name: Title, text: "Hyperspace Navigation")
#    - ItemList (name: SystemList, min size: 250x200)
#    - HBoxContainer
#      - Button (name: TravelButton, text: "Jump")  
#      - Button (name: CancelButton, text: "Cancel")
#    - Label (name: InfoLabel, text: "Select destination system")
