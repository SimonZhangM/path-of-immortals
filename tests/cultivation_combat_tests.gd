extends SceneTree
var checks := 0
var failures: Array[String] = []
var registry := ContentRegistry.new()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL: "+label)

func _init() -> void: call_deferred("run")

func learn(member: PartyMemberState, book: String, level: int, choice := "") -> void:
	for stage in range(1,level+1):
		check(member.knowledge.record_achievement(registry.library,book,stage,5),"learn "+book+str(stage))
	if not choice.is_empty(): check(member.knowledge.choose(registry.library,book,level,choice),"choose "+choice)

func actor(id: String) -> PartyMemberState:
	var raw := registry.get_character("base.character.chen_yu")
	raw.id=id
	raw.max_hp=100000; raw.max_stamina=100000; raw.max_spirit=100000
	raw.cultivation_rank="base.cultivation.huashen"
	var member := PartyMemberState.new(raw,registry)
	# Registry realm names are authoritative; fixture uses combat_rank fallback.
	if member.cultivation.is_empty(): member.cultivation_rank_id=""; member.definition.combat_rank=5
	member.inventory=InventoryState.new(registry,Vector2i(10,10))
	return member

func battle(spell_id := "", choice := "") -> BattleSimulation:
	var p := actor("test.actor.player")
	var e := actor("test.actor.enemy")
	p.inventory.add_item("weapon","base.map_item.qingshi_short_sword",Vector2i(0,3))
	e.inventory.add_item("enemy_weapon","base.map_item.qingshi_short_sword",Vector2i(0,3))
	if not spell_id.is_empty():
		var definition: Dictionary = registry.library.spells[spell_id]
		learn(p,definition.book_id,int(definition.learned_at_book_level)+1,choice)
		check(p.inventory.add_item("spell",spell_id,Vector2i.ZERO),"equip "+spell_id)
	var sim := BattleSimulation.new([p],[e],registry)
	check(sim.start(),"start "+spell_id)
	sim.timeline.set_all(p,false); sim.timeline.set_all(e,false)
	return sim

func run() -> void:
	check(registry.load_base_content(),"registry "+str(registry.errors))
	if not registry.errors.is_empty(): finish(); return
	var catalog := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(catalog.error.is_empty(),"assets loaded")
	if not catalog.error.is_empty(): finish(); return
	test_knowledge()
	test_all_spells()
	test_modes_controls()
	test_special()
	test_prepared()
	test_boundaries()
	test_shield_order()
	test_book_rules()
	test_attribution_and_weights()
	test_passives_and_recovery()
	finish()

func test_knowledge() -> void:
	check(registry.library.books.size()==35 and registry.library.spells.size()==56,"35 books / 56 spells registered")
	var k := CultivationKnowledge.new()
	check(not k.record_achievement(registry.library,"base.cultivation_book.metal_04",2,5),"no jumping stages")
	check(not k.record_achievement(registry.library,"base.cultivation_book.metal_04",1,0),"mortal cannot learn")
	check(k.record_achievement(registry.library,"base.cultivation_book.metal_04",1,1),"first stage qi")
	check(k.record_achievement(registry.library,"base.cultivation_book.metal_04",2,1),"second stage qi")
	check(not k.record_achievement(registry.library,"base.cultivation_book.metal_04",3,1),"third stage requires foundation")
	check(k.choose(registry.library,"base.cultivation_book.metal_04",2,"剑锋"),"choose branch")
	check(not k.choose(registry.library,"base.cultivation_book.metal_04",2,"留痕"),"no free respec")
	var restored := CultivationKnowledge.new()
	check(restored.restore(k.snapshot(),registry.library,1) and restored.snapshot()==k.snapshot(),"learning snapshot round trip")
	var p := actor("test.learner")
	check(not p.can_use_item(registry.get_item("base.spell.metal_01")),"unlearned spell denied")
	p.knowledge=restored
	check(p.can_use_item(registry.get_item("base.spell.metal_01")),"learned spell independent of book")
	check(p.inventory.add_item("a","base.spell.metal_01",Vector2i.ZERO) and not p.inventory.add_item("b","base.spell.metal_01",Vector2i(1,0)),"spell unique on board")

func test_all_spells() -> void:
	for id: String in registry.library.spells:
		var definition: Dictionary = registry.library.spells[id]
		var choices: Array = [""]+definition.branches.keys()
		for choice: String in choices:
			var sim := battle(id,choice)
			var p: PartyMemberState = sim.state.teams[0][0]
			var e: PartyMemberState = sim.state.teams[1][0]
			p.hp-=100
			sim.t01.forced_rolls.assign([0.0,.99,0.0,.99,0.0,.99,0.0,.99])
			var spell := sim.cultivation.data(p,registry.get_item(id))
			if spell.opcode=="change_cd": sim.timeline.change_cd("weapon",30_000_000,0)
			sim.advance(float(sim.timeline.full_cd("spell"))/1_000_000)
			var old_spirit := p.spirit
			if spell.prepared:
				check(sim.state.item_runtime.spell.activation_count==0 and p.spirit==old_spirit,"prepared waits without fee "+id+choice)
				check(sim.cultivation.prepared(p,spell.opcode,sim.state.time_usec)=="spell","prepared is eligible "+id)
			else:
				check(sim.timeline.request("spell"),"manual cast "+id+choice)
				check(sim.state.item_runtime.spell.activation_count==1,"one activation "+id+choice)
				check(p.spirit<old_spirit,"paid fee "+id+choice)
				if spell.damage>0: check(e.hp<e.maximum("hp"),"spell causes damage "+id+choice)
				if spell.opcode=="sword_screen": check(is_equal_approx(p.sword_screen.value,spell.shield),"screen value "+choice)
				if spell.opcode=="status": check(sim.t01.layers(p,spell.statuses[0].status)>0 or not p.thunder_shields.is_empty(),"self status effect "+id+choice)
				if spell.opcode=="enchant": check(not p.weapon_enchantment.is_empty(),"enchant pending")
				if spell.opcode=="weapon_barrier": check(p.barrier>0,"weapon shield present")
			check(registry.get_item(id).icon_path.is_empty(),"empty icon "+id)

func test_modes_controls() -> void:
	var sim := battle("base.spell.metal_01")
	var p: PartyMemberState = sim.state.teams[0][0]
	sim.advance(4)
	check(sim.state.item_runtime.spell.activation_count==0,"manual at zero waits")
	sim.timeline.set_mode("spell",true)
	check(sim.state.item_runtime.spell.activation_count==1,"auto from ready activates once")
	sim.advance(1)
	var remaining := sim.timeline.remaining("spell")
	sim.timeline.set_mode("spell",false)
	check(sim.timeline.remaining("spell")==remaining,"mode preserves remaining")
	sim.timeline.apply_control(p,"disrupt","all",8_000_000,"source.a",sim.state.time_usec)
	sim.timeline.set_speed("spell","haste",.2,sim.state.time_usec)
	check(is_equal_approx(sim.timeline.timers.spell.speed,.95),"speed additive +20 -25 = .95")
	sim.advance(1)
	check(abs(sim.timeline.remaining("spell")-(remaining-950000))<=1,"disrupt runs old work at .95")
	sim.timeline.clear_control(p,"all",["disrupt"],sim.state.time_usec)
	check(is_equal_approx(sim.timeline.timers.spell.speed,1.2),"clearing disrupt recomputes without resetting")
	sim.timeline.apply_control(p,"disable","items",3_000_000,"a",sim.state.time_usec)
	check(sim.timeline.blocked("weapon",sim.state.time_usec) and not sim.timeline.blocked("spell",sim.state.time_usec),"disable only items")
	sim.timeline.apply_control(p,"silence","spells",3_000_000,"a",sim.state.time_usec)
	sim.advance(1)
	sim.timeline.apply_control(p,"silence","spells",3_000_000,"b",sim.state.time_usec)
	check(sim.timeline.controls[p.id+":silence:spells"].source=="b","latest source owns silence")
	sim.timeline.cleanse(p,sim.state.time_usec)
	check(sim.timeline.blocked("spell",sim.state.time_usec),"ordinary cleanse cannot clear silence")
	sim.timeline.clear_control(p,"spells",["silence"],sim.state.time_usec)
	check(sim.timeline.remaining("spell")==sim.timeline.full_cd("spell"),"early clear restarts complete CD")
	sim.timeline.apply_control(p,"root","weapons",2_000_000,"root",sim.state.time_usec)
	check(sim.timeline.blocked("weapon",sim.state.time_usec) and not sim.timeline.blocked("spell",sim.state.time_usec),"root only weapons")
	sim.timeline.apply_control(p,"weakness","all",5_000_000,"weak",sim.state.time_usec)
	check(p.temporary_effects.has("weakness"),"weakness active")
	sim.timeline.cleanse(p,sim.state.time_usec)
	check(not p.temporary_effects.has("weakness"),"cleanse weakness")

func test_special() -> void:
	var sim := battle("base.spell.metal_07","返锋")
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	sim.cultivation.add_barrier(p,20,"other")
	sim.advance(8)
	check(sim.timeline.request("spell"),"cast weapon barrier")
	var attributed := sim.cultivation.barrier_from(p,"base.spell.metal_07")
	var old := p.barrier
	sim.t01.forced_rolls.assign([0.0,.99])
	check(sim.timeline.request("weapon"),"use return edge")
	check(is_equal_approx(old-p.barrier,sim.t01.q(attributed*.5)),"return edge spends own source only")
	check(is_equal_approx(sim.cultivation.barrier_from(p,"other"),20),"other shield untouched")
	check(p.return_edge.is_empty(),"return edge single use")
	var thunder := battle("base.spell.thunder_03")
	p=thunder.state.teams[0][0]; e=thunder.state.teams[1][0]
	thunder.advance(8)
	thunder.t01.apply_status(e,"雷印",10,p,8_000_000)
	thunder.t01.apply_status(e,"连环",5,p,8_000_000)
	thunder.t01.forced_rolls.assign([0.0])
	thunder.timeline.request("spell")
	check(thunder.t01.layers(e,"雷印")==0 and thunder.t01.layers(e,"连环")==4,"chain spell one strike plus extra chain")
	var extra := battle("base.spell.water_02","裂冰")
	p=extra.state.teams[0][0]; e=extra.state.teams[1][0]
	e.armor_capacity_sources.test=100; e.armor=100
	extra.advance(6); extra.t01.forced_rolls.assign([0.0]); extra.timeline.request("spell")
	check(is_equal_approx(e.armor,62.8),"crack ice 28.6 normal + 8.6 armor-only")
	var many := battle()
	p=many.state.teams[0][0]
	for i in range(2,6): p.inventory.add_item("w"+str(i),"base.map_item.qingshi_short_sword",Vector2i(i,3))
	check(is_equal_approx(many.t01.costs(p,registry.get_item("base.map_item.qingshi_short_sword"),0).x,6.0),"five weapons 200 percent stamina")

func test_prepared() -> void:
	var sim := battle("base.spell.wind_05","留风")
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	sim.advance(8)
	var hp := p.hp
	var spirit := p.spirit
	sim.t01.forced_rolls.assign([0.0,.99])
	sim.timeline.request("enemy_weapon")
	check(p.hp==hp and is_equal_approx(spirit-p.spirit,6),"ready dodge avoids hit and pays on trigger")
	check(sim.t01.layers(p,"轻灵")==4,"dodge success produces agility")
	check(sim.timeline.remaining("spell")==8_000_000,"dodge restarts CD after actual trigger")
	var force := battle("base.spell.earth_06")
	p=force.state.teams[0][0]; e=force.state.teams[1][0]
	force.advance(10)
	force.t01.apply_status(e,"疲惫",10,p,10_000_000)
	force.t01.forced_rolls.assign([0.0])
	force.timeline.request("weapon")
	check(force.state.item_runtime.spell.activation_count==1 and force.t01.layers(e,"疲惫")==10,"forced critical does not consume fatigue")
	var tax := battle("base.spell.earth_07")
	p=tax.state.teams[0][0]; e=tax.state.teams[1][0]
	tax.advance(10)
	e.stamina=3.4
	var hp_before := p.hp
	tax.timeline.request("enemy_weapon")
	check(p.hp==hp_before and e.stamina==3.4 and tax.t01.layers(e,"重伤")==3,"tax interrupts unaffordable cast, no enemy fee, still injury")
	check(tax.state.item_runtime.spell.activation_count==1,"tax pays once")

func finish() -> void:
	print("CULTIVATION CHECKS %d; FAILURES %d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func add_spell(sim: BattleSimulation, member: PartyMemberState, id: String, key: String, cell: Vector2i, choice := "") -> void:
	var raw: Dictionary = registry.library.spells[id]
	learn(member,raw.book_id,int(raw.learned_at_book_level)+1,choice)
	member.inventory.locked=false
	check(member.inventory.add_item(key,id,cell),"additional spell placed "+id)
	sim.attach(member,0 if member==sim.state.teams[0][0] else 1,key,false)
	sim.timeline.set_mode(key,false)

func test_boundaries() -> void:
	var sim := battle()
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	var expected := [3.0,3.8,4.5,5.3,6.0]
	for n in 5:
		if n>0: check(p.inventory.add_item("extra"+str(n),"base.map_item.qingshi_short_sword",Vector2i(n,3)),"weapon limit removed "+str(n+1))
		check(is_equal_approx(sim.t01.costs(p,registry.get_item("base.map_item.qingshi_short_sword"),0).x,expected[n]),"weapon fee "+str(n+1))
	check(not sim.timeline.apply_control(p,"typo","all",3_000_000,"a",0) and not sim.timeline.error.is_empty(),"unknown control rejected explicitly")
	check(not sim.timeline.apply_control(p,"disable","all",3_000_000,"a",0),"disable cannot include spells")
	check(sim.timeline.block_next_round("weapon",0),"voucher during countdown")
	check(not sim.timeline.block_next_round("weapon",0) and not sim.timeline.error.is_empty(),"undecided multi voucher rejected")
	p.stamina=0
	sim.advance(5.5)
	check(sim.timeline.remaining("weapon")==5_500_000 and not sim.timeline.timers.weapon.get("block_next",false),"voucher at zero consumed without affordable target")
	p.stamina=100
	sim.advance(5.5)
	check(sim.timeline.block_next_round("weapon",sim.state.time_usec) and sim.timeline.remaining("weapon")==0,"ready voucher waits for application")
	check(sim.timeline.request("weapon") and sim.state.item_runtime.weapon.activation_count==0 and sim.timeline.remaining("weapon")==5_500_000,"ready voucher cancels one application")
	sim.timeline.apply_control(p,"freeze","all",2_000_000,"f",sim.state.time_usec)
	var work := sim.timeline.remaining("weapon")
	sim.advance(1)
	check(sim.timeline.remaining("weapon")==work,"freeze preserves remaining work")
	sim.timeline.clear_control(p,"all",["freeze"],sim.state.time_usec)
	sim.advance(1)
	check(sim.timeline.remaining("weapon")==work-1_000_000,"release resumes work")
	var exhausted := battle()
	exhausted.state.teams[0][0].stamina=0; exhausted.state.teams[1][0].stamina=0
	exhausted.advance(.1)
	check(exhausted.state.result=="draw","resource exhausted board draws")
	var paralysis := battle()
	p=paralysis.state.teams[0][0]
	p.paralyzed_until=6_000_000
	paralysis.advance(5.5)
	check(paralysis.timeline.remaining("weapon")==5_500_000,"paralysis skips round exactly at zero")
	var equal := battle()
	equal.state.teams[0][0].paralyzed_until=5_500_000
	equal.timeline.set_mode("weapon",true); equal.advance(5.5)
	check(equal.state.item_runtime.weapon.activation_count==1,"paralysis expires before simultaneous activation")
	var command := battle("base.spell.metal_06","疾御")
	p=command.state.teams[0][0]
	command.advance(6)
	command.timeline.change_cd("weapon",3_000_000,command.state.time_usec)
	var old_cd := command.timeline.remaining("weapon")
	var old_spirit := p.spirit
	command.t01.forced_rolls.assign([0.0,.99])
	check(command.timeline.request("spell","weapon"),"manual command chooses eligible weapon")
	check(command.timeline.remaining("weapon")==old_cd and command.state.item_runtime.weapon.activation_count==0,"external command preserves weapon cycle")
	check(is_equal_approx(old_spirit-p.spirit,4.5),"fast command fee branch")
	var union := battle("base.spell.metal_08","主兵")
	p=union.state.teams[0][0]
	p.inventory.add_item("second","base.map_item.qingshi_short_sword",Vector2i(1,3)); union.attach(p,0,"second",false); union.timeline.set_mode("second",false)
	union.advance(6)
	old_cd=union.timeline.remaining("weapon")
	p.stamina=3.8
	union.t01.forced_rolls.assign([0.0,.99])
	check(union.timeline.request("spell") and p.stamina==0,"union charges two separately rounded half fees once")
	check(union.timeline.remaining("weapon")==old_cd and union.state.item_runtime.second.activation_count==0,"union preserves participant CDs")
	var tax := battle("base.spell.earth_07")
	p=tax.state.teams[0][0]; e=tax.state.teams[1][0]
	add_spell(tax,e,"base.spell.wind_05","enemy_dodge",Vector2i(2,0))
	tax.advance(10)
	e.spirit=6
	tax.t01.forced_rolls.assign([0.0,.99])
	var old_hp := e.hp
	tax.timeline.request("weapon")
	check(e.hp<old_hp and e.spirit==6 and tax.state.item_runtime.enemy_dodge.activation_count==0,"tax cancels unaffordable prepared dodge before effect")
	check(tax.state.item_runtime.spell.activation_count==1 and tax.timeline.remaining("enemy_dodge")==8_000_000,"tax paid once and failed prepared restarts")
	var guard := battle("base.spell.earth_05","蓄岳")
	p=guard.state.teams[0][0]; e=guard.state.teams[1][0]
	guard.advance(8)
	guard.t01.apply_status(p,"坚韧",10,p,8_000_000)
	guard.t01.forced_rolls.assign([0.0,.01])
	guard.timeline.request("enemy_weapon")
	check(guard.t01.layers(p,"坚韧")==14,"guard bypasses tenacity consume then grants4")
	check(is_equal_approx(p.maximum("hp")-p.hp,11.0),"guard suppresses critical and applies20 percent reduction: "+str(p.maximum("hp")-p.hp))
	var disabled := battle("base.spell.wind_05")
	p=disabled.state.teams[0][0]
	disabled.timeline.set_enabled("spell",false); disabled.advance(8)
	check(disabled.cultivation.prepared(p,"dodge",8_000_000).is_empty(),"prepared off ignores trigger")
	disabled.timeline.set_enabled("spell",true); p.spirit=0
	check(disabled.cultivation.prepared(p,"dodge",8_000_000).is_empty(),"prepared short of resource remains waiting")
	p.spirit=6
	check(disabled.cultivation.prepared(p,"dodge",8_000_000)=="spell","resource restored reopens eligible trigger")

func test_shield_order() -> void:
	var sim := battle()
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	sim.advance(6)
	p.hp=1; e.hp=1
	p.sword_screen={"value":1.0,"absorption":.4,"counter":15.0}
	sim.t01.forced_rolls.assign([0.0,.99,0.0])
	sim.timeline.request("enemy_weapon")
	check(e.hp==0 and p.hp==1,"broken screen counter kills attacker before lethal remainder")
	var mixed := battle("base.spell.fire_03")
	p=mixed.state.teams[0][0]; e=mixed.state.teams[1][0]
	mixed.advance(8)
	mixed.t01.apply_status(e,"灼烧",5,p,8_000_000)
	e.thunder_shields.assign([1.0]); mixed.cultivation.add_barrier(e,30,"other")
	mixed.t01.forced_rolls.assign([0.0])
	mixed.timeline.request("spell")
	check(e.thunder_shields.is_empty() and e.barrier==30,"burst shares original special-shield type and cannot switch to barrier")
	var replacement := battle("base.spell.metal_03","返剑")
	p=replacement.state.teams[0][0]; e=replacement.state.teams[1][0]
	learn(p,"base.cultivation_book.thunder_03",3,"盾破留印")
	replacement.advance(8); p.thunder_shields.assign([10.0,20.0])
	replacement.timeline.request("spell")
	check(p.thunder_shields.is_empty() and e.paralyzed_until==10_000_000 and replacement.t01.layers(e,"雷印")==0,"replacement only total paralysis, no broken-shield responses")
	var kill := battle("base.spell.wood_04","枯荣夺生")
	p=kill.state.teams[0][0]; e=kill.state.teams[1][0]
	kill.advance(10); e.hp=20; kill.t01.forced_rolls.assign([0.0])
	kill.timeline.request("spell")
	check(kill.t01.layers(p,"生机")==2,"lethal hit retains self feedback from actual HP loss")
	var thunder := battle("base.spell.thunder_01")
	p=thunder.state.teams[0][0]; e=thunder.state.teams[1][0]
	learn(p,"base.cultivation_book.thunder_03",5,"双霆引印")
	thunder.advance(4); e.hp=25; thunder.t01.apply_status(e,"雷印",20,p,4_000_000); thunder.t01.forced_rolls.assign([0.0])
	thunder.timeline.request("spell")
	check(e.hp==0 and thunder.t01.layers(e,"雷印")==10,"double lightning first strike kills, no second10 consumed")

func test_book_rules() -> void:
	var sim := battle("base.spell.metal_01")
	var p: PartyMemberState = sim.state.teams[0][0]
	learn(p,"base.cultivation_book.metal_02",1,"锐金")
	check(not sim.cultivation.general(p,"metal",1,"锐金"),"general learned but unequipped inactive")
	check(p.inventory.add_item("general","base.cultivation_book.metal_02",Vector2i(3,0)),"general occupies1")
	sim.attach(p,0,"general",true)
	check(not sim.cultivation.general(p,"metal",1,"锐金"),"general insertion CD inactive")
	sim.advance(3)
	check(sim.cultivation.general(p,"metal",1,"锐金"),"general active after entry")
	sim.timeline.apply_control(p,"disable","items",3_000_000,"enemy",3_000_000)
	check(not sim.cultivation.general(p,"metal",1,"锐金"),"disabled general listener inactive")
	learn(p,"base.cultivation_book.metal_03",1,"回锋")
	check(sim.cultivation.spec(p,"metal",1,"回锋"),"specialization passive requires no book slot")
	var k := CultivationKnowledge.new()
	check(k.acquire(registry.library,"base.cultivation_book.metal_04") and k.level("base.cultivation_book.metal_04")==0,"acquire at zero without free spell")
	var copy := CultivationKnowledge.new()
	check(copy.restore(k.snapshot(),registry.library,4) and copy.learned.has("base.cultivation_book.metal_04"),"zero-stage acquisition survives reload")
	check(not copy.restore({"version":1,"learned":{"bad.id":{"level":0,"branches":{}}}},registry.library,4),"unknown zero-stage book rejected")
	var bag := InventoryState.new(registry,Vector2i(3,3))
	check(bag.add_item("vertical","base.cultivation_book.metal_04",Vector2i(2,1),true),"book two cells vertical fit")
	check(bag.item_at(Vector2i(2,2))=="vertical" and not bag.add_item("blocked","base.spell.metal_01",Vector2i(2,2)),"vertical occupancy respected")
	check(not bag.move_item("vertical",Vector2i(2,2)),"vertical out-of-bounds rejected")
	var bad: Dictionary = registry.library.spells["base.spell.metal_01"].duplicate(true)
	bad.silent_new_effect=10
	check(not CultivationLibrary.validate_spell(bad),"unknown spell property rejected")
	bad.erase("silent_new_effect"); bad.opcode="unknown"
	check(not CultivationLibrary.validate_spell(bad),"unknown opcode rejected")

func test_attribution_and_weights() -> void:
	var sim := battle()
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	sim.cultivation.add_barrier(p,20,"base.spell.metal_07")
	sim.cultivation.add_barrier(p,30,"orb")
	sim.cultivation.spend_barrier(p,10)
	check(p.barrier==40 and sim.cultivation.barrier_from(p,"base.spell.metal_07")==20 and sim.cultivation.barrier_from(p,"orb")==20,"approved other origins consumed before weapon barrier")
	sim.cultivation.spend_barrier(p,25)
	check(p.barrier==15 and sim.cultivation.barrier_from(p,"base.spell.metal_07")==15,"weapon origin consumed only after all other origins")
	var body := ItemData.new({"id":"test.armor.body","name":"测试身甲","type":"armor","category":"armor","tags":[],"effects":[],"size":[1,1],"cooldown":0,"armor_type":"轻甲","armor_slot":"身甲","element":"base.element.water"})
	var shield := ItemData.new({"id":"test.armor.shield","name":"测试盾","type":"armor","category":"armor","tags":[],"effects":[],"size":[2,1],"cooldown":0,"armor_type":"重甲","armor_slot":"盾","element":"base.element.none"})
	registry._items[body.id]=body; registry._items[shield.id]=shield
	p.inventory.add_item("earlier_shield",shield.id,Vector2i.ZERO)
	p.inventory.add_item("later_body",body.id,Vector2i(0,1))
	sim.t01.refresh_equipment(p)
	check(p.armor_type=="轻甲","equal weights armor resolves to body even later in scan")
	check(p.defense_element=="base.element.none","equal element weights independently scan NONE first")
	p.inventory.take("later_body")
	var other := ItemData.new({"id":"test.armor.other","name":"测试轻盾","type":"armor","category":"armor","tags":[],"effects":[],"size":[2,1],"cooldown":0,"armor_type":"轻甲","armor_slot":"盾"})
	registry._items[other.id]=other
	p.inventory.add_item("other",other.id,Vector2i(2,0))
	sim.t01.refresh_equipment(p)
	check(p.armor_choice_required and sim.t01.configuration_issue().contains("甲型"),"exceptional tie without body needs explicit player selection")
	p.armor_choice="轻甲"; sim.t01.refresh_equipment(p)
	check(not p.armor_choice_required and p.armor_type=="轻甲","exceptional tie command accepts only highest candidates")
	var mixed := battle()
	p=mixed.state.teams[0][0]; e=mixed.state.teams[1][0]
	learn(e,"base.cultivation_book.thunder_03",5,"雷罡反震")
	mixed.advance(6)
	p.weapon_enchantment={"ratio":.5}
	p.hp=1
	e.thunder_shields.assign([5.0,100.0])
	mixed.t01.forced_rolls.assign([0.0,.99,0.0])
	mixed.timeline.request("weapon")
	check(p.hp==0 and e.hp==e.maximum("hp"),"shield reflection stops entire mixed attack before HP stage")
	# 11*1.2 + (11*.5)*1.1 = 19.3; .6 absorption -> 11.6.
	check(e.thunder_shields.size()==1 and is_equal_approx(e.thunder_shields[0],93.4),"reflection base uses actual full shield loss across both packets")
	var frost := battle("base.spell.water_01","覆霜")
	p=frost.state.teams[0][0]; e=frost.state.teams[1][0]
	learn(p,"base.cultivation_book.water_03",1,"初霜")
	frost.advance(4); frost.t01.apply_status(e,"润脉",3,e,4_000_000)
	frost.t01.forced_rolls.assign([0.0])
	frost.timeline.request("spell")
	check(frost.t01.layers(e,"寒霜")==1 and e.frozen_until==0,"initial frost bonus survives cancellation but cannot trigger in same attack")

func test_passives_and_recovery() -> void:
	var sim := battle()
	var p: PartyMemberState = sim.state.teams[0][0]
	var e: PartyMemberState = sim.state.teams[1][0]
	learn(p,"base.cultivation_book.wood_03",5,"生生不息")
	p.knowledge.choose(registry.library,"base.cultivation_book.wood_03",2,"养生")
	p.knowledge.choose(registry.library,"base.cultivation_book.wood_03",4,"生息绵长")
	p.hp=p.maximum("hp")-6
	sim.t01.apply_status(p,"生机",10,p,0)
	sim.advance(2)
	check(p.hp==p.maximum("hp") and is_equal_approx(p.barrier,3.5),"life 30 percent strengthening;13 heal uses6, overflow7 creates3.5 shield")
	var old_barrier := p.barrier
	sim.advance(1)
	check(p.barrier==old_barrier,"life starting full gives no overflow shield")
	var resources := battle()
	p=resources.state.teams[0][0]
	learn(p,"base.cultivation_book.water_03",3,"盈流成护")
	resources.t01.apply_status(p,"润脉",10,p,0)
	resources.advance(2)
	check(p.barrier==10,"both resources full convert20 directly at50 percent")
	var frost := battle("base.spell.water_01","覆霜")
	p=frost.state.teams[0][0]; e=frost.state.teams[1][0]
	learn(p,"base.cultivation_book.water_03",4,"玄霜")
	p.knowledge.choose(registry.library,"base.cultivation_book.water_03",3,"霜回活水")
	frost.advance(4); frost.t01.forced_rolls.assign([0.0]); frost.timeline.request("spell")
	check(e.frozen_until==5_000_000 and frost.t01.layers(p,"润脉")==1,"frost specialization extends to1s and returns one resource layer")
	var poison := battle()
	p=poison.state.teams[0][0]; e=poison.state.teams[1][0]
	learn(p,"base.cultivation_book.wood_03",4,"蚀骨渐深")
	p.knowledge.choose(registry.library,"base.cultivation_book.wood_03",2,"蚀骨")
	poison.timeline.apply_control(p,"weakness","all",5_000_000,"enemy",0)
	poison.t01.apply_status(e,"毒蚀",10,p,0)
	poison.advance(2)
	check(is_equal_approx(e.maximum("hp")-e.hp,13),"poison30 percent specialization unaffected by weakness")
	check(is_equal_approx(poison.t01.adjusted_damage(p,e,100,"钝击","base.element.none",2_000_000,{"kind":"active"},true),80),"weakness direct reduction20 percent")
	var thunder := battle()
	p=thunder.state.teams[0][0]
	learn(p,"base.cultivation_book.thunder_03",4,"雷罡凝实")
	p.knowledge.choose(registry.library,"base.cultivation_book.thunder_03",2,"凝罡")
	learn(p,"base.cultivation_book.thunder_02",1,"雷罡")
	p.inventory.add_item("thunder_general","base.cultivation_book.thunder_02",Vector2i.ZERO); thunder.attach(p,0,"thunder_general",false)
	thunder.t01.apply_status(p,"雷蕴",10,p,0)
	check(p.thunder_shields==[140.0] and thunder.cultivation.absorption(p)==.8,"new thunder shield +10+20+10 percent and absorption80 percent")
	var return_flow := battle("base.spell.water_08","回澜")
	p=return_flow.state.teams[0][0]; e=return_flow.state.teams[1][0]
	return_flow.advance(10)
	p.spirit=p.maximum("spirit")*.2+20; p.stamina=p.maximum("stamina")*.5
	e.spirit=e.maximum("spirit")*.5; e.stamina=e.maximum("stamina")*.5
	var before_spirit := p.spirit-20
	var before_stamina := p.stamina
	return_flow.t01.forced_rolls.assign([0.0]); return_flow.timeline.request("spell")
	# SPELL against NONE:60*(1.1+.5)=96; R=96*.5/1.5=32.
	check(is_equal_approx(p.spirit-before_spirit,22.9) and is_equal_approx(p.stamina-before_stamina,9.1),"return flow splits32 inverse to current20/50 percent ratios")
	var tax := battle("base.spell.earth_07")
	p=tax.state.teams[0][0]; e=tax.state.teams[1][0]
	add_spell(tax,e,"base.spell.earth_07","enemy_tax",Vector2i.ZERO)
	tax.advance(10); tax.t01.forced_rolls.assign([0.0,.99]); tax.timeline.request("enemy_weapon")
	check(tax.state.item_runtime.spell.activation_count==1 and tax.state.item_runtime.enemy_tax.activation_count==1,"mutual prepared taxes each settle once without recursion")
	var control := battle("base.spell.metal_01")
	p=control.state.teams[0][0]
	control.advance(4); control.clock.paused=true; control.timeline.set_mode("spell",true)
	check(control.state.item_runtime.spell.activation_count==0,"mode change while paused never casts")
	control.clock.paused=false; control.timeline.wake(control.state.time_usec)
	check(control.state.item_runtime.spell.activation_count==1,"resuming wakes ready automatic spell")
	control.timeline.apply_control(p,"silence","spells",3_000_000,"a",4_000_000)
	control.advance(1)
	control.timeline.clear_control(p,"spells",["silence"],5_000_000)
	control.advance(2)
	check(control.timeline.remaining("spell")==2_000_000,"stale natural end cannot restart CD after early release")
