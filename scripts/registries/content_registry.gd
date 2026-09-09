class_name ContentRegistry
extends RefCounted

var _elements: Dictionary = {}
var _traits: Dictionary = {}
var _items: Dictionary = {}
var _enemies: Dictionary = {}
var _characters: Dictionary = {}
var _boards: Dictionary = {}
var _cultivation: Dictionary = {}
var errors: PackedStringArray = []

func load_base_content() -> bool:
	_elements.clear()
	_traits.clear()
	_items.clear()
	_enemies.clear()
	_characters.clear()
	_boards.clear()
	_cultivation.clear()
	errors.clear()
	_load_directory("res://data/elements", "element")
	_load_directory("res://data/traits", "trait")
	_load_directory("res://data/items", "item")
	_load_directory("res://data/boards", "board")
	_load_directory("res://data/cultivation", "cultivation")
	_load_directory("res://data/enemies", "enemy")
	_load_directory("res://data/characters", "character")
	for character in _characters.values() + _enemies.values():
		if character.has("board_layout") and not _boards.has(character["board_layout"]):
			errors.append("Unknown board layout for " + character["id"])
		if character.has("cultivation_rank") and not _cultivation.has(character["cultivation_rank"]):
			errors.append("Unknown cultivation rank for " + character["id"])
		for trait_id in character.get("traits", []):
			if not _traits.has(trait_id):
				errors.append("Unknown companion trait for " + character["id"])
	for board in _boards.values():
		if not FileAccess.file_exists(board.texture_path):
			errors.append("Missing board texture: " + board.texture_path)
	return errors.is_empty()

func get_element(id: String) -> Dictionary:
	return _elements.get(id, {}).duplicate(true)

func get_trait(id: String) -> Dictionary:
	return _traits.get(id, {}).duplicate(true)

func register_element(raw: Dictionary) -> bool:
	var error := _validate_identity(raw)
	if error.is_empty() and (not raw.get("color") is String or not Color.html_is_valid(raw["color"])):
		error = "element color must be valid HTML color"
	if not error.is_empty():
		return _reject(raw, error)
	_elements[raw["id"]] = raw.duplicate(true)
	return true

func register_trait(raw: Dictionary) -> bool:
	var error := _validate_identity(raw)
	var active: bool = raw.get("kind") == "active"
	if error.is_empty() and raw.get("kind") not in ["active", "passive"]:
		error = "trait kind must be active or passive"
	if error.is_empty() and raw.get("effect") not in (["damage", "restore"] if active else ["defense", "max_hp"]):
		error = "unsupported trait effect for this kind"
	if error.is_empty() and not _positive_integer(raw.get("value")):
		error = "trait value must be positive integer"
	var cd: Variant = raw.get("cooldown")
	if error.is_empty():
		if active and (not _positive_number(cd) or float(cd) < 0.001 or float(cd) > 86400):
			error = "active trait cooldown out of range"
		elif not active and (not _nonnegative_integer(cd) or float(cd) != 0):
			error = "passive trait cooldown must be zero"
	if error.is_empty() and not _elements.has(raw.get("element", "base.element.none")):
		error = "unknown trait element"
	if error.is_empty() and not raw.get("description", "") is String:
		error = "trait description must be a string"
	if not error.is_empty():
		return _reject(raw, error)
	_traits[raw["id"]] = raw.duplicate(true)
	return true

func get_item(id: String) -> ItemData:
	return _items.get(id)

func get_enemy(id: String) -> Dictionary:
	return _enemies.get(id, {}).duplicate(true)

func get_character(id: String) -> Dictionary:
	return _characters.get(id, {}).duplicate(true)

func get_board(id: String) -> BoardLayout:
	return _boards.get(id)

func get_cultivation(id: String) -> Dictionary:
	return _cultivation.get(id, {}).duplicate(true)

func register_cultivation(raw: Dictionary) -> bool:
	var error := _validate_identity(raw)
	if error.is_empty() and not _nonnegative_integer(raw.get("order")):
		error = "cultivation order must be a nonnegative integer"
	var frame: Variant = raw.get("portrait_frame")
	if error.is_empty() and (not frame is String or not FileAccess.file_exists(frame)):
		error = "cultivation portrait frame must exist"
	var window: Variant = raw.get("portrait_window")
	if error.is_empty():
		if not window is Array or window.size() != 4:
			error = "portrait window requires normalized x, y, width, height"
		else:
			for value in window:
				if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 1:
					error = "portrait window values must be between zero and one"
			if error.is_empty() and (window[2] <= 0 or window[3] <= 0 or window[0] + window[2] > 1 or window[1] + window[3] > 1):
				error = "portrait window must fit within frame"
	if not error.is_empty():
		return _reject(raw, error)
	_cultivation[raw["id"]] = raw.duplicate(true)
	return true

func register_board(raw: Dictionary) -> bool:
	var error := _validate_identity(raw)
	if error.is_empty() and not BoardLayout.validate(raw):
		error = "board requires source dimensions and five increasing grid lines per axis"
	if not error.is_empty():
		return _reject(raw, error)
	_boards[raw["id"]] = BoardLayout.new(raw)
	return true

func register_character(raw: Dictionary) -> bool:
	var error := _validate_identity(raw)
	if error.is_empty():
		if not _positive_integer(raw.get("max_hp")):
			error = "max_hp must be a positive integer"
		for stat in ["max_stamina", "max_spirit"]:
			if not _nonnegative_integer(raw.get(stat)):
				error = stat + " must be a nonnegative integer"
		for field in ["cultivation_rank", "portrait"]:
			if not raw.get(field) is String or str(raw[field]).strip_edges().is_empty():
				error = field + " must be a nonempty string"
	if not error.is_empty():
		return _reject(raw, error)
	var traits: Variant = raw.get("traits", [])
	if not traits is Array or traits.size() > 2:
		return _reject(raw, "companions allow at most two trait slots")
	for trait_id in traits:
		if not trait_id is String:
			return _reject(raw, "trait references must be strings")
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
		var rotates := false
		for effect in raw["effects"]:
			if effect is Dictionary and effect.get("trigger") == "on_activate":
				rotates = true
		if not rotates:
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
	if error.is_empty() and not _nonnegative_integer(raw.get("defense", 0)):
		error = "defense must be a nonnegative integer"
	if error.is_empty() and not _nonnegative_integer(raw.get("uses_per_unit", 0)):
		error = "uses_per_unit must be a nonnegative integer"
	if error.is_empty() and raw.get("category", raw["type"]) not in ["weapon", "armor", "pill", "item", "talisman"]:
		error = "unsupported category"
	if error.is_empty() and not raw.get("quality", "凡品") is String:
		error = "quality must be a string"
	if error.is_empty():
		for effect in raw["effects"]:
			if not effect is Dictionary or not EffectSystem.validate_definition(effect):
				error = "unsupported or invalid effect"
				break
			if effect.get("effect") == "restore_over_time" and (int(raw.get("uses_per_unit", 0)) <= 0 or raw["effects"].size() != 1):
				error = "restoration requires a consumable with one effect"
		if error.is_empty() and int(raw.get("uses_per_unit", 0)) > 0 and (raw["effects"].size() != 1 or raw["effects"][0].get("effect") != "restore_over_time"):
			error = "current consumables must use one restoration effect"
	if not error.is_empty():
		return _reject(raw, error)
	if raw.get("element", "base.element.none") != "base.element.none" and not _elements.has(raw.get("element")):
		return _reject(raw, "unknown item element")
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
	if _elements.has(raw["id"]) or _traits.has(raw["id"]) or _items.has(raw["id"]) or _enemies.has(raw["id"]) or _characters.has(raw["id"]) or _boards.has(raw["id"]) or _cultivation.has(raw["id"]):
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
		if kind == "element":
			register_element(json.data)
		elif kind == "trait":
			register_trait(json.data)
		elif kind == "item":
			register_item(json.data)
		elif kind == "character":
			register_character(json.data)
		elif kind == "board":
			register_board(json.data)
		elif kind == "cultivation":
			register_cultivation(json.data)
		else:
			register_enemy(json.data)
