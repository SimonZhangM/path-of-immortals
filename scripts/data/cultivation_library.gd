class_name CultivationLibrary
extends RefCounted

const OPCODES := ["attack", "sword_screen", "enchant", "command_weapon", "weapon_barrier", "weapon_union", "heal", "status", "guard_critical", "force_critical", "tax_cast", "armor_counter", "dodge", "followup", "change_cd", "thunder_counter"]
var books: Dictionary = {}
var book_items: Dictionary = {}
var spells: Dictionary = {}
var spell_items: Dictionary = {}
var spell_presentations: Dictionary = {}
var error := ""

func load_catalog(registry: ContentRegistry) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cultivation_library.json"))
	if not parsed is Dictionary or parsed.get("version") != 1:
		error = "Invalid cultivation library"
		return false
	var presentations: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_item_presentations.json"))
	var book_art: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_book_art.json"))
	spell_presentations = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/spell_presentations.json"))
	if spell_presentations.size() != parsed.spells.size():
		error = "Incomplete spell presentations"
		return false
	if not presentations is Dictionary or not book_art is Dictionary or presentations.size() != parsed.books.size():
		error = "Invalid cultivation book presentations"
		return false
	for book: Dictionary in parsed.books:
		if books.has(book.id) or int(book.max_level) not in [5, 8]:
			error = "Invalid/duplicate book: " + str(book.id)
			return false
		var presentation: Variant = presentations.get(book.id)
		var icon: Variant = book_art.get(book.id)
		if not _valid_presentation(book, presentation, icon):
			error = "Invalid cultivation book presentation: " + str(book.id)
			return false
		books[book.id] = book.duplicate(true)
		var record := item_record(book, false)
		record.icon = icon
		record.tags = ["功法", "书籍"] + presentation.tags
		record.combat.flavor_description = presentation.flavor_description
		record.combat.description = presentation.description
		if not registry.register_item(record): return false
		book_items[book.id] = registry.get_item(book.id)
	for spell: Dictionary in parsed.spells:
		if not validate_spell(spell) or spells.has(spell.id) or spell.opcode not in OPCODES or not books.has(spell.book_id) or int(spell.learned_at_book_level) not in [1, 3, 5, 7]:
			error = "Unsupported spell definition: " + str(spell.id)
			return false
		spells[spell.id] = spell.duplicate(true)
		var presentation: Dictionary = spell_presentations.get(spell.id, {})
		if presentation.is_empty() or not ResourceLoader.exists(presentation.icon) or not ResourceLoader.exists(presentation.frame):
			error = "Missing spell artwork: " + str(spell.id)
			return false
		var record := item_record(spell, true)
		record.icon = presentation.icon
		record.quality = presentation.quality
		record.tags = ["功法", "法术", str(presentations[spell.book_id].tags[0])]
		record.combat.presentation = presentation.duplicate(true)
		if not registry.register_item(record): return false
		spell_items[spell.id] = registry.get_item(spell.id)
	return true

static func _valid_presentation(book: Dictionary, presentation: Variant, icon: Variant) -> bool:
	if not presentation is Dictionary or presentation.get("name") != book.name: return false
	if not icon is String or not icon.ends_with("-booksimple.webp") or not ResourceLoader.exists(icon): return false
	var tags: Variant = presentation.get("tags")
	if not tags is Array or tags.size() != 2: return false
	var element_names := {"metal":"金系", "wood":"木系", "water":"水系", "fire":"火系", "earth":"土系", "wind":"风系", "thunder":"雷系"}
	if tags[0] != element_names.get(book.element) or tags[1] not in ["技艺", "总纲", "状态", "战斗"]: return false
	for field: String in ["flavor_description", "description"]:
		if not presentation.get(field) is String or presentation[field].strip_edges().is_empty(): return false
	return true

static func item_record(data: Dictionary, spell: bool) -> Dictionary:
	var combat := data.duplicate(true)
	combat.source_location = str(data.source.path) + ":" + str(data.source.line)
	combat.hit_chance = 0.95
	var dimensions: Array = data.get("size", [int(data.cells), 1]) if spell else [int(data.cells), 1]
	return {"id": data.id, "name": data.name, "type": "spell" if spell else "book", "category": "spell" if spell else "book", "quality": "", "tags": [], "size": dimensions.duplicate(), "icon": "", "cooldown": data.cooldown if spell else 0, "stamina_cost": 0, "spirit_cost": data.spirit_cost if spell else 0, "element": "base.element." + data.element, "rule_version": 1, "combat": combat, "effects": [{"trigger": "on_activate", "effect": "cast_spell", "opcode": data.opcode}] if spell else []}

func inventory_records() -> Array[Dictionary]:
	# Physical inventory views reuse registered book identity and presentation.
	# Ownership is granted explicitly, never replenished by opening a screen.
	var result: Array[Dictionary] = []
	for item: ItemData in book_items.values():
		result.append({"id": item.id, "name": item.display_name, "category": "book", "quality": item.quality,
			"element": item.element, "tags": item.tags.duplicate(), "icon": item.icon_path,
			"card_frame": "",
			"footprint_columns": item.grid_size.x, "footprint_rows": item.grid_size.y,
			"cooldown": 0, "effects": [], "rule_version": 1,
			"quantity": 1, "acquired_at": 20261019, "enhancement_level": 0, "grant_on_start": false})
	for item: ItemData in spell_items.values():
		result.append({"id":item.id,"name":item.display_name,"category":"spell","quality":item.quality,
			"element":item.element,"tags":item.tags.duplicate(),"icon":item.icon_path,"card_frame":MapItemQuality.background_path(item.quality),
			"footprint_columns":item.grid_size.x,"footprint_rows":item.grid_size.y,"cooldown":item.cooldown_usec/1000000.0,
			"effects":item.effects.duplicate(true),"rule_version":1,"quantity":1,"acquired_at":20261019,"enhancement_level":0,"grant_on_start":false})
	return result

func resolved(member: PartyMemberState, id: String) -> Dictionary:
	if not spells.has(id): return {}
	return resolve_spell(spells[id], member.knowledge)

static func resolve_spell(definition: Dictionary, knowledge: CultivationKnowledge) -> Dictionary:
	var result := definition.duplicate(true)
	var branch := knowledge.branch(result.book_id, int(result.learned_at_book_level) + 1)
	result.merge(result.branches.get(branch, {}), true)
	result.selected_branch = branch
	return result

func branch_key(book_id: String, choice: String) -> String:
	# Scope aliases to their book; shared names in other elements are unchanged.
	var names: Dictionary = books.get(book_id, {}).get("branch_display_names", {})
	for key: String in names:
		if names[key] == choice: return key
	return choice

func branch_display_name(book_id: String, choice: String) -> String:
	return str(books.get(book_id, {}).get("branch_display_names", {}).get(choice, choice))

func branch_unavailable_reason(book_id: String, stage: int, choice: String) -> String:
	choice = branch_key(book_id, choice)
	if not books.has(book_id) or choice not in books[book_id].branches.get(str(stage), []):
		return "该重没有此分支"
	if books[book_id].get("deferred_branches", {}).has(choice):
		return "连携系统开放后可用；当前仅可预览，可保留待选并继续修习后续重数"
	return ""


static func validate_spell(raw: Dictionary, branch := false) -> bool:
	# A learned branch changes effects, never the spell's fixed board footprint.
	if branch and (raw.has("size") or raw.has("cells")): return false
	var allowed := "absorption advance_cd agility armor_bonus armor_only bleed blunt_critical blunt_pct book_id branches burst_armor_only burst_pct burst_ratio burst_status cd_pct cells chain_bonus cooldown core_references cost_pct counter counter_bonus damage damage_layers damage_pct deferred delay_cd dispel_bonus drain_return drain_spirit element extra_chain followup_bonus followup_hit freeze_extra heal heal_pct hit_bonus icon id injury layer_cap layer_ratio learned_at_book_level life_per_hp main_ratio missing_scale name opcode other_ratio paralysis_extension pierce_bonus poison_entangle prepared race_bonus ratio reduction refresh_fire return_edge return_resources root shield source spirit_cost statuses strike_bonus surcharge tenacity weapon_pct wither_resource".split(" ")
	for key: String in raw:
		if key not in allowed and key != "size": return false
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
		if not ContentRegistry._positive_integer(raw.get("cells")) or int(raw.cells) not in [1,2]: return false
		if not raw.get("spirit_cost") is float and not raw.get("spirit_cost") is int: return false
		var dimensions: Variant = raw.get("size", [int(raw.cells), 1])
		if not dimensions is Array or dimensions.size() != 2: return false
		if not ContentRegistry._positive_integer(dimensions[0]) or not ContentRegistry._positive_integer(dimensions[1]): return false
		if dimensions[0] * dimensions[1] != raw.cells: return false
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
