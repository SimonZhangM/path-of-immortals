class_name PartyMemberState
extends RefCounted

var id: String
var definition: Dictionary
var inventory: InventoryState
var hp: int
var stamina: int
var spirit: int
var defense_sources: Dictionary = {}
var defense: int:
	get:
		var total := 0
		for value in defense_sources.values():
			total += int(value)
		return total

func _init(raw: Dictionary, registry: ContentRegistry) -> void:
	definition = raw.duplicate(true)
	id = raw["id"]
	inventory = InventoryState.new(registry)
	reset_resources()

func reset_resources() -> void:
	defense_sources.clear()
	hp = int(definition["max_hp"])
	stamina = int(definition["max_stamina"])
	spirit = int(definition["max_spirit"])
