extends RefCounted
## Visible snapshots are independent from the transactional live session.
const Files = preload("res://scripts/entry/save_file.gd")
const AUTO_PATH := "user://inventory_loadout.json"
static var auto_path := AUTO_PATH

static func quick_path() -> String:
	return auto_path.get_base_dir().path_join("quick_save.json")

static func working_path() -> String:
	return auto_path.get_base_dir().path_join("live_session.json")

static func same_path(first: String, second: String) -> bool:
	return not first.is_empty() and not second.is_empty() and ProjectSettings.globalize_path(first)==ProjectSettings.globalize_path(second)

static func is_quick(path: String) -> bool:
	return same_path(path,quick_path())

static func is_working(path: String) -> bool:
	return same_path(path,working_path())

static func is_system(path: String) -> bool:
	return is_auto(path) or is_quick(path)

static func is_snapshot(path: String) -> bool:
	return is_system(path) or is_manual(path)

static func is_auto(path: String) -> bool:
	return same_path(path,auto_path)

static func is_manual(path: String) -> bool:
	if path.is_empty() or is_system(path) or is_working(path): return false
	var source := path if FileAccess.file_exists(path) else path+".bak"
	var info: Variant = Files.read(source).get("save_info",{})
	return info is Dictionary and info.get("save_kind","")=="manual"
