class_name CompanionState
extends RefCounted

var id: String
var definition: Dictionary
var traits: Array[Dictionary] = []
var cultivation_rank_id: String
var _registry: ContentRegistry
var cultivation: Dictionary:
	get:
		return _registry.get_cultivation(cultivation_rank_id)

func _init(raw: Dictionary, registry: ContentRegistry) -> void:
	_registry = registry
	definition = raw.duplicate(true)
	id = raw["id"]
	cultivation_rank_id = raw["cultivation_rank"]
	for trait_id in raw.get("traits", []):
		traits.append(registry.get_trait(trait_id))
