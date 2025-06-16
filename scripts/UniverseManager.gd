# =============================================================================
# UNIVERSE MANAGER - Main controller for the game universe
# =============================================================================
# UniverseManager.gd - Singleton (AutoLoad)
extends Node

signal system_changed(new_system_id)
signal celestial_body_approached(body_data)

var current_system_id: String = ""
var universe_data: Dictionary = {}
var player_ship: Node = null

func _ready():
	load_universe_data()
	change_system("sol_system")  # Starting system

func load_universe_data():
	var file = FileAccess.open("res://data/universe.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			universe_data = json.data
		else:
			push_error("Failed to parse universe.json")
	else:
		push_error("Could not open universe.json")

func change_system(system_id: String):
	if system_id in universe_data.systems:
		current_system_id = system_id
		system_changed.emit(system_id)
		print("Entered system: ", system_id)
	else:
		push_error("System not found: " + system_id)

func get_current_system() -> Dictionary:
	if current_system_id in universe_data.systems:
		return universe_data.systems[current_system_id]
	return {}

func get_celestial_body(body_id: String) -> Dictionary:
	var system = get_current_system()
	for body in system.get("celestial_bodies", []):
		if body.id == body_id:
			return body
	return {}

func can_travel_to_system(system_id: String) -> bool:
	var current_system = get_current_system()
	var connections = current_system.get("connections", [])
	return system_id in connections
