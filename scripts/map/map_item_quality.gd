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

static func color(quality: String) -> Color:
	return COLORS[index(quality)]
