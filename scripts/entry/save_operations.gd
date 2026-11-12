extends RefCounted
## Explicit player commands only. Automatic gameplay saving stays read-only for manual slots.
const Files = preload("res://scripts/entry/save_file.gd")
const Metadata = preload("res://scripts/entry/save_metadata.gd")

static func store_manual(catalog: RefCounted, state: MapLoadoutState, source_path: String, path: String) -> String:
	if not catalog.can_store(path):
		return "自动存档不能手动覆盖，请选择快速或手动档位。"
	catalog.entries()
	if not catalog.error.is_empty(): return catalog.error
	var registered: Array = catalog.paths()
	if path not in registered and path!=catalog.next_manual_slot().path: return "手动档位无效。"
	var snapshot := Metadata.stamp(state.snapshot(),source_path)
	var quick: bool = catalog.is_quick(path) or MapLoadoutStore.SaveSlots.is_quick(path)
	snapshot.save_info.save_kind = "quick" if quick else "manual"
	if quick: snapshot.save_info.checkpoint_reason = "manual_save"
	var result := Files.write(path,snapshot)
	if result != OK: return "存储失败，原存档保留："+error_string(result)
	if path not in registered:
		result = catalog.register(path)
		if result != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			return "存档列表登记失败，请稍后重试。"
	if quick:
		# A successful explicit save supersedes any older queued quick snapshot.
		if MapLoadoutStore.SaveSlots.is_quick(path):
			var checkpoints = preload("res://scripts/entry/save_checkpoints.gd")
			checkpoints.pending_quick.clear()
			checkpoints.pending_source = ""
			checkpoints.retry_seconds = 0.0
		if preload("res://scripts/entry/game_save_session.gd").remember(path)!=OK:
			push_warning("存档已保存，续玩索引暂未更新。")
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
