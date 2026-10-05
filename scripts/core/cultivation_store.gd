class_name CultivationStore
extends RefCounted

static func load_into(knowledge: CultivationKnowledge, library: CultivationLibrary, realm: int, path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"): return ""
	var source := path if FileAccess.file_exists(path) else path+".bak"
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(source)) != OK: return "学习存档损坏，原文件保留"
	var parsed: Variant = parser.data
	if not parsed is Dictionary: return "学习存档损坏，原文件保留"
	return "" if knowledge.restore(parsed,library,realm) else knowledge.error

static func save(knowledge: CultivationKnowledge, path: String) -> String:
	if path.is_empty(): return ""
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return "无法写入学习存档"
	file.store_string(JSON.stringify(knowledge.snapshot(),"\t"))
	file.flush()
	var result := file.get_error()
	file.close()
	if result!=OK: return "学习存档写入失败，原文件保留"
	var target := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak") and DirAccess.remove_absolute(target+".bak")!=OK: return "无法更新学习存档备份"
		if DirAccess.rename_absolute(target,target+".bak")!=OK: return "无法备份学习存档"
	if DirAccess.rename_absolute(target+".tmp",target)!=OK:
		if FileAccess.file_exists(path+".bak"): DirAccess.rename_absolute(target+".bak",target)
		return "学习存档保存失败"
	return ""
