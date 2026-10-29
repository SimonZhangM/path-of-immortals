extends RefCounted
## Explicit player commands only. Automatic gameplay saving stays read-only for manual slots.
const Files = preload("res://scripts/entry/save_file.gd")
const Metadata = preload("res://scripts/entry/save_metadata.gd")

static func store_manual(catalog: RefCounted, state: MapLoadoutState, source_path: String, path: String) -> String:
	if path.is_empty() or catalog.is_system(path) or MapLoadoutStore.SaveSlots.is_system(path):
		return "快速和自动存档不能手动覆盖，请选择手动档位。"
	catalog.entries()
	if not catalog.error.is_empty(): return catalog.error
	var registered: Array = catalog.paths()
	if path not in registered and path!=catalog.next_manual_slot().path: return "手动档位无效。"
	var snapshot := Metadata.stamp(state.snapshot(),source_path)
	snapshot.save_info.save_kind = "manual"
	var result := Files.write(path,snapshot)
	if result != OK: return "存储失败，原存档保留："+error_string(result)
	if path not in registered:
		result = catalog.register(path)
		if result != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			return "存档列表登记失败，请稍后重试。"
	return ""

static func delete_slot(catalog: RefCounted, path: String) -> String:
	catalog.entries()
	if not catalog.error.is_empty(): return catalog.error
	if path.is_empty() or path not in catalog.paths(): return "存档不在当前列表中。"
	# Stage all recovery files together before deleting any. A failed rename rolls back.
	var staged: Array[Dictionary] = []
	var suffix := ".deleted-%d" % Time.get_ticks_usec()
	for extension in ["",".bak",".tmp"]:
		var original := ProjectSettings.globalize_path(path+extension)
		if not FileAccess.file_exists(original): continue
		var removed := original+suffix
		var result := DirAccess.rename_absolute(original,removed)
		if result != OK:
			for entry in staged: DirAccess.rename_absolute(entry.removed,entry.original)
			return "无法删除存档，原文件保留："+error_string(result)
		staged.append({"original":original,"removed":removed})
	if staged.is_empty(): return "该存档已不存在。"
	for entry in staged:
		if DirAccess.remove_absolute(entry.removed)!=OK:
			push_warning("存档已从列表移除，待清理文件："+entry.removed)
	# Retain registered slot identities as empty reservations, without renumbering others.
	return ""
