extends SceneTree

var checks := 0
var failures := 0
const CLOTH := "base.map_item.coarse_cloth_armor"
const HELMET := "base.map_item.old_iron_helmet"
const SHIELD := "base.map_item.round_wood_shield"
const SWORD := "base.map_item.qingshi_short_sword"

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _fixture(support := false, weapon := true) -> Dictionary:
	var registry := ContentRegistry.new()
	_check(registry.load_base_content(), "base content loads")
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	_check(created.error.is_empty(), "six canonical items register")
	var hero := PartyMemberState.new(registry.get_character(GameManager.PARTY_IDS[0]), registry)
	var dog := PartyMemberState.new(registry.get_enemy(GameManager.ENEMY_ID), registry)
	dog.hp = 1000
	hero.inventory.add_item("cloth", CLOTH, Vector2i(0, 0))
	hero.inventory.add_item("helmet", HELMET, Vector2i(0, 2))
	hero.inventory.add_item("shield", SHIELD, Vector2i(1, 0))
	if weapon:
		hero.inventory.add_item("sword", SWORD, Vector2i(2, 0))
	var companions: Array = []
	if support:
		var companion_data := registry.get_character(GameManager.PARTY_IDS[1])
		companion_data.traits = ["base.trait.ward"]
		companions.append(CompanionState.new(companion_data, registry))
	var battle := BattleSimulation.new([hero], [dog], registry, companions)
	return {"registry": registry, "hero": hero, "dog": dog, "battle": battle, "loadout": created.state}

func _hit(fixture: Dictionary, amount: int) -> Dictionary:
	return EffectSystem.new().apply({"trigger": "on_activate", "effect": "damage", "value": amount}, fixture.battle.state, fixture.hero, fixture.battle.state.time_usec, {"side": 1, "owner_name": "测试目标", "item_id": GameManager.CLAW_ID, "stamina_cost": 0})

func _run() -> void:
	var f := _fixture()
	var hero: PartyMemberState = f.hero
	var battle: BattleSimulation = f.battle
	_check(hero.maximum("armor") == 11 and hero.armor == 0, "caps sum to11 without granting starting armor")
	_check(hero.armor_type == "轻甲" and f.registry.get_item(HELMET).armor_type.is_empty() and f.registry.get_item(SHIELD).armor_type.is_empty(), "only clothes define armor type")
	battle.start()
	battle.advance(3.999)
	_check(hero.armor == 0, "first gain waits a full4s")
	battle.advance(0.001)
	_check(hero.armor == 3, "cloth grants3 armor at4s")
	battle.advance(1)
	_check(hero.armor == 7, "helmet1 plus shield3 at5s")
	_check(hero.stamina == 47, "armor gains do not consume stamina; only sword did")
	battle.advance(11)
	_check(hero.armor == 11, "repeated gains cap at11")
	hero.defense_sources["obsolete"] = 100
	var hit := _hit(f, 5)
	_check(hero.armor == 6 and hero.hp == 50 and hit.armor_absorbed == 5, "attack consumes5 armor and preserves remainder, no fixed reduction")
	hit = _hit(f, 10)
	_check(hero.armor == 0 and hero.hp == 46 and hit.value == 4, "overflow subtracts HP only after armor empties")
	hit = _hit(f, 5)
	_check(hero.hp == 41 and hit.value == 5, "empty armor provides no fixed mitigation even with obsolete defense source")
	var restore := EffectSystem.new().restore(hero, "armor", 99, 0, {})
	_check(restore.value == 11 and hero.armor == 11, "restore reports actual capped gain")
	battle.detach("cloth")
	var cloth := hero.inventory.take("cloth")
	_check(hero.maximum("armor") == 4 and hero.armor == 4 and hero.armor_type == "无甲", "remove body armor clamps current value and clears armor type")
	hero.inventory.put(cloth, Vector2i.ZERO)
	battle.attach(hero, 0, "cloth", true)
	_check(hero.maximum("armor") == 11 and hero.armor == 4, "reinsert cap does not grant free armor")
	battle.advance(6.999)
	_check(battle.state.item_runtime.cloth.activation_count == 0, "battle insertion waits3s plus full4s rotation")
	battle.advance(0.001)
	_check(battle.state.item_runtime.cloth.activation_count == 1, "reinserted armor activates after7s")
	var old_activation: int = battle.state.item_runtime.shield.activation_count
	var old_due: int = battle.state.item_runtime.shield.next_activation_usec
	_check(hero.inventory.move_item("shield", Vector2i(1, 1)), "armor can be rearranged within board")
	_check(battle.state.item_runtime.shield.activation_count == old_activation and battle.state.item_runtime.shield.next_activation_usec == old_due, "moving does not reset armor cooldown")
	battle.clock.paused = true
	var before := hero.armor
	battle.advance(10)
	_check(hero.armor == before, "pause freezes armor rotation")
	var guarded := _fixture(true)
	guarded.battle.start()
	guarded.battle.advance(5)
	_check(guarded.hero.armor == 9 and guarded.hero.maximum("armor") == 11, "ward grants2 at5s with no cap bonus")
	var trait_data: Dictionary = guarded.registry.get_trait("base.trait.ward")
	_check(trait_data.kind == "active" and trait_data.cooldown == 5 and trait_data.effect == "restore_armor" and trait_data.value == 2, "actual ward definition matches user instruction")
	var peaceful := _fixture(true, false)
	peaceful.battle.start()
	_check(peaceful.battle.state.result == "draw", "armor and armor-only support cannot cause infinite peaceful combat")
	# An old weapon-only version1 save preserves positions and gains new starter gear.
	var state: MapLoadoutState = f.loadout
	var old := {"version": 1, "board_id": "base.board.bag", "placements": [{"instance_id": "owned." + SWORD + ".0", "item_id": SWORD, "cell": [2, 0]}]}
	_check(state.restore(old).is_empty() and state.storage.entries().size() == 5 and state.inventory.get_instances()[0].cell == Vector2i(2, 0), "old save retains sword and adds three new armor pieces to storage")
	for entry in state.storage.entries():
		if entry.item_id == HELMET:
			_check(state.place(state.drag_data("storage", entry.instance_id), Vector2i(2, 2)), "1x1 helmet fits last free row")
	var saved := state.snapshot()
	var other: MapLoadoutState = _fixture().loadout
	_check(other.restore(saved).is_empty() and other.snapshot() == saved, "armor placement round-trips through versioned snapshot")
	var invalid := {"id": "test.invalid.helmet", "name": "错误甲型", "type": "armor", "tags": [], "effects": [], "cooldown": 0, "size": [1, 1], "armor_slot": "头盔", "armor_type": "轻甲"}
	_check(not f.registry.register_item(invalid), "helmet cannot carry an armor type")
	print("ARMOR POOL RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
