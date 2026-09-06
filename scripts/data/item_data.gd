class_name ItemData
extends RefCounted

var id: String
var display_name: String
var type: String
var tags: Array
var cooldown_usec: int
var effects: Array
var grid_size: Vector2i
var icon_path: String

# Registry validates input before constructing an immutable-by-convention definition.
func _init(raw: Dictionary) -> void:
	id = raw["id"]
	display_name = raw["name"]
	type = raw["type"]
	tags = raw["tags"].duplicate()
	cooldown_usec = roundi(float(raw["cooldown"]) * 1_000_000.0)
	effects = raw["effects"].duplicate(true)
	grid_size = Vector2i(int(raw["size"][0]), int(raw["size"][1]))
	icon_path = raw.get("icon", "")
