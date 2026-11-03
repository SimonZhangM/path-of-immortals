extends RefCounted
## Read-only routing: tracked targets are marked unless explicitly suppressed.
var definitions := {}
var scene_ids := {}

func _init() -> void:
	var session: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/session_maps.json"))
	for id: String in session.scenes: scene_ids[session.scenes[id]] = id
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/world_map_locations.json"))
	for location: Dictionary in world.locations.values():
		if not location.map_id.is_empty():
			definitions[location.map_id] = JSON.parse_string(FileAccess.get_file_as_string(location.map_definition))

func exit_toward(current: String, destination: String) -> Dictionary:
	if current==destination: return {}
	var queue := [{"map_id":current,"first":{}}]
	var seen := {current:true}
	while not queue.is_empty():
		var step: Dictionary = queue.pop_front()
		for exit: Dictionary in definitions.get(step.map_id,{}).get("exits",[]):
			var next_id: String = scene_ids.get(exit.scene,"")
			if next_id.is_empty() or seen.has(next_id): continue
			var first: Dictionary = exit if step.first.is_empty() else step.first
			if next_id==destination:
				return {"map_id":current,"point_id":first.point_id,"destination_map_id":destination,"kind":"exit"}
			seen[next_id] = true
			queue.append({"map_id":next_id,"first":first})
	return {}

func markers_for(entry: Dictionary, current_map: String) -> Array:
	var targets := QuestTracking.targets(entry)
	var local := targets.filter(func(target: Dictionary): return target.map_id==current_map)
	# Work in the current task scene first; false is an explicit scene exception.
	if not local.is_empty():
		return local.filter(func(target: Dictionary): return bool(target.get("point_marker",true)))
	for target: Dictionary in targets:
		var exit := exit_toward(current_map,target.map_id)
		if not exit.is_empty(): return [exit]
	return []
