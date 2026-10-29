extends RefCounted
## Explicit visible snapshots; transaction commits never call this implicitly.
const Files = preload("res://scripts/entry/save_file.gd")
const Slots = preload("res://scripts/entry/save_slot_policy.gd")
const Metadata = preload("res://scripts/entry/save_metadata.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
const Settings = preload("res://scripts/settings/game_settings.gd")
static var pending_quick: Dictionary = {}
static var pending_source := ""
static var retry_seconds := 0.0

static func sync_preferences() -> void:
	if bool(Settings.value("quick_save",true)): return
	pending_quick.clear()
	pending_source = ""
	retry_seconds = 0.0

static func write(state: MapLoadoutState, source_path: String, kind: String, reason: String) -> String:
	# Empty/standalone fixture paths must never touch the user's shared snapshots.
	if not Slots.is_working(source_path): return ""
	if kind not in ["quick","auto"]: return "存档类别无效。"
	sync_preferences()
	if not bool(Settings.value("quick_save" if kind=="quick" else "auto_save",true)): return ""
	var target := Slots.quick_path() if kind=="quick" else Slots.auto_path
	var snapshot := Metadata.stamp(state.snapshot(),source_path)
	snapshot.save_info.save_kind = kind
	snapshot.save_info.checkpoint_reason = reason
	var error := Files.write(target,snapshot)
	if error!=OK: return "存档保存失败，原记录保留："+error_string(error)
	if kind=="quick": pending_quick.clear()
	# Continue also discovers the latest snapshot if the optional index write fails.
	if Session.remember(target)!=OK: push_warning("存档已保存，续玩索引暂未更新。")
	return ""

static func after_action(state: MapLoadoutState, source_path: String, reason: String) -> void:
	# Call only AFTER a successful transaction. A checkpoint failure must not
	# report the transaction itself as failed and invite duplicate purchases.
	var error := write(state,source_path,"quick",reason)
	if error.is_empty(): return
	pending_quick = Metadata.stamp(state.snapshot(),source_path)
	pending_quick.save_info.save_kind = "quick"
	pending_quick.save_info.checkpoint_reason = reason
	pending_source = source_path
	retry_seconds = 5.0
	push_warning("操作已完成，快速存档等待重试："+error)

static func retry_pending(seconds: float, source_path: String, safe: bool) -> void:
	sync_preferences()
	if pending_quick.is_empty(): return
	if source_path!=pending_source:
		pending_quick.clear()
		return
	retry_seconds = maxf(0.0,retry_seconds-seconds)
	if not safe or retry_seconds>0.0: return
	retry_seconds = 5.0
	if Files.write(Slots.quick_path(),pending_quick)==OK:
		pending_quick.clear()
		Session.remember(Slots.quick_path())
