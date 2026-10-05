class_name CultivationLibrary
extends RefCounted

const OPCODES := ["attack", "sword_screen", "enchant", "command_weapon", "weapon_barrier", "weapon_union", "heal", "status", "guard_critical", "force_critical", "tax_cast", "armor_counter", "dodge", "followup", "change_cd", "thunder_counter"]
var books: Dictionary = {}
var spells: Dictionary = {}
var error := ""

func load_catalog(registry: ContentRegistry) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cultivation_library.json"))
	if not parsed is Dictionary or parsed.get("version") != 1:
		error = "Invalid cultivation library"
		return false
	for book: Dictionary in parsed.books:
		if books.has(book.id) or int(book.max_level) not in [5, 8]:
			error = "Invalid/duplicate book: " + str(book.id)
			return false
		books[book.id] = book.duplicate(true)
		if not registry.register_item(item_record(book, false)): return false
	for spell: Dictionary in parsed.spells:
		if not validate_spell(spell) or spells.has(spell.id) or spell.opcode not in OPCODES or not books.has(spell.book_id) or int(spell.learned_at_book_level) not in [1, 3, 5, 7]:
			error = "Unsupported spell definition: " + str(spell.id)
			return false
		spells[spell.id] = spell.duplicate(true)
		if not registry.register_item(item_record(spell, true)): return false
	return true

static func item_record(data: Dictionary, spell: bool) -> Dictionary:
	var combat := data.duplicate(true)
	combat.source_location = str(data.source.path) + ":" + str(data.source.line)
	combat.hit_chance = 0.95
	return {"id": data.id, "name": data.name, "type": "spell" if spell else "book", "category": "spell" if spell else "book", "quality": "", "tags": [], "size": [int(data.cells), 1], "icon": "", "cooldown": data.cooldown if spell else 0, "stamina_cost": 0, "spirit_cost": data.spirit_cost if spell else 0, "element": "base.element." + data.element, "rule_version": 1, "combat": combat, "effects": [{"trigger": "on_activate", "effect": "cast_spell", "opcode": data.opcode}] if spell else []}

func resolved(member: PartyMemberState, id: String) -> Dictionary:
	if not spells.has(id): return {}
	var result: Dictionary = spells[id].duplicate(true)
	var branch := member.knowledge.branch(result.book_id, int(result.learned_at_book_level) + 1)
	result.merge(result.branches.get(branch, {}), true)
	return result


static func validate_spell(raw: Dictionary, branch := false) -> bool:
	var allowed := "absorption advance_cd agility armor_bonus armor_only bleed blunt_critical blunt_pct book_id branches burst_armor_only burst_pct burst_ratio burst_status cd_pct cells chain_bonus cooldown core_references cost_pct counter counter_bonus damage damage_layers damage_pct deferred delay_cd dispel_bonus drain_return drain_spirit element extra_chain followup_bonus followup_hit freeze_extra heal heal_pct hit_bonus icon id injury layer_cap layer_ratio learned_at_book_level life_per_hp main_ratio missing_scale name opcode other_ratio paralysis_extension pierce_bonus poison_entangle prepared race_bonus ratio reduction refresh_fire return_edge return_resources root shield source spirit_cost statuses strike_bonus surcharge tenacity weapon_pct wither_resource".split(" ")
	for key: String in raw:
		if key not in allowed: return false
		if raw[key] is float and not is_finite(raw[key]): return false
	var numeric := "absorption advance_cd agility armor_bonus armor_only bleed blunt_critical blunt_pct burst_pct burst_ratio cd_pct cells chain_bonus cooldown cost_pct counter counter_bonus damage damage_pct delay_cd dispel_bonus drain_return drain_spirit followup_bonus followup_hit freeze_extra heal heal_pct hit_bonus injury layer_cap layer_ratio learned_at_book_level life_per_hp main_ratio missing_scale other_ratio paralysis_extension pierce_bonus poison_entangle race_bonus ratio reduction root shield spirit_cost strike_bonus surcharge tenacity weapon_pct".split(" ")
	for key: String in numeric:
		if raw.has(key) and (not (raw[key] is float or raw[key] is int) or not is_finite(float(raw[key]))): return false
		if raw.has(key) and key not in ["cd_pct","cost_pct","damage_pct","heal_pct"] and raw[key] < 0: return false
	if raw.get("cd_pct",0) <= -1 or raw.get("cost_pct",0) < -1: return false
	if raw.get("absorption",0) > 1: return false
	for key: String in ["prepared","return_edge","extra_chain","burst_armor_only","refresh_fire","return_resources"]:
		if raw.has(key) and not raw[key] is bool: return false
	if raw.has("opcode") and raw.opcode not in OPCODES: return false
	if not branch and (not ContentRegistry._positive_number(raw.get("cooldown")) or not ContentRegistry._nonnegative_integer(raw.get("damage"))): return false
	if not branch:
		for key: String in ["id","name","book_id","element","opcode"]:
			if not raw.get(key) is String or raw[key].is_empty(): return false
		if not raw.id.begins_with("base.spell.") or raw.element not in T01Definition.STATUS_GROUPS: return false
		if int(raw.get("cells",0)) not in [1,2] or not raw.get("spirit_cost") is float and not raw.get("spirit_cost") is int: return false
		if not raw.get("source") is Dictionary or not raw.source.get("path") is String or not ContentRegistry._positive_integer(raw.source.get("line")): return false
	if raw.has("statuses") and not raw.statuses is Array: return false
	if raw.has("branches") and not raw.branches is Dictionary: return false
	for effect: Variant in raw.get("statuses",[]):
		if not effect is Dictionary: return false
		for key: String in effect:
			if key not in ["status","count","gate","target"]: return false
		if T01Definition.status_element(effect.get("status","")).is_empty() or not ContentRegistry._positive_integer(effect.get("count")) or effect.get("gate") not in ["always","hit","hp_damage","armor_damage"] or effect.get("target") not in ["self","enemy"]: return false
	for patch: Variant in raw.get("branches",{}).values():
		if not patch is Dictionary or not validate_spell(patch,true): return false
	return true
