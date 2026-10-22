class_name CultivationGrowth
extends RefCounted

const PATH := "res://data/cultivation_growth.json"
const ELEMENTS := ["metal", "wood", "water", "fire", "earth", "wind", "thunder"]
const RESOURCE_KEYS := ["hp", "stamina", "spirit"]
static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty(): _rules = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _rules

static func cents(value: float) -> int:
	return floori(maxf(0, value) * 100.0 + 0.50000001)

static func quantize(value: float) -> float:
	return cents(value) / 100.0

static func display(value: float) -> String:
	var tenths := int((cents(value) + 5) / 10)
	return "%d.%d" % [tenths / 10, tenths % 10]

static func initial(realm: int) -> Dictionary:
	return {"version":1, "realm":realm, "layer":1, "progress":0, "roots":rules().initial_roots.duplicate(), "resources":{}, "day_usec":0, "budget":0, "day_paid":false, "breakthrough_serial":0}

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	if raw.is_empty(): return true
	for key in ["realm", "layer", "progress", "day_usec", "budget", "breakthrough_serial"]:
		if not raw.has(key) or not WorldCalendar.integer_between(raw[key],0,100000000000): return false
	if raw.get("version") != 1 or raw.realm > 5 or raw.layer < 1 or raw.layer > 10 or raw.day_usec >= 60000000: return false
	if raw.realm==0 and raw.layer!=1: return false
	if not WorldCalendar.integer_between(raw.get("experience",0),0,100000000000): return false
	if not raw.get("day_paid") is bool or not raw.get("resources") is Dictionary or not raw.get("roots") is Array: return false
	var seen := {}
	for element: Variant in raw.roots:
		if element not in ELEMENTS or seen.has(element): return false
		seen[element] = true
	for key: Variant in raw.resources:
		if key not in RESOURCE_KEYS or not WorldCalendar.integer_between(raw.resources[key],0,1000000000): return false
	return int(raw.progress) <= target(raw)

static func rank_id(growth: Dictionary) -> String:
	return "base.cultivation." + str(rules().realms[int(growth.realm)].id)

# Explicit modifier boundary for future verified pill/effect contributions.
# Values are fractions (0.20 adds twenty percentage points), not multipliers.
static func breakthrough_chance(growth: Dictionary, bonus: float = 0.0) -> float:
	if int(growth.realm)==0: return 1.0
	return clampf(float(rules().realms[int(growth.realm)].chance)+bonus,0.0,1.0)

static func maxima(growth: Dictionary) -> Dictionary:
	var definition: Dictionary = rules().realms[int(growth.realm)]
	var result := {}
	for i in 3: result[RESOURCE_KEYS[i]] = int(definition.base[i]) + (int(growth.layer)-1)*int(definition.step[i])
	return result

static func target(growth: Dictionary) -> int:
	var realm := int(growth.realm)
	var layer := int(growth.layer)
	var definition: Dictionary = rules().realms[realm]
	if realm == 0 or layer == 10: return cents(float(definition.breakthrough))
	return cents(float(definition.upgrade) * float(rules().step_weights[layer-1]))

# Returns the amount actually credited, including steps crossed this command.
static func award(growth: Dictionary, amount: int) -> int:
	var left := maxi(0, amount)
	var before := maxima(growth)
	while left > 0 and target(growth) > 0:
		var accepted := mini(left, target(growth) - int(growth.progress))
		growth.progress = int(growth.progress) + accepted
		left -= accepted
		if int(growth.progress) < target(growth) or int(growth.realm) == 0 or int(growth.layer) == 10: break
		growth.layer = int(growth.layer)+1
		growth.progress = 0
	var after := maxima(growth)
	for key: String in growth.resources:
		growth.resources[key] = int(growth.resources[key]) + (int(after[key])-int(before[key]))*100
	return amount-left

static func book_target(library: CultivationLibrary, knowledge: CultivationKnowledge, book_id: String) -> int:
	if not library.books.has(book_id): return 0
	var book: Dictionary = library.books[book_id]
	var stage := knowledge.level(book_id)
	if stage >= int(book.max_level): return 0
	return cents(float(rules()["book_costs_%d" % int(book.max_level)][stage]))

static func book_error(growth: Dictionary, library: CultivationLibrary, knowledge: CultivationKnowledge, book_id: String) -> String:
	if not library.books.has(book_id): return "未知功法"
	var book: Dictionary = library.books[book_id]
	if str(book.element).trim_prefix("base.element.") not in growth.roots: return "缺少对应灵根"
	var next := knowledge.level(book_id)+1
	if next > int(book.max_level): return "功法已圆满"
	var required := ceili(next/2.0) if int(book.max_level)==8 else next
	return "尚未达到下一重境界" if int(growth.realm)<required else ""

static func award_book(growth: Dictionary, library: CultivationLibrary, knowledge: CultivationKnowledge, book_id: String, amount: int) -> int:
	var left := amount
	while left > 0 and book_error(growth,library,knowledge,book_id).is_empty():
		var required := book_target(library,knowledge,book_id)
		var current := cents(knowledge.practice_value(book_id))
		var accepted := mini(left,maxi(0,required-current))
		left -= accepted
		current += accepted
		knowledge.practice[book_id] = current/100.0
		if current < required: break
		if not knowledge.record_achievement(library,book_id,knowledge.level(book_id)+1,int(growth.realm)): break
		knowledge.practice[book_id] = 0.0
	if amount != left: knowledge.changed.emit()
	return amount-left
