# =============================================================================
# UI CONTROLLER - Handles menus and interface
# =============================================================================
# UIController.gd
extends Control

@onready var hyperspace_menu = $HyperspaceMenu
@onready var system_list = $HyperspaceMenu/VBoxContainer/SystemList
@onready var travel_button = $HyperspaceMenu/VBoxContainer/TravelButton

func _ready():
	add_to_group("ui")
	hyperspace_menu.visible = false
	travel_button.pressed.connect(_on_travel_button_pressed)

func show_hyperspace_menu():
	populate_system_list()
	hyperspace_menu.visible = true
	get_tree().paused = true

func hide_hyperspace_menu():
	hyperspace_menu.visible = false
	get_tree().paused = false

func populate_system_list():
	system_list.clear()
	var current_system = UniverseManager.get_current_system()
	var connections = current_system.get("connections", [])
	
	for system_id in connections:
		var system_data = UniverseManager.universe_data.systems.get(system_id, {})
		var system_name = system_data.get("name", system_id)
		system_list.add_item(system_name)
		system_list.set_item_metadata(system_list.get_item_count() - 1, system_id)

func _on_travel_button_pressed():
	var selected = system_list.get_selected_items()
	if selected.size() > 0:
		var system_id = system_list.get_item_metadata(selected[0])
		UniverseManager.change_system(system_id)
		hide_hyperspace_menu()

func _input(event):
	if event.is_action_pressed("ui_cancel") and hyperspace_menu.visible:
		hide_hyperspace_menu()
