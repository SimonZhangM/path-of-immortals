@tool
class_name MapRoutePoint
extends Sprite2D

@export var point_id: String = ""
@export var location_note: String = ""

func present_exploration(revealed: bool, visited: bool) -> void:
	visible = revealed
	# Material affects this Sprite only: child road signs retain their own colors.
	if visited:
		material = null
	elif material == null:
		var gray := ShaderMaterial.new()
		gray.shader = preload("res://scripts/map/map_unvisited_point.gdshader")
		material = gray

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["请为地图节点填写稳定的Point Id。移动节点只需修改Position。"] if point_id.is_empty() else [])
