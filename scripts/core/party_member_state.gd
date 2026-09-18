class_name PartyMemberState
extends RefCounted

var id: String
var definition: Dictionary
var inventory: InventoryState
var hp: int
var stamina: int
var spirit: int
var armor: int = 0
var armor_capacity_sources: Dictionary = {}
var armor_type_sources: Dictionary = {}
var armor_type: String:
	get:
		return "无甲" if armor_type_sources.is_empty() else String(armor_type_sources.values()[0])
var cultivation_rank_id: String = ""
var _registry: ContentRegistry
var cultivation: Dictionary:
	get:
		return _registry.get_cultivation(cultivation_rank_id)
var max_hp_sources: Dictionary = {}
var defense_sources: Dictionary = {}
var defense: int:
	get:
		var total := 0
		for value in defense_sources.values():
			total += int(value)
		return total

func _init(raw: Dictionary, registry: ContentRegistry) -> void:
	_registry = registry
	definition = raw.duplicate(true)
	cultivation_rank_id = raw.get("cultivation_rank", "")
	id = raw["id"]
	var board := registry.get_board(raw.get("board_layout", ""))
	inventory = InventoryState.new(registry, board.grid_size if board != null else BoardLayout.plain().grid_size)
	reset_resources()

func set_cultivation_rank(rank_id: String) -> bool:
	if _registry.get_cultivation(rank_id).is_empty():
		return false
	cultivation_rank_id = rank_id
	return true

func maximum(resource: String) -> int:
	if resource == "armor":
		var total := 0
		for bonus in armor_capacity_sources.values():
			total += int(bonus)
		return total
	var value := int(definition["max_" + resource])
	if resource == "hp":
		for bonus in max_hp_sources.values():
			value += int(bonus)
	return value

func reset_resources() -> void:
	max_hp_sources.clear()
	defense_sources.clear()
	armor_capacity_sources.clear()
	armor_type_sources.clear()
	armor = 0
	hp = int(definition["max_hp"])
	stamina = int(definition["max_stamina"])
	spirit = int(definition["max_spirit"])

func remove_armor_source(source_id: String) -> void:
	armor_capacity_sources.erase(source_id)
	armor_type_sources.erase(source_id)
	armor = mini(armor, maximum("armor"))
