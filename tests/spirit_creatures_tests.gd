extends SceneTree

var registry := ContentRegistry.new()
var checks := 0
var failures := 0
const CASES := [
	["biyetengling",144,42,28,18,6,20,10], ["xiwenlingyuan",160,40,24,16,5,22,12],
	["taibeishiling",184,64,56,56,4,24,12], ["lanlinglingsun",136,24,60,11,5,26,14],
	["qingfenglingtang",136,84,48,14,4,28,16], ["yanbilingyuan_huguo",208,110,72,92,9,50,28],
	["yanbilingyuan_shouxue",240,126,80,106,9,60,34]
]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)
func enemy(slug: String) -> PartyMemberState:
	var member := PartyMemberState.new(registry.get_enemy("base.enemy."+slug),registry)
	member.equip_definition_loadout()
	return member
func dummy() -> PartyMemberState:
	var raw := registry.get_character("base.character.chen_yu")
	raw.id="test.target"; raw.cultivation_rank="base.cultivation.qi_refining"
	raw.max_hp=100000; raw.max_stamina=10000; raw.max_spirit=10000
	return PartyMemberState.new(raw,registry)
func instance(member: PartyMemberState, suffix: String) -> String:
	for entry: Dictionary in member.inventory.get_instances():
		if entry.item_id.ends_with(suffix): return entry.instance_id
	return ""
func duel(member: PartyMemberState) -> BattleSimulation:
	var sim := BattleSimulation.new([dummy()],[member],registry)
	check(sim.start(),"simulation starts: "+sim.configuration_error)
	return sim
func run() -> void:
	check(registry.load_base_content(),"content loads: "+str(registry.errors))
	if not registry.errors.is_empty(): quit(1); return
	var catalog := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(catalog.error.is_empty(),"inventory catalog: "+catalog.error)
	if not catalog.error.is_empty(): quit(1); return
	check(registry.register_item({"id":"base.test.spirit_sword","name":"结算测试剑","type":"weapon","category":"weapon","quality":"凡品","tags":[],"size":[1,1],"cooldown":4,"stamina_cost":1,"rule_version":1,"combat":{"source_location":"isolated test only","hit_chance":1.0},"effects":[{"trigger":"on_activate","effect":"damage","value":100,"damage_type":"斩击"}]}),"register isolated lethal fixture")
	for row: Array in CASES:
		var member := enemy(row[0]); var sim := duel(member)
		check(member.hp==row[1] and member.stamina==row[2] and member.spirit==row[3] and member.armor==row[4],row[0]+" exact equipped full resources")
		check(member.inventory.get_instances().size()==row[5],row[0]+" loadout count")
		check(member.definition.progression_rewards.cultivation==row[6] and member.definition.progression_rewards.experience==row[7],row[0]+" reward values")
		check(registry.enemy_battle_error(member.id).is_empty(),row[0]+" art ready")
		check(member.board.grid_size==Vector2i(4,4 if row[0].begins_with("yanbilingyuan") else 3),"board dimensions")
		for entry: Dictionary in member.inventory.get_instances():
			var item := registry.get_item(entry.item_id)
			check((load(item.icon_path) as Texture2D).get_image().has_mipmaps(),"mipmap "+item.id)
		sim.advance(2.6)
		check(not sim.drain_events().any(func(e:Dictionary):return e.kind=="item_activated"),"first cast waits full CD")
		sim.advance(12)
		check(sim.drain_events().any(func(e:Dictionary):return e.kind=="damage"),row[0]+" attacks execute")
		var fighter:=dummy()
		check(fighter.inventory.add_item("test.sword", "base.test.spirit_sword", Vector2i.ZERO),"equip live attack fixture")
		var opponent:=enemy(row[0])
		var full:=BattleSimulation.new([fighter],[opponent],registry)
		check(full.start(),"full battle starts")
		full.advance(300)
		check(full.state.result=="victory" and opponent.hp==0,row[0]+" actual attacks finish battle")
		var materials: Array = member.definition.loot
		var rolls: Array = []; rolls.resize(materials.size()); rolls.fill(0.0)
		var remaining: Array = member.inventory.get_instances().map(func(e:Dictionary):return e.item_id)
		var reward := BattleLoot.candidate(catalog.state,member.definition,"test."+row[0],rolls,remaining)
		check(reward.error.is_empty() and reward.drops.size()==materials.size(),"all eligible 25% rolls can drop")
		for drop: String in reward.drops:
			check(registry.get_item(drop).quality=="凡品" and registry.get_item(drop).effects.is_empty(),"drop is inert mortal-quality material")
	test_periodic()
	test_thresholds()
	test_combo()
	test_buff_and_fruit(catalog.state)
	test_reinsertion_and_order()
	test_validation()
	print("SPIRIT CREATURES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func test_periodic() -> void:
	for row: Array in [["biyetengling",10,7],["xiwenlingyuan",9,8],["yanbilingyuan_huguo",6,3]]:
		var member := enemy(row[0]); var sim := duel(member)
		sim.timeline.set_all(member,false)
		member.spirit=0; member.stamina=0
		sim.advance(row[1]-.01)
		check(member.spirit==0,"periodic no immediate tick")
		sim.advance(.01)
		check(member.spirit==row[2],"periodic first exact tick")
		if row[0].begins_with("yanbi"): check(member.stamina==6,"dual periodic resources")
		member.hp=0; var before:=member.spirit
		sim.advance(row[1]); check(member.spirit==before,"death prevents periodic healing")

func test_thresholds() -> void:
	var member := enemy("lanlinglingsun"); var sim := duel(member)
	for entry: Dictionary in member.inventory.get_instances(): sim.timeline.set_mode(entry.instance_id,false)
	var id := instance(member,"guixiweiyu")
	sim.timeline.set_mode(id,true)
	sim.advance(12)
	check(sim.state.item_runtime[id].activation_count==0 and sim.timeline.remaining(id)==0,"tail ready at full CD, waits for threshold")
	member.stamina=9.6; sim._wake_items(sim.state.time_usec)
	check(member.stamina==21.6 and member.spirit==57,"40% inclusive and costs once")
	member.stamina=0; sim.advance(12)
	check(sim.state.item_runtime[id].activation_count==2,"second allowed use")
	member.stamina=0; sim.advance(24)
	check(member.stamina==0 and sim.state.item_runtime[id].activation_count==2,"two-use limit")
	# Reinsertion of the same unit cannot renew use count or refill resources.
	sim.detach(id); sim.attach(member,1,id,true)
	check(not sim.item_rules.available(id) and member.stamina==0,"reinsertion retains use limit without refill")
	var stone := enemy("taibeishiling"); var s := duel(stone)
	s.timeline.set_all(stone,false); var repair:=instance(stone,"jutu");s.timeline.set_mode(repair,true)
	s.advance(13);check(stone.spirit==56 and s.state.item_runtime[repair].activation_count==0,"full armor skips cost")
	stone.armor=40;s._wake_items(s.state.time_usec)
	check(stone.armor==51 and stone.spirit==52 and s.t01.layers(stone,"坚韧")==3,"damaged armor repairs and gains tenacity")

func test_combo() -> void:
	for row: Array in [["qingfenglingtang","qingfenglianzhi",3.8,.2,3],["yanbilingyuan_huguo","lianbizhongchui",8.2,.3,6]]:
		var member := enemy(row[0]);var sim := duel(member)
		sim.timeline.set_all(member,false);var id:=instance(member,row[1]);sim.timeline.set_mode(id,true)
		for i in 20:sim.t01.forced_rolls.append(.1)
		sim.advance(row[2]);var first:=sim.drain_events().filter(func(e:Dictionary):return e.kind=="damage" and e.get("instance_id")==id)
		var stamina:=member.stamina
		check(first.size()==1,"combo first hit at CD")
		sim.advance(row[3]-.01);check(not sim.drain_events().any(func(e:Dictionary):return e.kind=="damage"),"combo gap respected")
		sim.advance(.01);check(sim.drain_events().filter(func(e:Dictionary):return e.kind=="damage").size()==1 and member.stamina==stamina,"second hit no duplicate fee")

func test_buff_and_fruit(catalog: MapLoadoutState) -> void:
	var member:=enemy("yanbilingyuan_huguo");var sim:=duel(member)
	sim.timeline.set_all(member,false)
	member.hp=83.2;sim._wake_items(0)
	var base:=sim.t01.adjusted_damage(member,sim.state.teams[0][0],10,"钝击","base.element.none",0,{},true)
	check(base==12,"low HP buffs physical by 20%")
	check(sim.t01.adjusted_damage(member,sim.state.teams[0][0],10,"法术型","base.element.earth",0,{},true)==11,"buff excludes spells")
	sim.advance(8);check(sim.t01.adjusted_damage(member,sim.state.teams[0][0],10,"钝击","base.element.none",8000000,{},true)==10,"buff expires without retrigger")
	var fruit:=instance(member,"shanlingguo");sim.timeline.set_mode(fruit,true)
	member.hp=100;member.stamina=0;sim.advance(4)
	check(member.inventory.get_instance(fruit).is_empty(),"fruit consumed once at first CD and HP<=60%")
	var hp:=member.hp;var stamina:=member.stamina
	sim.advance(6)
	check(member.hp==hp+18 and member.stamina==stamina+30,"fruit delivers both resources three times plus one skin tick")
	var rolls: Array=[];rolls.resize(member.definition.loot.size());rolls.fill(0.0)
	var reward:=BattleLoot.candidate(catalog,member.definition,"fruit.eaten",rolls,member.inventory.get_instances().map(func(e:Dictionary):return e.item_id))
	check(reward.drops.size()==3 and not reward.drops.has("base.material.yanbilingyuan_shanlingguo"),"consumed fruit excluded from drops")
	rolls.fill(.25)
	check(BattleLoot.candidate(catalog,member.definition,"boundary",rolls).drops.is_empty(),"25% boundary excluded, no first-kill guarantee")
	for suffix in ["yanyuanzhanggu","yanyuanbigu"]:
		var item:=registry.get_item("base.organ.yanbilingyuan_"+suffix)
		check(item.cooldown_usec==0 and item.effects.is_empty(),"bones never attack")
	check(registry.get_item("base.organ.biyetengling_huichunya").effects.is_empty() and not registry.get_item("base.organ.biyetengling_chouya").effects.is_empty(),"bud separate from sprout")

func test_validation() -> void:
	var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/items/lanlinglingsun_guixiweiyu.json"))
	for patch: Dictionary in [{"battle_use_limit":0},{"activation_threshold":{"resource":"armor","numerator":1,"denominator":2}},{"periodic_restore":{"interval":0,"resources":{"spirit":1}}},{"resource_bonuses":{"bad":10}},{"multi_hit":{"count":2,"interval":0}}]:
		var bad:=raw.duplicate(true);bad.combat.merge(patch,true)
		check(not T01Definition.runtime_error(bad).is_empty(),"invalid common rule rejected")

func test_reinsertion_and_order() -> void:
	var member:=enemy("biyetengling");var sim:=duel(member)
	sim.timeline.set_all(member,false);member.spirit=0
	sim.advance(5)
	var id:=instance(member,"xulubao")
	sim.detach(id);sim.attach(member,1,id,true)
	sim.advance(4.99);check(member.spirit==0,"reinsertion does not grant immediate periodic recovery")
	sim.advance(.01);check(member.spirit==7,"reinsertion preserves original ten-second deadline")
	var falcon:=enemy("lanlinglingsun");var f:=duel(falcon)
	f.timeline.set_all(falcon,false);var tail:=instance(falcon,"guixiweiyu");f.timeline.set_mode(tail,true)
	falcon.spirit=0;f.advance(12)
	check(f.timeline.remaining(tail)==0,"unmet threshold stays ready even without payment resources")
	var stone:=enemy("taibeishiling");var s:=duel(stone)
	var shell:=instance(stone,"yanke")
	stone.inventory.take(shell);s.detach(shell)
	check(stone.maximum("spirit")==36 and stone.spirit==36,"removing resource capacity clamps current resource")
	# A lethal hit cannot activate a threshold passive on the corpse.
	var ape:=enemy("yanbilingyuan_huguo");var a:=duel(ape)
	ape.hp=0;a._wake_items(0)
	check(not ape.temporary_effects.has("base.organ.yanbilingyuan_hujing"),"dead owner never triggers low-HP buff")
