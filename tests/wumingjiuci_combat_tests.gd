extends SceneTree

var registry := ContentRegistry.new()
var checks := 0
var failures := 0
var loadout: MapLoadoutState
const IDS := ["heiwei_cishu", "huiyi_fu", "xueju_huizhu", "yanfu_duzhu"]

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func actor(id: String) -> PartyMemberState:
	var raw := registry.get_character("base.character.chen_yu")
	raw.id = id
	raw.max_hp = 10000
	raw.max_stamina = 10000
	var result := PartyMemberState.new(raw, registry)
	result.inventory = InventoryState.new(registry, Vector2i(8,8))
	return result

func duel(player: PartyMemberState, enemy: PartyMemberState) -> BattleSimulation:
	var sim := BattleSimulation.new([player], [enemy], registry)
	check(sim.start(), "simulation starts")
	return sim

func run() -> void:
	check(registry.load_base_content(), "content loads: " + str(registry.errors))
	if not registry.errors.is_empty(): quit(1); return
	var content := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(content.error.is_empty(), "runtime item catalog loads: " + content.error)
	if not content.error.is_empty(): quit(1); return
	loadout = content.state
	var occupied := [5,5,9,9]
	var capacities := [0,0,4,9]
	for i in IDS.size():
		var enemy := PartyMemberState.new(registry.get_enemy("base.enemy."+IDS[i]),registry)
		enemy.equip_definition_loadout()
		check(registry.enemy_battle_error(enemy.id).is_empty(), IDS[i]+" battle enabled")
		check(enemy.inventory.occupied_cells() == occupied[i], IDS[i]+" organ cells")
		var player := actor("test.player")
		var sim := duel(player,enemy)
		check(enemy.armor == 0 and enemy.maximum("armor") == capacities[i], IDS[i]+" initial armor and capacity")
		sim.advance(7.1)
		var events := sim.drain_events()
		check(events.any(func(e:Dictionary):return e.kind == "damage"), IDS[i]+" actual attacks")
		check(enemy.stamina < enemy.maximum("stamina"), IDS[i]+" pays organ costs")
		if i >= 2: check(enemy.armor > 0, IDS[i]+" armor recovery")
		for entry:Dictionary in enemy.inventory.get_instances():
			check((load(registry.get_item(entry.item_id).icon_path) as Texture2D).get_image().has_mipmaps(), "organ mipmaps "+entry.item_id)
		# Complete combat with real attacks; large fixture resources isolate mechanics from balance.
		var attacker := actor("test.full.player")
		attacker.inventory.add_item("sword", "base.map_item.qingshi_short_sword", Vector2i.ZERO)
		var defender := PartyMemberState.new(registry.get_enemy(enemy.id),registry)
		defender.equip_definition_loadout()
		var full := duel(attacker,defender)
		full.advance(240)
		check(full.state.is_finished() and full.state.result=="victory" and defender.hp==0, IDS[i]+" real attacks complete battle")
	test_delays()
	test_poison_and_heart()
	test_loot()
	print("SHRINE COMBAT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_delays() -> void:
	var player := actor("test.delay.target")
	player.inventory.add_item("a", "base.organ.cishu_tooth",Vector2i(0,0))
	player.inventory.add_item("b", "base.organ.cishu_tooth",Vector2i(1,0))
	player.inventory.add_item("armor", "base.organ.huizhu_shell",Vector2i(0,1))
	player.inventory.add_item("passive", "base.organ.huizhu_silk",Vector2i(3,0))
	var enemy := actor("test.delay.source")
	enemy.inventory.add_item("echo", "base.organ.huifu_echo_sac",Vector2i.ZERO)
	var sim := duel(player,enemy)
	sim.timeline.set_all(player,false)
	sim.timeline.set_all(enemy,false)
	var echo: Dictionary = registry.get_item("base.organ.huifu_echo_sac").effects[0]
	var silk: Dictionary = registry.get_item("base.organ.huizhu_silk_sac").effects[0]
	var big: Dictionary = registry.get_item("base.organ.yanfu_silk_sac").effects[0]
	check(sim.t01.delay_cooldowns(player,echo,0)==["a"], "equal due chooses first board cell")
	check(sim.timeline.remaining("a")==4000000 and sim.timeline.remaining("b")==3500000, "single delay exact 0.5 seconds")
	check(sim.t01.delay_cooldowns(player,echo,0)==["b"], "chooses earliest current due, not first cell")
	sim.timeline.set_speed("a","test.speed",1.0,0)
	check(sim.t01.delay_cooldowns(player,echo,0)==["a"], "earliest considers actual CD speed")
	check(sim.t01.delay_cooldowns(player,silk,0)==["a","b"], "attack scope skips armor and passive")
	check(sim.t01.delay_cooldowns(player,big,0)==["a","b","armor"], "all items includes recovery but not zero-CD passive")
	sim.timeline.change_cd("a",-100000000,0)
	check(sim.t01.delay_cooldowns(player,echo,0)==["a"] and sim.timeline.remaining("a")==500000, "ready item can be delayed")
	sim.timeline.apply_control(player,"freeze","a",1000000,"test",0)
	check(sim.t01.delay_cooldowns(player,echo,0)==["b"], "frozen item excluded")
	sim.timeline.timers.b.entry=1000000.0
	check(sim.t01.delay_cooldowns(player,echo,0).is_empty(), "entry cooldown excluded and no-target harmless")
	for patch in [{"seconds":0},{"seconds":NAN},{"item_scope":"unknown"},{"selection":"random"},{"target":"self"}]:
		var bad := echo.duplicate(true)
		bad.merge(patch,true)
		check(not T01Definition.valid_effect(bad), "invalid CD effect rejected")
	# Actual activation dispatch, cost and timer rescheduling, independent of direct helper checks.
	var target := actor("test.activation.target")
	target.inventory.add_item("weapon","base.organ.cishu_tail",Vector2i.ZERO)
	var bat := actor("test.activation.bat")
	bat.inventory.add_item("echo","base.organ.huifu_echo_sac",Vector2i.ZERO)
	var active := duel(target,bat)
	active.timeline.set_all(target,false)
	active.advance(6.5)
	check(active.timeline.remaining("weapon")==500000 and bat.stamina==bat.maximum("stamina")-3, "echo activation delays a ready weapon and pays 3 stamina")
	var events := active.drain_events()
	check(events.any(func(e:Dictionary):return e.kind=="cooldown_delayed"), "delay emits simulation event")
	check(BattleLog.new().consume(events,registry).contains("冷却延长0.5秒"), "delay visible in battle log")

func test_poison_and_heart() -> void:
	var target := actor("test.poison.target")
	var poison := PartyMemberState.new(registry.get_enemy("base.enemy.yanfu_duzhu"),registry)
	poison.inventory.add_item("sac","base.organ.yanfu_poison_sac",Vector2i.ZERO)
	check(T01CombatRules.capacity(poison,"毒蚀")==1 and T01CombatRules.capacity(poison,"流血")==0, "organ grants only one poison capacity")
	var sim := duel(target,poison)
	sim.advance(6)
	check(T01CombatRules.layers(target,"毒蚀")==1 and target.hp==target.maximum("hp"), "poison applies at 6 seconds without immediate damage")
	sim.advance(0.999)
	check(target.hp==target.maximum("hp"), "first tick waits full second")
	sim.advance(0.001)
	check(target.hp==target.maximum("hp")-1 and T01CombatRules.layers(target,"毒蚀")==0, "one layer causes one damage at 7 seconds then clears")
	check(sim.t01.apply_status(target,"毒蚀",5,poison,sim.state.time_usec) and T01CombatRules.layers(target,"毒蚀")==1, "source capacity clamps extra layers")
	poison.inventory.locked=false
	poison.inventory.take("sac")
	check(T01CombatRules.capacity(poison,"毒蚀")==0, "removing organ removes capacity")
	var heart := PartyMemberState.new(registry.get_enemy("base.enemy.yanfu_duzhu"),registry)
	heart.inventory.add_item("heart","base.organ.yanfu_heart",Vector2i.ZERO)
	var heart_target := actor("test.heart.target")
	heart_target.inventory.add_item("weapon","base.organ.cishu_tooth",Vector2i.ZERO)
	var heart_sim := duel(heart_target,heart)
	heart_sim.timeline.set_all(heart_target,false)
	heart_sim.advance(2)
	check(heart.stamina==105, "heart idle above threshold")
	heart.stamina=69
	heart_sim.timeline.wake(heart_sim.state.time_usec)
	heart_sim.advance(2)
	check(heart.stamina==71, "heart restores 2 at threshold after 2 seconds")
	heart_sim.advance(2)
	check(heart.stamina==71, "heart stops again above two-thirds")

func test_loot() -> void:
	var state: MapLoadoutState = MapLoadoutStore.candidate(loadout).state
	for slug: String in IDS:
		var enemy := registry.get_enemy("base.enemy."+slug)
		var rolls: Array = []
		rolls.resize(enemy.loot.size()); rolls.fill(0.249)
		var all_drops := BattleLoot.candidate(state,enemy,"test.all."+slug,rolls)
		check(all_drops.error.is_empty() and all_drops.drops.size()==enemy.loot.size(), slug+" material drops")
		rolls.fill(0.25)
		var none := BattleLoot.candidate(state,enemy,"test.none."+slug,rolls)
		check(none.error.is_empty() and none.drops.size()==(1 if slug=="yanfu_duzhu" else 0), slug+" exact 25 percent threshold")
		for row:Dictionary in enemy.loot:
			check(not state.records[row.item_id].grant_on_start and state.records[row.item_id].category=="beast", "material identity and no starting grant")
	var poison := registry.get_enemy("base.enemy.yanfu_duzhu")
	var miss := [0.99,0.99,0.99,0.99,0.99,0.99]
	var first := BattleLoot.candidate(state,poison,"test.n04",miss)
	check(first.drops==["base.material.yanfu_heart"], "first poison victory guarantees heart only")
	check(state.restore(first.snapshot).is_empty(), "first receipt accepted")
	var count: int = state.snapshot().owned_units.size()
	var repeat := BattleLoot.candidate(state,poison,"test.n04",miss)
	check(repeat.snapshot.owned_units.size()==count, "retry does not duplicate loot")
	var second := BattleLoot.candidate(state,poison,"test.n23",miss)
	check(second.drops.is_empty(), "first victory shared across two sites")
	miss[5]=0.099
	check(BattleLoot.candidate(state,poison,"test.n23.hit",miss).drops==["base.material.yanfu_heart"], "later heart independent 10 percent")
