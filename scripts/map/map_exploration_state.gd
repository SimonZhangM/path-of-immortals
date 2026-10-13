class_name MapExplorationState
extends RefCounted

# Pure graph-derived visibility. Only visited IDs are persisted; frontier is rebuilt.
var visited: Dictionary = {}
var revealed: Dictionary = {}
var full_routes: Dictionary = {}

static func valid_record(raw: Variant) -> bool:
	if not raw is Dictionary or raw.size() > 128: return false
	for map_id: Variant in raw:
		if not map_id is String or not map_id.begins_with("base.map."): return false
		if not raw[map_id] is Array or raw[map_id].size() > 4096: return false
		var seen := {}
		for point_id: Variant in raw[map_id]:
			if not point_id is String or not point_id.begins_with(map_id + ".point.") or seen.has(point_id): return false
			seen[point_id] = true
	return true

func rebuild(adjacency: Dictionary, visited_ids: Array) -> void:
	visited.clear()
	revealed.clear()
	full_routes.clear()
	for id: String in visited_ids:
		if adjacency.has(id): visited[id] = true
	for id: String in visited:
		revealed[id] = true
		for edge: Dictionary in adjacency[id]:
			revealed[edge.to] = true
			full_routes[edge.id] = true
