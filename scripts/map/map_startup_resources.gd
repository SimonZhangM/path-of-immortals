extends RefCounted
## Presentation-side prefetch. Validation still runs through the original catalog.
const Metrics = preload("res://scripts/map/map_texture_metrics.gd")
var retained: Array[Resource] = []

func prepare(tree: SceneTree, registry: ContentRegistry, definition: Dictionary) -> void:
	var paths: Dictionary = {}
	for path: String in MapStatusHeader.startup_textures(definition.get("title_image", "")): paths[path] = true
	for file in ["inventory_items", "enemy_materials", "herbs", "minerals", "foods", "qinglan_boards"]:
		var records: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + file + ".json"))
		if records is Array:
			for record: Variant in records:
				if record is Dictionary: _add_icon(paths, record.get("icon", ""))
	for record: Dictionary in registry.library.inventory_records(): _add_icon(paths, record.get("icon", ""))
	# Dynamic player/dialogue textures are not PackedScene dependencies.
	_collect_textures(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/player.json")), paths)
	for file: String in definition.get("event_files", []):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
		if raw is Dictionary and raw.get("type") == "dialogue": _collect_textures(raw, paths)
	var pending: Array[String] = []
	var request_budget := Time.get_ticks_usec()
	for path: String in paths:
		if ResourceLoader.exists(path, "Texture2D") and ResourceLoader.load_threaded_request(path, "Texture2D") == OK:
			pending.append(path)
		if Time.get_ticks_usec()-request_budget > 6000:
			await tree.process_frame
			request_budget = Time.get_ticks_usec()
	while not pending.is_empty():
		var budget := Time.get_ticks_usec()
		for index in range(pending.size()-1, -1, -1):
			var path := pending[index]
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var resource := ResourceLoader.load_threaded_get(path) as Texture2D
				if resource != null:
					retained.append(resource)
					Metrics.has_mipmaps(resource)
			pending.remove_at(index)
			# GPU readbacks for mipmap checks are budgeted rather than batched into
			# a multi-second frame. Never inspect transparent artwork bounds here.
			if Time.get_ticks_usec()-budget > 6000: break
		await tree.process_frame

func _add_icon(paths: Dictionary, path: Variant) -> void:
	if path is String and not path.is_empty(): paths[path] = true

func _collect_textures(value: Variant, paths: Dictionary) -> void:
	if value is Dictionary:
		for child: Variant in value.values(): _collect_textures(child, paths)
	elif value is Array:
		for child: Variant in value: _collect_textures(child, paths)
	elif value is String and value.begins_with("res://") and value.get_extension() in ["png", "webp", "jpg"]:
		paths[value] = true
