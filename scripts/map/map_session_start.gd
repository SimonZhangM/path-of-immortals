extends Node
## Read only routing metadata here; the map validates/restores the complete save.
@export var inventory_save_path := MapLoadoutStore.DEFAULT_PATH
var startup_error := ""
var defer_map_music := false
const LoadingOverlay = preload("res://scripts/entry/game_loading_overlay.gd")
var _started := false

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
	if _started: return
	_started = true
	if MapLoadoutStore.GameSaveSession.resume_requested:
		await _start_with_loading()
		return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/session_maps.json"))
	var path := MapLoadoutStore.session_path(inventory_save_path)
	if MapLoadoutStore.GameSaveSession.resume_requested and not MapLoadoutStore.GameSaveSession.has_save(path):
		_return_to_menu("最后使用的存档已不可读取。")
		return
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
		if MapLoadoutStore.GameSaveSession.resume_requested:
			destination.queue_free()
			_return_to_menu("存档读取失败：" + startup_error)
			return
	MapLoadoutStore.GameSaveSession.resume_requested = false
	get_tree().current_scene = destination
	queue_free()

func _load_map_scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path, "PackedScene"): return null
	var error := ResourceLoader.load_threaded_request(path, "PackedScene")
	if error != OK: return null
	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path) as PackedScene
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS: return null
		await get_tree().process_frame
	return null

func _start_with_loading() -> void:
	var overlay := LoadingOverlay.show_for(get_tree())
	# Ensure the loading UI is rendered before any synchronous metadata work.
	await RenderingServer.frame_post_draw
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/session_maps.json"))
	var path := MapLoadoutStore.session_path(inventory_save_path)
	if not MapLoadoutStore.GameSaveSession.has_save(path):
		await _loading_failed(overlay, "最后使用的存档已不可读取。")
		return
	var location := saved_location(path)
	var map_id: String = location.get("map_id", catalog.default_map)
	if not catalog.scenes.has(map_id): map_id = catalog.default_map
	var scene := await _load_map_scene(catalog.scenes[map_id])
	if scene == null:
		await _loading_failed(overlay, "地图资源读取失败，请稍后重试。")
		return
	var destination = scene.instantiate()
	if not location.is_empty():
		var found := false
		for point in destination.get_node("MapViewport/MapContent/Points").get_children():
			if point.point_id == location.point_id: found = true; break
		if not found:
			destination.free()
			scene = await _load_map_scene(catalog.scenes[catalog.default_map])
			if scene == null:
				await _loading_failed(overlay, "默认地图资源读取失败。")
				return
			destination = scene.instantiate()
			push_warning("存档落点已失效，使用默认地图起点。")
	destination.inventory_save_path = path
	# Keep entry music until the complete map is ready to be revealed.
	destination.defer_map_music = true
	destination.staged_startup = true
	destination.defer_optional_views = true
	destination.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(destination)
	await destination.initialize_staged()
	if not destination.startup_error.is_empty():
		startup_error = destination.startup_error
		destination.queue_free()
		await _loading_failed(overlay, "存档读取失败：" + startup_error)
		return
	# Restore first, render behind the cover, then reveal without a minimum wait.
	await RenderingServer.frame_post_draw
	MapLoadoutStore.GameSaveSession.resume_requested = false
	destination.defer_map_music = defer_map_music
	if not defer_map_music:
		MapPresentation.enter_map(destination.definition, LoadingOverlay.FADE_SECONDS)
	else:
		preload("res://scripts/entry/entry_music.gd").finish_for(get_tree(), LoadingOverlay.FADE_SECONDS)
	await overlay.reveal()
	destination.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().current_scene = destination
	queue_free()

func _loading_failed(overlay: CanvasLayer, message: String) -> void:
	MapLoadoutStore.GameSaveSession.resume_error = message
	MapLoadoutStore.GameSaveSession.clear_selection()
	# The overlay survives the router, so release it when the new scene appears.
	var tree := get_tree()
	tree.scene_changed.connect(overlay.queue_free, CONNECT_ONE_SHOT)
	tree.change_scene_to_file("res://scenes/entry/start_menu.tscn")

func _return_to_menu(message: String) -> void:
	MapLoadoutStore.GameSaveSession.resume_error = message
	MapLoadoutStore.GameSaveSession.clear_selection()
	get_tree().change_scene_to_file("res://scenes/entry/start_menu.tscn")
