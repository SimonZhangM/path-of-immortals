class_name ContentRegistry
extends RefCounted

var _items: Dictionary = {}
var _enemies: Dictionary = {}
var _characters: Dictionary = {}
var errors: PackedStringArray = []

func load_base_content() -> bool:
	_items.clear()
	_enemies.clear()
	_characters.clear()
	errors.clear()
	_load_directory("res://data/items", "item")
	_load_directory("res://data/enemies", "enemy")
	_load_directory("res://data/characters", "character")
	return errors.is_empty()

func get_item(id: String) -> ItemData:
	return _items.get(id)

func get_enemy(id: String) -> Dictionary:
	return _enemies.get(id, {}).duplicate(true)

func get_character(id: String) -> Dictionary:
	return _characters.get(id, {}).duplicate(true)

func register_character(raw: Dictionary) -> bool:
	var error := _validate_identity(raw)
	if error.is_empty():
		if not _positive_integer(raw.get("max_hp")):
			error = "max_hp must be a positive integer"
		for stat in ["max_stamina", "max_spirit"]:
			if not _nonnegative_integer(raw.get(stat)):
				error = stat + " must be a nonnegative integer"
		for field in ["realm", "portrait"]:
			if not raw.get(field) is String or str(raw[field]).strip_edges().is_empty():
				error = field + " must be a nonempty string"
	if not error.is_empty():
		return _reject(raw, error)
	_characters[raw["id"]] = raw.duplicate(true)
	return true

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
	if error.is_empty() and not raw.get("effects") is Array:
		error = "effects must be an array"
	if error.is_empty():
		var cooldown: Variant = raw.get("cooldown")
		if raw["effects"].is_empty():
			if not (cooldown is int or cooldown is float) or float(cooldown) != 0.0:
				error = "passive items must use cooldown 0"
		elif not _positive_number(cooldown) or float(cooldown) < 0.001 or float(cooldown) > 86400.0:
			error = "active cooldown must be between 0.001 and 86400 seconds"
	if error.is_empty():
		var footprint: Variant = raw.get("size")
		if not footprint is Array or footprint.size() != 2:
			error = "size must be [width, height]"
		else:
			for dimension in footprint:
				if not _positive_integer(dimension) or float(dimension) > 4.0:
					error = "size dimensions must be integers from 1 to 4"
	if error.is_empty() and not raw.get("icon", "") is String:
		error = "icon must be a resource path string"
	if error.is_empty() and not _nonnegative_integer(raw.get("stamina_cost", 0)):
		error = "stamina_cost must be a nonnegative integer"
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
	if error.is_empty():
		for stat in ["max_stamina", "max_spirit"]:
			if not _nonnegative_integer(raw.get(stat, 0)):
				error = stat + " must be a nonnegative integer"
		if not raw.get("portrait", "") is String:
			error = "portrait must be a resource path string"
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
	if _items.has(raw["id"]) or _enemies.has(raw["id"]) or _characters.has(raw["id"]):
		return "duplicate content ID"
	if not raw.get("name") is String or str(raw.get("name", "")).strip_edges().is_empty():
		return "name must be a nonempty string"
	return ""

static func _positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0

static func _positive_integer(value: Variant) -> bool:
	return _positive_number(value) and float(value) <= 1_000_000_000.0 and float(value) == floor(float(value))

static func _nonnegative_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 1_000_000_000.0 and float(value) == floor(float(value))

func _reject(raw: Dictionary, message: String) -> bool:
	errors.append("%s: %s" % [str(raw.get("id", "<missing id>")), message])
	return false

func _load_directory(path: String, kind: String) -> void:
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
		if kind == "item":
			register_item(json.data)
		elif kind == "character":
			register_character(json.data)
		else:
			register_enemy(json.data)
