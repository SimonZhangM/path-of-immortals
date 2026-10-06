class_name MapLoadoutStore
extends RefCounted

const DEFAULT_PATH := "user://inventory_loadout.json"

static func session_path(configured: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--loadout-save="):
			return argument.trim_prefix("--loadout-save=")
	return configured

static func create_state(registry: ContentRegistry, board: BoardLayout) -> Dictionary:
	var catalog := MapInventoryCatalog.new()
	catalog.configure(JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json")))
	var error := catalog.load_entries("res://data/maps/inventory_items.json")
	if not error.is_empty():
		return {"state": null, "error": error}
	var state := MapLoadoutState.new()
	var definitions := catalog.visible_entries()
	var materials: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/enemy_materials.json"))
	if not materials is Array: return {"state": null, "error": "兽材目录必须为数组。"}
	var resolved: Array[Dictionary] = []
	for raw: Variant in materials:
		if not raw is Dictionary: return {"state": null, "error": "兽材定义必须为对象。"}
		var record := MapItemQuality.material_record(raw, registry)
		if record.is_empty(): return {"state": null, "error": "兽材来源怪物境界／品级无效。"}
		resolved.append(record)
	error = catalog.replace_entries(resolved)
	if not error.is_empty(): return {"state": null, "error": error}
	definitions.append_array(catalog.visible_entries())
	var boards: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/qinglan_boards.json"))
	if not boards is Array: return {"state": null, "error": "阵盘目录必须为数组。"}
	error = catalog.replace_entries(boards)
	if not error.is_empty(): return {"state": null, "error": error}
	definitions.append_array(catalog.visible_entries())
	error = state.configure(registry, board, definitions)
	if error.is_empty():
		for enemy: Dictionary in registry._enemies.values():
			for row: Dictionary in enemy.get("loot", []):
				if not state.records.has(row.item_id) or state.records[row.item_id].category != "beast":
					error = "敌方掉落引用了未知兽材：" + row.item_id
	return {"state": state, "error": error}

static func load_into(state: MapLoadoutState, path: String) -> String:
	if path.is_empty():
		return ""
	var target_path := path
	if not FileAccess.file_exists(path):
		# Recover the last complete file if shutdown interrupted the rename.
		if not FileAccess.file_exists(path + ".bak"):
			return save(state, path)
		path += ".bak"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "无法读取行囊存档。"
	var parser := JSON.new()
	var saved_text := file.get_as_text()
	file.close() # Windows cannot rename the v1 file while our read handle is open.
	if parser.parse(saved_text) != OK:
		return "行囊存档内容不完整，原文件已保留。"
	var error := state.restore(parser.data)
	if error.is_empty() and (path != target_path or parser.data.get("version", 1) == 1 or parser.data.get("content_grants", {}) != state.content_grants):
		error = save(state, target_path)
	return error

static func save(state: MapLoadoutState, path: String) -> String:
	if path.is_empty():
		return ""
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return "无法保存行囊，请检查本地目录的写入权限。"
	file.store_string(JSON.stringify(state.snapshot(), "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return "行囊存档写入失败，原存档保留。"
	var target := ProjectSettings.globalize_path(path)
	var backup := target + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak") and DirAccess.remove_absolute(backup) != OK:
			return "无法更新行囊备份，原存档保留。"
		if DirAccess.rename_absolute(target, backup) != OK:
			return "无法备份行囊，原存档保留。"
	if DirAccess.rename_absolute(target + ".tmp", target) != OK:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(backup, target)
		return "无法完成行囊保存，已保留上一份配置。"
	return ""

static func claim_reward(state: MapLoadoutState, reward: Dictionary, path: String) -> String:
	if state.has_reward(reward.get("id", "")) and not reward.get("test_replay_on_restart", false):
		return ""
	# Save a candidate before publishing ownership/UI changes. Failure leaves the
	# live inventory and receipt untouched, so the same button can safely retry.
	var prepared := state.reward_candidate(reward)
	var candidate: MapLoadoutState = prepared.state
	var error: String = prepared.error
	if error.is_empty():
		error = save(candidate, path)
	if not error.is_empty():
		return error
	return state.restore(candidate.snapshot())
