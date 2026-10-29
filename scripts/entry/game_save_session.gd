extends RefCounted
## Only remembers which save was last played; game saves remain authoritative.
const INDEX_PATH := "user://last_game_session.json"
const PREVIEW_PATH := "user://entry_flow_preview.json"
const Slots = preload("res://scripts/entry/save_slot_policy.gd")
const Files = preload("res://scripts/entry/save_file.gd")
static var index_path := INDEX_PATH
static var active_path := ""
static var resume_requested := false
static var resume_error := ""

static func has_save(path: String) -> bool:
	if path.is_empty() or path == PREVIEW_PATH: return false
	# Match the store's interrupted-rename recovery, never prefer an older backup
	# over an existing main file, and never treat a creation draft as a game save.
	var source := path if FileAccess.file_exists(path) else path + ".bak"
	if not FileAccess.file_exists(source): return false
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null: return false
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary: return false
	var raw: Dictionary = parser.data
	return (raw.get("version", 0) == 1 or raw.get("version", 0) == 2) and raw.get("board_id", "") is String \
		and not str(raw.get("board_id", "")).is_empty() and raw.get("placements") is Array \
		and (raw.version == 1 or raw.get("owned_units") is Dictionary)

static func resume_path(legacy_path: String) -> String:
	# The two shared checkpoint kinds are ordered by their actual save time.
	var latest := ""
	var latest_time := -1
	if not legacy_path.is_empty():
		for candidate in [legacy_path.get_base_dir().path_join("quick_save.json"),legacy_path]:
			if not has_save(candidate): continue
			var source_file: String = candidate if FileAccess.file_exists(candidate) else candidate+".bak"
			var metadata: Variant = Files.read(source_file).get("save_info",{})
			var info: Dictionary = metadata if metadata is Dictionary else {}
			var timestamp := int(info.get("saved_at_unix_ms",int(info.get("saved_at_unix",FileAccess.get_modified_time(source_file)))*1000))
			if timestamp>latest_time:
				latest = candidate
				latest_time = timestamp
	if not latest.is_empty(): return latest
	var source := index_path if FileAccess.file_exists(index_path) else index_path + ".bak"
	if not FileAccess.file_exists(source):
		# One-time compatibility for the existing single-save installation.
		return legacy_path if has_save(legacy_path) else ""
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null: return ""
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary: return ""
	var path: Variant = parser.data.get("path", "")
	if not path is String or parser.data.get("version", 0) != 1: return ""
	# A missing/damaged last-used save never silently selects another character.
	return path if not Slots.is_working(path) and has_save(path) else ""

static func remember(path: String) -> Error:
	if path.is_empty() or path == PREVIEW_PATH or Slots.is_working(path): return OK
	if not has_save(path): return ERR_INVALID_DATA
	if index_path == INDEX_PATH:
		var absolute := ProjectSettings.globalize_path(path).replace("\\", "/")
		var user_directory := ProjectSettings.globalize_path("user://").replace("\\", "/").trim_suffix("/") + "/"
		# Standalone project fixtures/previews must not change the real resume target.
		if not absolute.begins_with(user_directory): return OK
	if FileAccess.file_exists(index_path) and resume_path("") == path: return OK
	var file := FileAccess.open(index_path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "path": path}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	var target := ProjectSettings.globalize_path(index_path)
	if FileAccess.file_exists(index_path):
		if FileAccess.file_exists(index_path + ".bak"):
			error = DirAccess.remove_absolute(target + ".bak")
			if error != OK: return error
		error = DirAccess.rename_absolute(target, target + ".bak")
		if error != OK: return error
	error = DirAccess.rename_absolute(target + ".tmp", target)
	if error != OK and FileAccess.file_exists(index_path + ".bak"):
		DirAccess.rename_absolute(target + ".bak", target)
	return error

static func begin_resume(path: String) -> bool:
	if not has_save(path): return false
	active_path = path
	resume_requested = true
	resume_error = ""
	return true

static func clear_selection() -> void:
	active_path = ""
	resume_requested = false
