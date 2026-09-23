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
	error = state.configure(registry, board, catalog.visible_entries())
	return {"state": state, "error": error}

static func load_into(state: MapLoadoutState, path: String) -> String:
	if path.is_empty():
		return ""
	if not FileAccess.file_exists(path):
		# Recover the last complete file if shutdown interrupted the rename.
		if not FileAccess.file_exists(path + ".bak"):
			return ""
		path += ".bak"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "无法读取行囊存档。"
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return "行囊存档内容不完整，原文件已保留。"
	return state.restore(parser.data)

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
	if state.has_reward(reward.get("id", "")):
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
