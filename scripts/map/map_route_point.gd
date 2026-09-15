@tool
class_name MapRoutePoint
extends Sprite2D

@export var point_id: String = ""
@export var location_note: String = ""

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["请为地图节点填写稳定的Point Id。移动节点只需修改Position。"] if point_id.is_empty() else [])
