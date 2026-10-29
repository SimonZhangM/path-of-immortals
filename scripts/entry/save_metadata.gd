extends RefCounted
## Presentation metadata only; never used by simulation or game-day arithmetic.
const Files = preload("res://scripts/entry/save_file.gd")
const Slots = preload("res://scripts/entry/save_slot_policy.gd")
static var active_path := ""
static var started_ms := 0
static var base_ms := 0
static var complete_history := false

static func start(path: String) -> void:
	if path.is_empty() or path == "user://entry_flow_preview.json" or path == active_path: return
	if Slots.is_snapshot(path): return
	if not Files.read(path).has("board_id"): return
	stop()
	var raw := Files.read(path)
	var info: Dictionary = raw.get("save_info",{}) if raw.get("save_info",{}) is Dictionary else {}
	active_path = path
	base_ms = maxi(0,int(info.get("playtime_ms",0)))
	complete_history = bool(info.get("playtime_complete",false))
	started_ms = Time.get_ticks_msec()

static func stamp(raw: Dictionary, path: String, metadata_source := "") -> Dictionary:
	var result := raw.duplicate(true)
	var source := path if metadata_source.is_empty() else metadata_source
	var previous := Files.read(source if FileAccess.file_exists(source) else source+".bak")
	var info: Dictionary = previous.get("save_info",{}) if previous.get("save_info",{}) is Dictionary else {}
	info = info.duplicate(true)
	info.version = 1
	info.saved_at_unix = int(Time.get_unix_time_from_system())
	info.saved_at_unix_ms = int(Time.get_unix_time_from_system()*1000.0)
	info.timezone_bias = int(Time.get_time_zone_from_system().bias)
	info.chapter_id = str(info.get("chapter_id","prologue"))
	if Slots.is_working(path): info.save_kind = "session"
	if path == active_path and not active_path.is_empty():
		info.playtime_ms = base_ms+maxi(0,Time.get_ticks_msec()-started_ms)
		info.playtime_complete = complete_history
	elif previous.is_empty():
		info.playtime_ms = 0
		info.playtime_complete = true
	result.save_info = info
	return result

static func flush() -> Error:
	if active_path.is_empty(): return OK
	if Slots.is_snapshot(active_path): return ERR_UNAUTHORIZED
	# Read the latest committed gameplay state, not a stale scene snapshot.
	var raw := Files.read(active_path)
	if not raw.has("board_id"): return ERR_FILE_CORRUPT
	return Files.write(active_path,stamp(raw,active_path))

static func stop() -> void:
	if not active_path.is_empty():
		var error := flush()
		if error != OK: push_warning("游戏时长暂未保存："+error_string(error))
	active_path = ""
	started_ms = 0
	base_ms = 0
