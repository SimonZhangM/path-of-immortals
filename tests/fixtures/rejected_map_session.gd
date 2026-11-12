extends "res://scripts/map/map_session_start.gd"
## Observe the failure route without replacing the test's current scene.
var rejection := ""
func _return_to_menu(message: String) -> void:
	rejection=message
