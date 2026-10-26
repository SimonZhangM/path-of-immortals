extends Control
## Presentation only: callers supply selected element IDs; never rolls or assigns roots.
const EFFECT := preload("res://scripts/entry/root_selection_effect.gdshader")
var _rings: Dictionary = {}
var _selected: Array[String] = []

func configure(config: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var source := Vector2(config.source_size[0], config.source_size[1])
	for entry: Dictionary in config.elements:
		var radii := Vector2(entry.radii[0], entry.radii[1])
		var extent: float = maxf(radii.x, radii.y) + config.padding
		var center := Vector2(entry.center[0], entry.center[1])
		var ring := ColorRect.new()
		ring.name = "Selected_" + str(entry.id)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader_material := ShaderMaterial.new()
		shader_material.shader = EFFECT
		shader_material.set_shader_parameter("extent", extent)
		shader_material.set_shader_parameter("radii", radii)
		shader_material.set_shader_parameter("angle", deg_to_rad(entry.angle))
		shader_material.set_shader_parameter("tint", Color(entry.color))
		ring.material = shader_material
		add_child(ring)
		ring.anchor_left = (center.x - extent) / source.x
		ring.anchor_right = (center.x + extent) / source.x
		ring.anchor_top = (center.y - extent) / source.y
		ring.anchor_bottom = (center.y + extent) / source.y
		ring.hide()
		_rings[entry.id] = ring
	hide()

func accepts_roots(element_ids: Array) -> bool:
	for id in element_ids:
		if not id is String or not _rings.has(id): return false
	return true

func set_selected_roots(element_ids: Array) -> bool:
	if not accepts_roots(element_ids): return false
	var next: Array[String] = []
	for id in element_ids:
		if not next.has(id): next.append(id)
	_selected = next
	for id: String in _rings: _rings[id].visible = _selected.has(id)
	visible = not _selected.is_empty()
	return true

func get_selected_roots() -> Array[String]:
	return _selected.duplicate()

func clear_selection() -> void:
	set_selected_roots([])
