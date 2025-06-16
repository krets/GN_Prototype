# =============================================================================
# CELESTIAL BODY - Generic space object (planets, moons, stations)
# =============================================================================
# CelestialBody.gd
extends StaticBody2D
class_name CelestialBody

@export var celestial_data: Dictionary = {}
@onready var sprite = $Sprite2D
@onready var label = $Label

func _ready():
	if celestial_data.has("sprite"):
		load_sprite(celestial_data.sprite)
	if celestial_data.has("name"):
		label.text = celestial_data.name

func load_sprite(sprite_path: String):
	var texture = load(sprite_path)
	if texture:
		sprite.texture = texture

func can_interact() -> bool:
	return celestial_data.get("can_land", false)

func interact():
	print("Landing on: ", celestial_data.name)
	UniverseManager.celestial_body_approached.emit(celestial_data)
	# Here you would transition to planet surface or show services menu
