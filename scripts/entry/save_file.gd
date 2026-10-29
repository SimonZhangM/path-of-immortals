extends RefCounted
## Small atomic JSON boundary shared by game saves and the slot index.

static func read(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}

static func write(path: String, value: Dictionary) -> Error:
	var file := FileAccess.open(path+".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value,"\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	var target := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"):
			error = DirAccess.remove_absolute(target+".bak")
			if error != OK: return error
		error = DirAccess.rename_absolute(target,target+".bak")
		if error != OK: return error
	error = DirAccess.rename_absolute(target+".tmp",target)
	if error != OK and FileAccess.file_exists(path+".bak"):
		DirAccess.rename_absolute(target+".bak",target)
	return error
