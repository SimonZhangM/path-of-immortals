class_name PartyMemberState
extends RefCounted

var id: String
var definition: Dictionary
var inventory: InventoryState
var board: BoardLayout
var hp: float
var stamina: int
var spirit: int
var armor: float = 0.0
var toxin_stacks: int = 0
var toxin_immune_until_usec: int = 0
var toxin_next_tick_usec: int = 0
var toxin_version: int = 0
var toxin_source: Dictionary = {}
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
	board = registry.get_board(raw.get("board_layout", ""))
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
	var value := int(definition["max_" + resource]) + (board.resource_bonus(resource) if board != null else 0)
	if resource == "hp":
		for bonus in max_hp_sources.values():
			value += int(bonus)
	return value

func reset_resources() -> void:
	toxin_stacks = 0
	toxin_immune_until_usec = 0
	toxin_next_tick_usec = 0
	toxin_version += 1
	toxin_source.clear()
	max_hp_sources.clear()
	defense_sources.clear()
	armor_capacity_sources.clear()
	armor_type_sources.clear()
	armor = 0
	hp = maximum("hp")
	stamina = maximum("stamina")
	spirit = maximum("spirit")

func remove_armor_source(source_id: String) -> void:
	armor_capacity_sources.erase(source_id)
	armor_type_sources.erase(source_id)
	armor = minf(armor, maximum("armor"))

# 毒蚀 applications go through this gate; immunity uses combat time, not wall time.
func apply_toxin(stacks: int, at_usec: int, source: Dictionary = {}) -> bool:
	if stacks <= 0 or hp <= 0 or at_usec < toxin_immune_until_usec:
		return false
	if toxin_stacks == 0:
		toxin_version += 1
		toxin_next_tick_usec = at_usec + 2_000_000
	toxin_stacks += stacks
	if not source.is_empty():
		toxin_source = source.duplicate()
	return true

func can_use_item(item: ItemData) -> bool:
	# Creatures without cultivation use innate attacks, not player equipment ranks.
	return item != null and (cultivation_rank_id.is_empty() or MapItemQuality.usable(item.quality, cultivation))

func cleanse_toxin(at_usec: int, immunity_usec: int) -> void:
	toxin_stacks = 0
	toxin_next_tick_usec = 0
	toxin_version += 1
	toxin_source.clear()
	toxin_immune_until_usec = maxi(toxin_immune_until_usec, at_usec + immunity_usec)
