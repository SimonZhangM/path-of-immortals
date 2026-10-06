class_name MapItemQuality
extends RefCounted

# Authored rarity order; independent of item enhancement level.
const QUALITIES := ["下品", "凡品", "良品", "上品", "灵品", "玄品", "仙品"]
const COLORS := [Color("a5a5a5"), Color("51b879"), Color("3296ed"), Color("ed8b28"), Color("b65cde"), Color("e9bd47"), Color("e33d3d")]
const UNKNOWN_DESCRIPTION := "此物灵机深藏，你的修为尚不足以参透，暂不可使用。待境界提升后再行探究。"

static func level(quality: String) -> int:
	return QUALITIES.find(quality) + 1

static func usable(quality: String, cultivation: Dictionary) -> bool:
	var item_level := level(quality)
	return item_level > 0 and not cultivation.is_empty() and item_level <= int(cultivation.get("order", -2)) + 2

static func index(quality: String) -> int:
	return maxi(0, QUALITIES.find(quality))

static func background_path(quality: String) -> String:
	return "res://assets/level-%d.webp" % (index(quality) + 1)

# Enemy realm starts at mortal (order 0), which maps to 下品, not 凡品.
# An authored quality is an explicit exception to the source-based default.
static func material_record(raw: Dictionary, registry: ContentRegistry) -> Dictionary:
	var record := raw.duplicate(true)
	if not record.has("quality"):
		var enemy := registry.get_enemy(record.get("source_enemy_id", ""))
		var realm := registry.get_cultivation(enemy.get("cultivation_rank", ""))
		if realm.is_empty(): return {}
		var order := int(realm.order)
		if order < 0 or order >= QUALITIES.size(): return {}
		record.quality = QUALITIES[order]
	if level(record.quality) == 0: return {}
	record.card_frame = background_path(record.quality)
	return record

static func color(quality: String) -> Color:
	return COLORS[index(quality)]
