class_name LegacyCombatFixture
extends RefCounted

# Retain the historical V0.10 regression baseline explicitly. Real scenes use
# ContentRegistry and the default consumable-armor simulation, never this file.
class LegacyRegistry extends ContentRegistry:
	func load_base_content() -> bool:
		if not super.load_base_content():
			return false
		# Historical combat fixtures predate board resource bonuses.
		for board in _boards.values():
			board.resource_bonuses.clear()
		_traits.erase("base.trait.ward")
		return register_trait({"id": "base.trait.ward", "name": "护元", "kind": "passive", "cooldown": 0, "element": "base.element.earth", "effect": "defense", "value": 1, "description": "历史测试：为主角提供1点防御。"})

static func registry() -> ContentRegistry:
	return LegacyRegistry.new()

static func battle(allies: Array, enemies: Array, content: ContentRegistry, allies_support: Array = [], enemies_support: Array = []) -> BattleSimulation:
	return BattleSimulation.new(allies, enemies, content, allies_support, enemies_support, true)

static func configure(game: GameManager) -> void:
	game.registry = registry()
	game.use_saved_loadout = false
	game.legacy_fixed_defense = true

static func game() -> GameManager:
	var instance := GameManager.new()
	configure(instance)
	return instance
