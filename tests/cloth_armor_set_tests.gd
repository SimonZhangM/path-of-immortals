extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry loads")
	var loaded := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	check(loaded.error.is_empty(), "isolated item catalog loads")
	var member := PartyMemberState.new({"id":"test.cloth", "name":"cloth", "max_hp":50, "max_stamina":50, "max_spirit":50}, registry)
	var enemy := PartyMemberState.new({"id":"test.enemy", "name":"enemy", "max_hp":50, "max_stamina":50, "max_spirit":50}, registry)
	var sim := BattleSimulation.new([member], [enemy], registry)
	var rules := sim.t01
	member.inventory = InventoryState.new(registry, Vector2i(4,4))
	check(member.inventory.add_item("body", "base.map_item.coarse_cloth_armor", Vector2i.ZERO), "body fits")
	check(member.inventory.add_item("arm", "base.map_item.t01_0014", Vector2i(1,0)), "arm touches body")
	check(rules.link_bonus(member).capacity == 0, "missing leg gives no set bonus")
	check(member.inventory.add_item("leg", "base.map_item.t01_0015", Vector2i(1,1)), "leg touches body")
	var bonus := rules.link_bonus(member)
	check(bonus.capacity == 3 and bonus.recovery.get("body",0) == 2 and bonus.stamina_recovery.get("body",0) == 2 and bonus.recovery.size() == 1, "cloth set gives capacity3, body armor2 and stamina2 only")
	for entry: Dictionary in member.inventory.get_instances():
		member.armor_capacity_sources[entry.instance_id] = registry.get_item(entry.item_id).armor_capacity
	rules.refresh_equipment(member)
	check(member.maximum("armor") == 13, "cloth trio capacity is 7+1+2+3=13")
	var body := registry.get_item("base.map_item.coarse_cloth_armor")
	check(body.cooldown_usec == 6_000_000 and body.effects_for("on_activate")[0].value + bonus.recovery.body == 6, "body restores6 each6seconds with set")
	check(ItemTooltip.effect_text(body).contains("套装：布护臂和布护腿同时与粗布甲紧贴，粗布甲护甲上限额外+3，粗布甲恢复护甲额外+2，且额外恢复2体力。"), "cloth set tooltip matches request")
	check(ItemTooltip._colored(body.combat.equipment_note, ItemTooltip.highlighted_keywords()).contains("player-status-stamina.webp[/img]"), "stamina inline icon included")
	sim = BattleSimulation.new([member],[enemy],registry)
	rules = sim.t01
	member.armor = 0
	member.stamina = 40
	rules.activate("body",6_000_000)
	check(is_equal_approx(member.armor,6) and is_equal_approx(member.stamina,42), "actual body activation restores6 armor and2 stamina")
	rules.activate("arm",6_000_000)
	check(is_equal_approx(member.stamina,42), "arm activation does not receive body stamina reward")
	member.stamina = 49
	rules.activate("body",12_000_000)
	check(is_equal_approx(member.stamina,50), "stamina recovery respects maximum")
	member.inventory.locked = false
	check(rules.link_bonus(member,"arm").capacity == 0, "excluded arm removes bonus")
	check(member.inventory.move_item("leg",Vector2i(1,2)), "leg moves diagonally away")
	check(rules.link_bonus(member).capacity == 0, "diagonal and touching arm only do not count")
	member.armor = 0
	member.stamina = 40
	rules.activate("body",18_000_000)
	check(is_equal_approx(member.armor,4) and is_equal_approx(member.stamina,40), "broken set restores base armor4 and no stamina")
	check(member.inventory.move_item("leg",Vector2i(1,1)), "leg returns")
	check(member.inventory.add_item("extra_arm", "base.map_item.t01_0014", Vector2i(3,0)), "extra same-slot arm allowed")
	check(rules.link_bonus(member).capacity == 3, "nonadjacent extra arm must not override touching arm")
	check(member.inventory.add_item("extra_leg", "base.map_item.t01_0015", Vector2i(3,1)), "extra same-slot leg allowed")
	check(rules.link_bonus(member).capacity == 3, "nonadjacent extra leg must not override touching leg")
	check(member.inventory.move_item("extra_arm",Vector2i(0,2)), "second arm also touches body")
	bonus = rules.link_bonus(member)
	check(bonus.capacity == 3 and bonus.recovery.get("body",0) == 2 and bonus.stamina_recovery.get("body",0) == 2, "multiple touching accessories grant one reward")
	check(rules.link_bonus(member,"arm").capacity == 3, "another touching arm can maintain set when first excluded")
	member.inventory.take("leg")
	check(member.inventory.add_item("upgraded_leg","base.map_item.t01_0070",Vector2i(1,1)), "coarse body accepts upgraded lineage leg")
	check(rules.link_bonus(member).capacity == 3, "coarse body new reward applies with compatible upgraded leg")
	member.inventory.take("upgraded_leg")
	check(member.inventory.add_item("leg","base.map_item.t01_0015",Vector2i(1,1)), "cloth leg returns")
	member.inventory.take("body")
	check(member.inventory.add_item("water_body","base.map_item.t01_0056",Vector2i.ZERO), "upgraded cloth body fits")
	bonus = rules.link_bonus(member)
	check(bonus.capacity == 2 and bonus.recovery.get("water_body",0) == 1 and bonus.stamina_recovery.is_empty(), "water body mixed grade reward remains2/1 without stamina")
	member.inventory.take("arm")
	member.inventory.take("leg")
	member.inventory.take("extra_arm")
	member.inventory.take("extra_leg")
	check(member.inventory.add_item("water_arm","base.map_item.t01_0066",Vector2i(1,0)) and member.inventory.add_item("water_leg","base.map_item.t01_0070",Vector2i(1,1)), "upgraded cloth accessories fit")
	bonus = rules.link_bonus(member)
	check(bonus.capacity == 3 and bonus.recovery.get("water_body",0) == 1, "all ordinary-grade cloth members give3/1")
	var raw := T01Definition.item_record(body.combat)
	for invalid: Variant in [-1, 1.5, "2"]:
		raw.combat.link_reward.stamina = invalid
		check(not T01Definition.runtime_error(raw).is_empty(), "invalid link reward rejected")
	var iron := PartyMemberState.new({"id":"test.iron", "max_hp":50, "max_stamina":50, "max_spirit":50},registry)
	check(iron.inventory.add_item("iron_body","base.map_item.t01_0011",Vector2i.ZERO) and iron.inventory.add_item("iron_arm","base.map_item.t01_0016",Vector2i(1,0)) and iron.inventory.add_item("iron_leg","base.map_item.t01_0017",Vector2i(1,1)), "shared iron link fixture fits")
	bonus = rules.link_bonus(iron)
	check(bonus.capacity == 3 and bonus.recovery.get("iron_body",0) == 2, "shared iron trio still gives3/2")
	print("CLOTH ARMOR SET: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
