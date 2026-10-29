extends RefCounted

# Read-only presentation data. Node membership comes from the shipped layouts,
# without instantiating travel scenes or changing the player's visit ledger.
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/world_map_locations.json"))
var locations: Dictionary = data.locations
var regions: Dictionary = data.regions
var _points_by_map: Dictionary = {}

func _init() -> void:
	var session: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/session_maps.json"))
	for location: Dictionary in locations.values():
		var map_id: String = location.map_id
		if map_id.is_empty() or not session.scenes.has(map_id) or _points_by_map.has(map_id): continue
		var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(location.map_definition))
		assert(definition.id == map_id, "World location must match its map definition")
		var layout: PackedScene = load(definition.layout_scene)
		var state := layout.get_state()
		var points: Dictionary = {}
		for node in state.get_node_count():
			for property in state.get_node_property_count(node):
				if state.get_node_property_name(node,property) == &"point_id":
					var point_id := str(state.get_node_property_value(node,property))
					if not point_id.is_empty(): points[point_id] = true
		_points_by_map[map_id] = points

func location_for_map(map_id: String) -> String:
	if not map_id.is_empty():
		for location_id: String in locations:
			if locations[location_id].map_id == map_id: return location_id
	return ""

func region_progress(region_id: String, visited: Dictionary) -> Dictionary:
	var total := 0
	var count := 0
	var counted_maps: Dictionary = {}
	for location: Dictionary in locations.values():
		var map_id: String = location.map_id
		if location.region_id != region_id or counted_maps.has(map_id): continue
		counted_maps[map_id] = true
		var valid: Dictionary = _points_by_map.get(map_id,{})
		total += valid.size()
		var seen: Dictionary = {}
		for point_id: String in visited.get(map_id,[]):
			if valid.has(point_id): seen[point_id] = true
		count += seen.size()
	return {"visited":count,"total":total,"ratio":float(count)/total if total > 0 else 0.0}
