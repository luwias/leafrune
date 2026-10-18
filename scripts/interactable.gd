extends Node3D
## Bármi, ami elé odaállva megnyomhatod az E-t. Csak egy azonosítót hordoz;
## hogy mi történik, azt a Game (game_state.gd) dönti el.

var target_id := ""


func _ready() -> void:
	add_to_group("interactable")
