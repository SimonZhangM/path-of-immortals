extends Node
## Read only routing metadata here; the map validates/restores the complete save.
@export var inventory_save_path := MapLoadoutStore.DEFAULT_PATH
var startup_error := ""
var defer_map_music := false

func _ready() -> void:
	start.call_deferred()

static func saved_location(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): path += ".bak"
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var raw: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not raw is Dictionary: return {}
	var location: Variant = raw.get("map_location", {})
	return location if MapLoadoutState.valid_map_location(location) else {}

func start() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/session_maps.json"))
	var path := MapLoadoutStore.session_path(inventory_save_path)
	var location := saved_location(path)
	var map_id: String = location.get("map_id", catalog.default_map)
	if not catalog.scenes.has(map_id): map_id = catalog.default_map
	var destination = load(catalog.scenes[map_id]).instantiate()
	if not location.is_empty():
		var found := false
		for point in destination.get_node("MapViewport/MapContent/Points").get_children():
			if point.point_id == location.point_id:
				found = true
				break
		if not found:
			destination.free()
			destination = load(catalog.scenes[catalog.default_map]).instantiate()
			push_warning("存档落点已失效，使用默认地图起点。")
	destination.inventory_save_path = path
	destination.defer_map_music = defer_map_music
	get_tree().root.add_child(destination)
	if not destination.startup_error.is_empty():
		startup_error = destination.startup_error
		# Keep the map's existing error reporting; do not write or replace the save.
	get_tree().current_scene = destination
	queue_free()
