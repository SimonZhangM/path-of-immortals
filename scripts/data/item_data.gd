class_name ItemData
extends RefCounted

var id: String
var display_name: String
var type: String
var tags: Array
var cooldown_usec: int
var stamina_cost: int
var effects: Array
var grid_size: Vector2i
var icon_path: String
var uses_per_unit: int
var category: String
var quality: String

# Registry validates input before constructing an immutable-by-convention definition.
func _init(raw: Dictionary) -> void:
	id = raw["id"]
	display_name = raw["name"]
	type = raw["type"]
	tags = raw["tags"].duplicate()
	cooldown_usec = roundi(float(raw["cooldown"]) * 1_000_000.0)
	stamina_cost = int(raw.get("stamina_cost", 0))
	effects = raw["effects"].duplicate(true)
	grid_size = Vector2i(int(raw["size"][0]), int(raw["size"][1]))
	icon_path = raw.get("icon", "")
	uses_per_unit = int(raw.get("uses_per_unit", 0))
	category = raw.get("category", type)
	quality = raw.get("quality", "凡品")

func is_consumable() -> bool:
	return uses_per_unit > 0
