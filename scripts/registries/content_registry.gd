class_name ContentRegistry
extends RefCounted

var _items: Dictionary = {}
var _enemies: Dictionary = {}
var errors: PackedStringArray = []

func load_base_content() -> bool:
	_items.clear()
	_enemies.clear()
	errors.clear()
	_load_directory("res://data/items", true)
	_load_directory("res://data/enemies", false)
	return errors.is_empty()

func get_item(id: String) -> ItemData:
	return _items.get(id)

func get_enemy(id: String) -> Dictionary:
	return _enemies.get(id, {}).duplicate(true)

func register_item(raw: Dictionary) -> bool:
	var error := _validate_identity(raw)
	if error.is_empty() and (not raw.get("type") is String or str(raw.get("type", "")).is_empty()):
		error = "type must be a nonempty string"
	if error.is_empty() and not raw.get("tags") is Array:
		error = "tags must be an array"
	if error.is_empty():
		for tag in raw["tags"]:
			if not tag is String:
				error = "tags must contain strings"
	if error.is_empty() and (not _positive_number(raw.get("cooldown")) or float(raw["cooldown"]) < 0.001 or float(raw["cooldown"]) > 86400.0):
		error = "cooldown must be between 0.001 and 86400 seconds"
	if error.is_empty() and (not raw.get("effects") is Array or raw["effects"].is_empty()):
		error = "effects must be a nonempty array"
	if error.is_empty():
		for effect in raw["effects"]:
			if not effect is Dictionary or not EffectSystem.validate_definition(effect):
				error = "unsupported or invalid effect (V0.1: on_activate / damage / positive integer value)"
				break
	if not error.is_empty():
		return _reject(raw, error)
	_items[raw["id"]] = ItemData.new(raw)
	return true

func register_enemy(raw: Dictionary) -> bool:
	var error := _validate_identity(raw)
	if error.is_empty() and not _positive_integer(raw.get("max_hp")):
		error = "max_hp must be a positive integer <= 1 billion"
	if not error.is_empty():
		return _reject(raw, error)
	_enemies[raw["id"]] = raw.duplicate(true)
	return true

func _validate_identity(raw: Dictionary) -> String:
	if not raw.get("id") is String or str(raw.get("id", "")).split(".").size() < 3:
		return "id must be a namespaced string, e.g. base.test.dummy"
	for part in str(raw["id"]).split("."):
		if part.is_empty() or not part.is_valid_identifier() or part != part.to_lower():
			return "id segments must be lowercase identifiers"
	if _items.has(raw["id"]) or _enemies.has(raw["id"]):
		return "duplicate content ID"
	if not raw.get("name") is String or str(raw.get("name", "")).strip_edges().is_empty():
		return "name must be a nonempty string"
	return ""

static func _positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0

static func _positive_integer(value: Variant) -> bool:
	return _positive_number(value) and float(value) <= 1_000_000_000.0 and float(value) == floor(float(value))

func _reject(raw: Dictionary, message: String) -> bool:
	errors.append("%s: %s" % [str(raw.get("id", "<missing id>")), message])
	return false

func _load_directory(path: String, is_item: bool) -> void:
	if not DirAccess.dir_exists_absolute(path):
		errors.append("Missing content directory: " + path)
		return
	var files := DirAccess.get_files_at(path)
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() != "json":
			continue
		var full_path := path.path_join(file_name)
		var file := FileAccess.open(full_path, FileAccess.READ)
		if file == null:
			errors.append("Cannot read: " + full_path)
			continue
		var json := JSON.new()
		if json.parse(file.get_as_text()) != OK:
			errors.append("%s:%d %s" % [full_path, json.get_error_line(), json.get_error_message()])
			continue
		if not json.data is Dictionary:
			errors.append("Expected JSON object: " + full_path)
			continue
		if is_item:
			register_item(json.data)
		else:
			register_enemy(json.data)
