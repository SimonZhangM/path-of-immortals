extends RefCounted
## Browsing preference only, following the existing per-save technique memory.
const SUFFIX := ".task-view.cfg"

static func read_selection(save_path: String) -> Dictionary:
	if save_path.is_empty(): return {}
	var config := ConfigFile.new()
	if config.load(save_path+SUFFIX)!=OK: return {}
	var id: Variant = config.get_value("task","id","")
	var category: Variant = config.get_value("task","category","all")
	if not id is String or not category is String: return {}
	return {"id":id,"category":category}

static func save_selection(save_path: String, selection: Dictionary) -> Error:
	if save_path.is_empty() or read_selection(save_path)==selection: return OK
	var config := ConfigFile.new()
	config.set_value("task","id",selection.id)
	config.set_value("task","category",selection.category)
	return config.save(save_path+SUFFIX)
