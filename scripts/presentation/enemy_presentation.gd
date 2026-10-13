class_name EnemyPresentation
extends RefCounted

# Enemy-owned presentation. Encounter records describe the location and trigger only.
static func validation_error(value: Variant, require_art: bool = true) -> String:
	if not value is Dictionary: return "enemy presentation must be an object"
	for key in ["rank_label", "category_label", "description"]:
		if not value.get(key) is String or value[key].strip_edges().is_empty():
			return "enemy presentation missing " + key
	if not value.get("battle_background") is String: return "enemy background must be a path string"
	if (require_art or not value.battle_background.is_empty()) and not ResourceLoader.exists(value.battle_background, "Texture2D"):
		return "enemy battle background does not exist"
	var alignment: Variant = value.get("preview_alignment", [0.5, 0.5])
	if not alignment is Array or alignment.size() != 2:
		return "enemy preview alignment requires two normalized coordinates"
	for coordinate: Variant in alignment:
		if not (coordinate is int or coordinate is float) or not is_finite(coordinate) or coordinate < 0 or coordinate > 1:
			return "enemy preview alignment must be between zero and one"
	if not value.get("summary") is Array: return "enemy summary must be an array"
	var traits: Variant = value.get("traits", [])
	if not traits is Array or traits.size() > 2: return "enemy traits require at most two labels"
	for caption: Variant in traits:
		if not caption is String or caption.strip_edges().is_empty(): return "invalid enemy trait"
	for row: Variant in value.summary:
		if not row is Dictionary or not row.get("label") is String or row.label.strip_edges().is_empty():
			return "invalid enemy summary label"
		if not row.get("icon") is String or not ResourceLoader.exists(row.icon, "Texture2D"):
			return "invalid enemy summary icon"
		if row.has("stat"):
			if row.stat not in ["hp", "stamina", "spirit", "resources", "armor"] or row.has("value"):
				return "enemy summary stat must be known and cannot duplicate a value"
		elif not row.get("value") is String or row.value.strip_edges().is_empty():
			return "enemy summary requires a stat or descriptive value"
	return ""

static func background_path(enemy: Dictionary) -> String:
	return enemy.get("presentation", {}).get("battle_background", "")

static func preview_alignment(enemy: Dictionary) -> Vector2:
	var coordinates: Array = enemy.get("presentation", {}).get("preview_alignment", [0.5, 0.5])
	return Vector2(coordinates[0], coordinates[1])

static func summary_rows(enemy: PartyMemberState) -> Array:
	var rows: Array = enemy.definition.get("presentation", {}).get("summary", []).duplicate(true)
	for row: Dictionary in rows:
		match row.get("stat", ""):
			"hp", "stamina", "spirit": row.value = str(enemy.maximum(row.stat))
			"resources": row.value = "%s / %s" % [enemy.maximum("hp"), enemy.maximum("stamina")]
			"armor": row.value = enemy.armor_type
	return rows
