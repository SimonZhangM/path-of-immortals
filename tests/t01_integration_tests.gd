extends SceneTree

var checks := 0
var failures: Array[String] = []
var registry := ContentRegistry.new()
var loadout: MapLoadoutState

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func _init() -> void:
	call_deferred("run")

func make_battle(item_id: String = "", more: Array = []) -> BattleSimulation:
	var raw := registry.get_character("base.character.chen_yu")
	raw.max_hp = 10000
	raw.max_stamina = 10000
	raw.max_spirit = 10000
	var player := PartyMemberState.new(raw, registry)
	if not item_id.is_empty():
		check(player.inventory.add_item("test.item", item_id, Vector2i.ZERO), "equip " + item_id)
	for row: Array in more:
		check(player.inventory.add_item(row[0], row[1], row[2]), "equip extra " + row[0])
	var enemy_raw := registry.get_enemy("base.enemy.wild_dog")
	enemy_raw.max_hp = 10000
	enemy_raw.max_stamina = 10000
	enemy_raw.max_spirit = 10000
	enemy_raw.combat_rank = 4
	var enemy := PartyMemberState.new(enemy_raw, registry)
	enemy.inventory.add_item("test.claw", "base.weapon.dog_claw", Vector2i.ZERO)
	var sim := BattleSimulation.new([player], [enemy], registry)
	check(sim.configuration_error.is_empty() and sim.t01 != null, "shared simulation configured")
	sim.t01.rng.seed = 7
	return sim

func run() -> void:
	check(registry.load_base_content(), "base registry: " + str(registry.errors))
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(created.error.is_empty(), "115 catalog/registry: " + created.error + str(registry.errors))
	if not created.error.is_empty():
		finish()
		return
	loadout = created.state
	check(loadout.records.size() == 115 and loadout.storage_records().size() == 115, "115 real inventory kinds")
	var empty_icons := 0
	var lower := 0
	for record: Dictionary in loadout.records.values():
		if record.icon.is_empty(): empty_icons += 1
		if record.quality == "下品": lower += 1
		var item := registry.get_item(record.id)
		check(item != null and item.effects == record.effects and item.element == record.element and item.spirit_cost == record.spirit_cost, "lossless mapping " + record.id)
		check(not ItemTooltip.effect_text(item).is_empty(), "tooltip " + record.id)
	check(empty_icons == 105 and lower == 27, "105 blank new images / 27 r1")
	check(not EffectSystem.validate_definition({"trigger":"on_activate", "effect":"unknown", "value":1}), "unknown effect rejected")
	check(not EffectSystem.validate_definition({"trigger":"on_activate", "effect":"apply_status", "status":"未知", "value":1,"target":"enemy","gate":"hit"}), "unknown status rejected")
	var invalid := T01Definition.item_record(loadout.records["base.map_item.qingshi_short_sword"])
	invalid.id = "test.invalid.missing_hit"
	invalid.combat.erase("hit_chance")
	check(not registry.register_item(invalid), "attack missing explicit hit template rejected before simulation")
	invalid = T01Definition.item_record(loadout.records["base.map_item.qingshi_short_sword"])
	invalid.id = "test.invalid.spirit_cost"
	invalid.spirit_cost = -1
	check(not registry.register_item(invalid), "negative spirit cost rejected before simulation")
	test_save()
	test_rules()
	test_status_timing()
	test_attack_boundaries()
	test_stacks_and_control()
	test_reactive_and_barrier()
	test_assets()
	finish()

func test_save() -> void:
	var old := {"version":1,"board_id":"base.board.bag","placements":[{"instance_id":"owned.base.map_item.qingshi_short_sword.0","item_id":"base.map_item.qingshi_short_sword","cell":[0,0]}], "granted_rewards":{"base.map_reward.test":{"item_id":"base.map_item.warm_jade","quantity":1}}}
	check(loadout.restore(old).is_empty(), "v1 restore")
	var current := loadout.snapshot()
	check(current.version == 2 and current.owned_units.size() == 116 and current.content_grants.get("t01.115.v1", false), "v1 migrates receipt / owned units, reward kept")
	check(loadout.restore(current).is_empty() and loadout.snapshot() == current, "v2 reload identical")
	var pill := "owned.base.map_item.hemostatic_pill.0"
	current.owned_units.erase(pill)
	check(loadout.restore(current).is_empty() and not loadout.snapshot().owned_units.has(pill), "consumed pill stays absent")
	check(loadout.restore(loadout.snapshot()).is_empty() and not loadout.snapshot().owned_units.has(pill), "repeated reload never regifts")
	var before := loadout.snapshot()
	check(loadout.add_reward({"id":"base.map_reward.new_test","item_id":"base.map_item.warm_jade","quantity":2}).is_empty(), "new reward transaction")
	check(loadout.snapshot().owned_units.size() == before.owned_units.size() + 2, "new reward units created once")
	check(loadout.add_reward({"id":"base.map_reward.new_test","item_id":"base.map_item.warm_jade","quantity":2}).is_empty(), "reward retry")
	check(loadout.snapshot().owned_units.size() == before.owned_units.size() + 2, "reward retry conserved")
	var file := "user://t01_test_isolated_inventory.json"
	check(MapLoadoutStore.save(loadout, file).is_empty(), "v2 atomic save")
	var registry2 := ContentRegistry.new()
	check(registry2.load_base_content(), "second registry")
	var state2: MapLoadoutState = MapLoadoutStore.create_state(registry2, registry2.get_board("base.board.bag")).state
	var disk_error := MapLoadoutStore.load_into(state2, file)
	check(disk_error.is_empty() and JSON.stringify(state2.snapshot()) == JSON.stringify(loadout.snapshot()), "disk roundtrip: " + disk_error)
	var v1_file := "user://t01_test_isolated_v1.json"
	var handle := FileAccess.open(v1_file,FileAccess.WRITE)
	handle.store_string(JSON.stringify(old))
	handle.close()
	check(MapLoadoutStore.load_into(state2,v1_file).is_empty(), "Windows v1 read handle closes before atomic migration")
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(v1_file))
	check(written.version == 2 and written.owned_units.size() == 116 and FileAccess.file_exists(v1_file+".bak"),"v1 migration persists receipt and backup")
	check(MapLoadoutStore.load_into(state2,v1_file).is_empty() and state2.snapshot().owned_units.size() == 116,"disk v1 retry cannot duplicate grant")

func test_rules() -> void:
	var sim := make_battle("base.map_item.qingshi_short_sword")
	var a: PartyMemberState = sim.state.teams[0][0]
	var b: PartyMemberState = sim.state.teams[1][0]
	var rules := sim.t01
	check(rules.q(0.15) == 0.2 and rules.q(0.25) == 0.3, "half up decimal ledger")
	b.barrier = 10
	var hit := rules.damage(a,b,0.15,"钝击","base.element.none",0,{"kind":"test"},false,{"special":false})
	check(hit.hp_loss == 0.1 and b.barrier == 9.9, "C10 packet quantization before shield")
	b.barrier = 0
	var hp_before := b.hp
	for component in 2:
		rules.damage(a,b,0.06,"钝击","base.element.none",0,{"kind":"test"},false,{"special":false})
	check(is_equal_approx(hp_before - b.hp, 0.2), "C10 independent0.06 packets each round to0.1")
	b.barrier = 10
	b.thunder_shields.assign([50.0,50.0])
	hit = rules.damage(a,b,100,"钝击","base.element.none",0,{"kind":"test"},false,{"special":true})
	check(b.thunder_shields == [40.0] and hit.hp_loss == 40 and b.barrier == 10, "C04 single 60% allowance")
	b.thunder_shields.clear()
	b.barrier = 0
	a.set_cultivation_rank("base.cultivation.golden_core")
	b.cultivation_rank_id = "base.cultivation.golden_core"
	rules.apply_status(a,"附炎",20,a,0)
	rules.apply_status(b,"灼烧",20,a,0)
	rules.apply_status(b,"破甲",20,a,0)
	hit = rules.damage(a,b,100,"钝击","base.element.fire",0,{"kind":"active"},true,{"special":false})
	check(hit.adjusted == 130 and rules.layers(a,"附炎") == 20, "C03 golden core reads each pool capped10")
	# One physical identity and one element, both corrections use base100.
	b.combat_statuses.clear()
	a.combat_statuses.clear()
	b.armor_type_sources = {"test":"轻甲"}
	b.defense_element = "base.element.metal"
	hit = rules.damage(a,b,100,"穿刺","base.element.fire",0,{"kind":"active"},true,{"special":false})
	check(hit.adjusted == 140, "single base additive 120%+20% =140")
	var pills := make_battle("base.map_item.hemostatic_pill")
	var p: PartyMemberState = pills.state.teams[0][0]
	p.hp = 100
	pills.start()
	pills.advance(0.01)
	check(p.inventory.get_instances().is_empty(), "first pill at zero, consumed / cell freed")
	check(p.hp == 100, "no immediate tick")
	pills.advance(1.99)
	check(p.hp == 103, "first tick exactly2s despite removed source")
	var sim2 := make_battle("base.map_item.qingshi_short_sword", [["armor","base.map_item.coarse_cloth_armor",Vector2i(1,0)]])
	sim2.start()
	check(sim2.state.teams[0][0].armor == 7, "C17 armor starts equipment baseline")
	var buffs := make_battle("base.map_item.t01_0088")
	var owner: PartyMemberState = buffs.state.teams[0][0]
	check(buffs.t01.apply_status(owner,"生机",5,owner,0), "apply regen")
	check(buffs.t01.apply_status(owner,"毒蚀",3,owner,0) and buffs.t01.layers(owner,"生机") == 2 and buffs.t01.layers(owner,"毒蚀") == 0, "opposite batches cancel")
	owner.combat_statuses.clear()
	check(buffs.t01.apply_status(owner,"雷蕴",10,owner,0) and owner.thunder_shields.size() == 1 and buffs.t01.layers(owner,"雷蕴") == 0, "thunder grant success even net stacks0")
	# Explicit mixed-grade member identity and actual adjacency.
	var linked := make_battle("base.map_item.coarse_cloth_armor", [["arm","base.map_item.t01_0066",Vector2i(1,0)],["leg","base.map_item.t01_0015",Vector2i(1,1)]])
	check(linked.state.teams[0][0].maximum("armor") == 14, "mixed link lowest reward once (7+3+2+2)")

func tick(rules: T01CombatRules, member: PartyMemberState, status: String, at: int) -> void:
	rules.tick_status({"member": member, "status": status}, at)

func test_status_timing() -> void:
	for status in ["生机", "毒蚀", "润脉", "枯脉", "流血", "灼烧", "重伤", "破甲", "驱散"]:
		var sim := make_battle()
		var a: PartyMemberState = sim.state.teams[0][0]
		var b: PartyMemberState = sim.state.teams[1][0]
		var r := sim.t01
		a.hp = 100
		a.spirit = 2
		a.stamina = 10
		r.apply_status(a, status, 5, b, 0)
		if status == "破甲":
			tick(r, a, status, 2_000_000)
			check(r.layers(a, status) == 5, "armor break holds10s")
			tick(r, a, status, 10_000_000)
			check(r.layers(a, status) == 4, "armor break first decay10s")
			continue
		if status == "驱散":
			r.apply_status(a, "反锋", 3, a, 0)
		tick(r, a, status, 1_999_999)
		check(r.layers(a, status) == 5 and a.hp == 100, "no premature tick " + status)
		tick(r, a, status, 2_000_000)
		match status:
			"生机": check(a.hp == 105 and r.layers(a, status) == 4, "regen locks5 then consumes1")
			"毒蚀": check(a.hp == 95 and r.layers(a, status) == 4, "toxin direct5 consumes1")
			"润脉": check(a.spirit == 7 and a.stamina == 15 and r.layers(a, status) == 4, "dual restoration")
			"枯脉": check(a.spirit == 0 and a.stamina == 3.5 and r.layers(a, status) == 4, "depletion once transfers3*50%")
			"流血", "灼烧":
				check(a.hp < 100 and r.layers(a, status) == 5, "dot ticks without decay " + status)
				var next: int = a.combat_statuses[status].next
				r.apply_status(a, status, 2, b, 2_500_000)
				check(a.combat_statuses[status].next == next, "dot refresh preserves next tick " + status)
				var expiry: int = a.combat_statuses[status].expires
				# Resolve every scheduled tick; endpoint must remove before dealing damage.
				while int(a.combat_statuses[status].next) < expiry:
					tick(r, a, status, a.combat_statuses[status].next)
				var hp := a.hp
				tick(r, a, status, expiry)
				check(a.hp == hp and r.layers(a, status) == 0, "no expiry dot " + status)
			"重伤":
				check(r.active_injury(a, 2_000_000) == 5 and r.layers(a, status) == 5, "injury activates2s no decay")
				check(r.restore(a, "hp", 3, 2_000_000) == 0 and a.hp == 100, "injury cannot invert healing")
				var cost := r.costs(a, registry.get_item("base.map_item.qingshi_short_sword"), 2_000_000)
				check(cost == Vector2(8,0), "injury only charges existing resource cost")
				tick(r, a, status, 3_000_000)
				check(r.layers(a, status) == 4, "injury first decay3s")
			"驱散":
				check(r.layers(a, "反锋") == 0 and r.layers(a, status) == 2, "dispel removes one buff layer per unit")
				r.apply_status(a, "生机", 4, a, 3_000_000)
				check(a.combat_statuses[status].next == 4_000_000, "stored dispel wakes1s")
				tick(r, a, status, 4_000_000)
				check(r.layers(a, "生机") == 2 and r.layers(a, status) == 0, "stored dispel resumes")
	var sim := make_battle()
	var a: PartyMemberState = sim.state.teams[0][0]
	var b: PartyMemberState = sim.state.teams[1][0]
	sim.t01.apply_status(b, "锋痕", 1, a, 0)
	sim.t01.apply_status(b, "流血", 3, a, 0)
	sim.t01.apply_status(b, "锋痕", 2, a, 0)
	sim.t01.forced_rolls.assign([0.1,0.9])
	sim.t01.apply_status(b, "反锋", 2, b, 1)
	check(sim.t01.layers(b, "锋痕") == 1 and sim.t01.layers(b, "流血") == 3, "same-time cancellation groups status before other kind")

func test_attack_boundaries() -> void:
	var sim := make_battle("base.map_item.qingshi_short_sword")
	var a: PartyMemberState = sim.state.teams[0][0]
	var b: PartyMemberState = sim.state.teams[1][0]
	var r := sim.t01
	var weapon := registry.get_item("base.map_item.qingshi_short_sword")
	var hit := {"effect":"damage", "value":20, "damage_type":"斩击"}
	a.set_cultivation_rank("base.cultivation.qi_refining")
	# Use no resonance for the shield-allocation arithmetic.
	a.cultivation_rank_id = ""
	a.definition.combat_rank = 1
	b.armor_type_sources = {"test":"轻甲"}
	b.barrier = 50
	b.armor = 100
	r.apply_status(a, "附炎", 10, a, 0)
	r.forced_rolls.assign([0.0, 0.5])
	r.attack_item(a,b,weapon,hit,0,{"kind":"active"})
	check(b.barrier == 41 and b.armor == 79, "30% whole30 allowance9, flame10 absorbs9, physical20 intact")
	check(r.layers(a, "附炎") == 0, "flame consumed at launch")
	b.combat_statuses.clear()
	r.apply_status(b, "轻灵", 5, b, 0)
	r.forced_rolls.assign([0.99])
	check(not r.attack_item(a,b,weapon,hit,0,{"kind":"active"}).hit and r.layers(b, "轻灵") == 3, "dodge consumes floor half only on miss")
	b.combat_statuses.clear()
	r.apply_status(b, "疲惫", 5, a, 0)
	r.forced_rolls.assign([0.0,0.0])
	r.attack_item(a,b,weapon,hit,0,{"kind":"active"})
	check(r.layers(b,"疲惫") == 3, "actual critical consumes half fatigue")
	b.combat_statuses.clear()
	r.apply_status(b,"坚韧",5,b,0)
	r.forced_rolls.assign([0.0,0.02])
	r.attack_item(a,b,weapon,hit,0,{"kind":"active"})
	check(r.layers(b,"坚韧") == 3, "resisted critical consumes half toughness")
	b.combat_statuses.clear()
	r.apply_status(b,"失衡",5,a,0)
	r.forced_rolls.assign([0.0,0.5,0.0,0.0])
	r.attack_item(a,b,weapon,hit,0,{"kind":"active"})
	check(r.layers(b,"失衡") == 3, "successful followup consumes half imbalance")
	b.combat_statuses.clear()
	r.apply_status(b,"缠绕",5,a,0)
	r.damage(a,b,10,"法术型","base.element.fire",0,{"kind":"active"},true,{"special":false})
	check(r.layers(b,"缠绕") == 4,"active fire consumes one entangle")
	for category in ["artifact", "throwable"]:
		for record: Dictionary in loadout.records.values():
			if record.category == category and record.get("base_damage",0)>0:
				var item := registry.get_item(record.id)
				b.combat_statuses.clear()
				r.forced_rolls.assign([0.949 if category == "artifact" else 0.899])
				check(r.attack_item(a,b,item,item.effects_for("on_activate")[0],0,{"kind":"active"}).hit,"confirmed hit below threshold " + item.display_name)
				r.forced_rolls.assign([0.95 if category == "artifact" else 0.90])
				check(not r.attack_item(a,b,item,item.effects_for("on_activate")[0],0,{"kind":"active"}).hit,"miss at threshold " + item.display_name)
	var thunder := make_battle("base.map_item.qingshi_short_sword")
	var target: PartyMemberState = thunder.state.teams[1][0]
	var source: PartyMemberState = thunder.state.teams[0][0]
	target.thunder_shields.assign([1.0,1.0,1.0])
	thunder.t01.apply_status(target,"雷蕴",10,target,0)
	target.barrier = 50
	var packet := thunder.t01.damage(source,target,10,"钝击","base.element.none",0,{"kind":"test"},false,{"special":true})
	check(packet.hp_loss == 7 and target.barrier == 50 and target.thunder_shields == [80.0],"recharge after old shields absorb3; no same-round barrier/new shield")
	var counter_sim := make_battle("base.map_item.qingshi_short_sword")
	var attacker: PartyMemberState = counter_sim.state.teams[0][0]
	var defender: PartyMemberState = counter_sim.state.teams[1][0]
	attacker.hp = 1
	counter_sim.t01.apply_status(defender, "反锋", 10, defender, 0)
	counter_sim.t01.apply_status(defender, "失衡", 5, attacker, 0)
	counter_sim.t01.forced_rolls.assign([0.0, 0.5, 0.0, 0.0])
	counter_sim.t01.attack_item(attacker,defender,weapon,hit,0,{"kind":"active"})
	check(attacker.hp == 0 and counter_sim.t01.layers(defender,"失衡") == 5, "C16 lethal counter prevents followup and its status consumption")
	check(counter_sim.drain_events().filter(func(e: Dictionary): return e.get("label") == "失衡追击").is_empty(), "C16 no followup event after attacker dies")
	var zero := make_battle("base.map_item.t01_0043")
	attacker = zero.state.teams[0][0]
	defender = zero.state.teams[1][0]
	zero.t01.apply_status(defender,"雷印",10,attacker,0)
	var zero_hp_before := defender.hp
	var zero_item := registry.get_item("base.map_item.t01_0043")
	var previous_value: float = zero_item.effects[0].value
	zero_item.effects[0].value = 0.0 # Isolate the shared hit-versus-positive-damage gate.
	zero.t01.forced_rolls.assign([0.0,0.5])
	zero.t01.activate("test.item",0)
	zero_item.effects[0].value = previous_value
	check(defender.hp == zero_hp_before and zero.t01.layers(defender,"雷印") == 12 and defender.paralyzed_until == 0, "C09 zero damage still applies configured hit status but cannot trigger thunder strike")
	zero.t01.apply_status(attacker,"生机",3,attacker,0)
	zero.t01.apply_status(attacker,"雷蕴",10,attacker,0)
	attacker.barrier = 8
	attacker.temporary_effects.test = {"until":5_000_000}
	zero.t01.paralyze(attacker,0)
	zero.t01.freeze(attacker,500_000,0)
	zero._finish("retreat",0)
	check(attacker.combat_statuses.is_empty() and attacker.temporary_effects.is_empty() and attacker.thunder_shields.is_empty() and attacker.barrier == 0 and attacker.paralyzed_until == 0 and attacker.frozen_until == 0, "C17 terminal cleanup removes status pools, shields, temporary effects and controls")

func test_stacks_and_control() -> void:
	var content := ContentRegistry.new()
	check(content.load_base_content(), "fresh stack registry")
	var state: MapLoadoutState = MapLoadoutStore.create_state(content, content.get_board("base.board.bag")).state
	check(state.add_reward({"id":"base.map_reward.stack_test","item_id":"base.map_item.hemostatic_pill","quantity":11}).is_empty(), "stack test stock")
	var id := "owned.base.map_item.hemostatic_pill.0"
	check(state.place(state.drag_data("storage",id,5), Vector2i.ZERO),"select five from storage")
	check(state.place(state.drag_data("storage",id,5), Vector2i(1,0)),"same item merges into one cell")
	check(state.inventory.get_instances().size() == 1 and state.inventory.get_instances()[0].units.size() == 10,"same concrete item maximum one10 stack")
	check(not state.place(state.drag_data("storage",id,1), Vector2i(2,0)),"eleventh cannot occupy a second cell")
	check(state.snapshot().owned_units.size() == 126,"stack operations preserve ownership")
	var oversized := state.snapshot()
	for unit_id: String in oversized.owned_units:
		if oversized.owned_units[unit_id] == "base.map_item.hemostatic_pill" and unit_id not in oversized.placements[0].unit_ids:
			oversized.placements[0].unit_ids.append(unit_id)
	var migrated_content := ContentRegistry.new()
	check(migrated_content.load_base_content(), "fresh migration registry")
	var migrated: MapLoadoutState = MapLoadoutStore.create_state(migrated_content, migrated_content.get_board("base.board.bag")).state
	check(migrated.restore(oversized).is_empty(), "old oversized stack migrates without blocking load")
	check(migrated.inventory.get_instances().is_empty() and migrated.snapshot().owned_units.size() == 126, "old oversized stack returns all units to storage without loss")
	check(state.save_formation("消耗叠",state.formation_icons[0]).is_empty(),"save concrete stack formation")
	var snapshot := state.snapshot()
	var consumed_id: String = snapshot.placements[0].unit_ids.pop_front()
	snapshot.owned_units.erase(consumed_id)
	snapshot.placements[0].instance_id = snapshot.placements[0].unit_ids[0]
	check(state.restore(snapshot).is_empty() and state.apply_formation(state.formations[0].id).is_empty(),"formation tolerates consumed first unit without replacement")
	check(state.inventory.get_instances()[0].units.size() == 9 and state.snapshot().owned_units.size() == 125,"formation uses remaining9 original units and cannot recreate consumed unit")
	var sim := make_battle("base.map_item.qingshi_short_sword")
	sim.start()
	var a: PartyMemberState = sim.state.teams[0][0]
	a.stamina = 0
	sim.advance(5.5)
	check(sim.state.item_runtime["test.item"].activation_count == 0,"no pay/activation when insufficient")
	a.stamina = 50
	sim._wake_items(sim.state.time_usec)
	sim.advance(0.001)
	check(sim.state.item_runtime["test.item"].activation_count == 1,"ready attack wakes immediately after resource recovery")
	var frozen := make_battle("base.map_item.qingshi_short_sword")
	frozen.start()
	var p: PartyMemberState = frozen.state.teams[0][0]
	frozen.t01.freeze(p,500_000,0)
	frozen.advance(5.5)
	check(frozen.state.item_runtime["test.item"].activation_count == 0,"freeze pauses item countdown")
	frozen.advance(0.5)
	check(frozen.state.item_runtime["test.item"].activation_count == 1,"freeze resumes remaining countdown")
	var display := make_battle("base.map_item.qingshi_short_sword")
	display.start()
	display.advance(2.0)
	var progress := display.activation_progress("test.item")
	display.t01.freeze(display.state.teams[0][0], 1_000_000, display.state.time_usec)
	check(is_equal_approx(display.activation_progress("test.item"), progress), "freeze preserves current displayed cooldown progress")
	display.advance(0.5)
	check(is_equal_approx(display.activation_progress("test.item"), progress), "cooldown display stays still throughout freeze")
	for at in [4_500_000,5_000_000]:
		var paralyzed := make_battle("base.map_item.qingshi_short_sword")
		paralyzed.start()
		paralyzed.t01.paralyze(paralyzed.state.teams[0][0],at)
		paralyzed.advance(5.5)
		check(paralyzed.state.item_runtime["test.item"].activation_count == (1 if at == 4_500_000 else 0),"paralysis endpoint versus skip full cycle")

func test_assets() -> void:
	for record: Dictionary in loadout.records.values():
		var battle := make_battle(record.id)
		for index in 100: battle.t01.forced_rolls.append(0.5)
		var member: PartyMemberState = battle.state.teams[0][0]
		member.hp = 100
		member.stamina = 100
		member.spirit = 100
		battle.start()
		battle.advance(maxf(float(record.cooldown), 12.0) + 0.01)
		var events := battle.drain_events()
		var activations := events.filter(func(event: Dictionary): return event.kind == "item_activated" and event.get("owner_id") == member.id)
		var periodic := not registry.get_item(record.id).effects_for("on_activate").is_empty()
		check(not periodic or not activations.is_empty(), "actual item activation " + record.name)
		if record.get("base_damage", 0) > 0:
			check(battle.state.teams[1][0].hp < 10000, "actual damage " + record.name)
		if record.get("armor_capacity", 0) > 0:
			check(member.maximum("armor") >= record.armor_capacity, "actual armor source " + record.name)
		check(member.spirit >= 0 and member.stamina >= 0, "resources nonnegative " + record.name)

func item_named(name_text: String) -> ItemData:
	for record: Dictionary in loadout.records.values():
		if record.name == name_text: return registry.get_item(record.id)
	return null

func test_reactive_and_barrier() -> void:
	var tested := {}
	for record: Dictionary in loadout.records.values():
		var reactive := registry.get_item(record.id).effects_for("on_attacked")
		if reactive.is_empty() or tested.has(reactive[0].status): continue
		var e: Dictionary = reactive[0]
		tested[e.status] = true
		var sim := make_battle(record.id)
		var owner: PartyMemberState = sim.state.teams[0][0]
		sim.start()
		sim.t01.on_attacked(owner, 8_999_999)
		check(sim.t01.layers(owner,e.status) == 0,"reactive waits initial9s " + e.status)
		sim.t01.on_attacked(owner, 9_000_000)
		check(sim.t01.layers(owner,e.status) == e.value and sim.state.item_runtime["test.item"].reactive_ready == 18_000_000,"successful reactive restarts independent9s " + e.status)
		sim.t01.on_attacked(owner, 10_000_000)
		check(sim.t01.layers(owner,e.status) == e.value,"no repeated early reactive " + e.status)
	var gem := item_named("灵盾珠")
	var sim := make_battle(gem.id)
	var owner: PartyMemberState = sim.state.teams[0][0]
	var enemy: PartyMemberState = sim.state.teams[1][0]
	owner.barrier = 50
	sim.start()
	check(sim.state.item_runtime["test.item"].barrier_stopped and sim.state.item_runtime["test.item"].next_activation_usec == 0,"full barrier suspends pearl CD")
	var spirit := owner.spirit
	sim.t01.damage(enemy,owner,5,"钝击","base.element.none",0,{"kind":"test"},false,{"special":false})
	check(not sim.state.item_runtime["test.item"].barrier_stopped and sim.state.item_runtime["test.item"].ready_at_usec == 10_500_000 and owner.spirit == spirit,"actual barrier loss resumes full10.5s, no instant fee or refill")
	sim.advance(10.499)
	check(sim.state.item_runtime["test.item"].activation_count == 0,"pearl cannot fire before restarted full CD")
	sim.advance(0.001)
	check(sim.state.item_runtime["test.item"].activation_count == 1 and owner.spirit == spirit-6,"pearl fires once and pays6 at10.5s")
	var cleanse := make_battle("base.map_item.detox_powder")
	owner = cleanse.state.teams[0][0]
	cleanse.t01.apply_status(owner,"毒蚀",5,cleanse.state.teams[1][0],0)
	cleanse.start()
	cleanse.advance(0.001)
	check(cleanse.t01.layers(owner,"毒蚀") == 0 and not cleanse.t01.apply_status(owner,"毒蚀",5,cleanse.state.teams[1][0],14_999_999),"first-ready detox clears shared toxin and blocks15s")
	check(cleanse.t01.apply_status(owner,"毒蚀",5,cleanse.state.teams[1][0],15_000_000),"toxin immunity expires at exact15s")
	var rank_one := make_battle()
	owner = rank_one.state.teams[0][0]
	owner.set_cultivation_rank("base.cultivation.qi_refining")
	rank_one.t01.apply_status(owner,"雷蕴",25,owner,0)
	check(owner.thunder_shields == [20.0] and rank_one.t01.layers(owner,"雷蕴") == 10,"batch thunder converts before clamping stored remainder")
	var water := item_named("寒水珠")
	var cold := make_battle(water.id)
	owner = cold.state.teams[0][0]
	enemy = cold.state.teams[1][0]
	cold.t01.forced_rolls.assign([0.0])
	cold.t01.activate("test.item",0)
	check(enemy.frozen_until == 500_000,"water hit applies frost before consuming one and freezing")
	var lightning := item_named("雷纹剑")
	if lightning == null:
		for record: Dictionary in loadout.records.values():
			if record.category == "weapon" and record.element == "base.element.thunder":
				lightning = registry.get_item(record.id)
				break
	var thunder := make_battle(lightning.id)
	owner = thunder.state.teams[0][0]
	enemy = thunder.state.teams[1][0]
	thunder.t01.apply_status(enemy,"雷印",10,owner,0)
	thunder.t01.apply_status(enemy,"连环",5,owner,0)
	thunder.t01.forced_rolls.assign([0.0,0.5])
	thunder.t01.attack_item(owner,enemy,lightning,lightning.effects[0],0,{"kind":"active"})
	check(thunder.t01.layers(enemy,"雷印") == 0 and thunder.t01.layers(enemy,"连环") == 5 and enemy.paralyzed_until == 1_000_000,"thunder strike consumes10, paralyzes, preempts chain")
	thunder.t01.forced_rolls.assign([0.0,0.5])
	thunder.t01.attack_item(owner,enemy,lightning,lightning.effects[0],0,{"kind":"active"})
	check(thunder.t01.layers(enemy,"连环") == 4,"without marks chain consumes one")

func finish() -> void:
	print("T01 CHECKS ", checks, "; FAILURES ", failures.size())
	quit(0 if failures.is_empty() else 1)
