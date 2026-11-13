extends "res://tests/cultivation_combat_tests.gd"
const Attribution=preload("res://scripts/simulation/battle_attribution.gd")
const Stats=preload("res://scripts/simulation/battle_replay_stats.gd")
const Format=preload("res://scripts/presentation/battle_replay_format.gd")

func metrics(sim:BattleSimulation,id:String)->Dictionary:
	sim.drain_events()
	return sim.replay.item(id).get("metrics",{})

func mixed()->BattleSimulation:
	var sim:=battle()
	var p:PartyMemberState=sim.state.teams[0][0]
	check(p.inventory.add_item("second","base.map_item.qingshi_short_sword",Vector2i(3,3)),"second identical weapon")
	sim.attach(p,0,"second",false)
	check(sim._definitions.has("second"),"attach second")
	sim.timeline.set_all(p,false)
	return sim

func run()->void:
	check(registry.load_base_content(),"registry")
	check(MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag")).error.is_empty(),"catalog")
	if not failures.is_empty():finish();return
	test_sources()
	test_shields()
	test_events_and_format()
	test_contribution_totals()
	test_command_costs()
	test_derived_and_passive()
	test_support_and_replacement()
	var training:=CultivationTraining.new(actor("test.training"),registry)
	check(training.start(),"training still starts")
	training.advance(1);training.take_payments()
	check(not training.replay_enabled and training.replay.snapshot().items.is_empty(),"non-combat training does not collect battle history")
	print("REPLAY: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_sources()->void:
	var sim:=mixed()
	var p:PartyMemberState=sim.state.teams[0][0]
	var e:PartyMemberState=sim.state.teams[1][0]
	sim.t01.apply_status(e,"毒蚀",2,p,0,false,-1,sim.t01.item_source("weapon"))
	sim.t01.apply_status(e,"毒蚀",1,p,0,false,-1,sim.t01.item_source("second"))
	var origins:=Attribution.pool(e,"毒蚀")
	check(origins.size()==2 and is_equal_approx(origins[0].weight,2.0/3),"mixed layer weights")
	sim.advance(1)
	var a:=metrics(sim,"weapon")
	var b:=metrics(sim,"second")
	check(is_equal_approx(a.damage_total,2) and is_equal_approx(b.damage_total,1),"first poison tick follows pre-consumption layers")
	sim.advance(1)
	a=metrics(sim,"weapon");b=metrics(sim,"second")
	check(is_equal_approx(a.damage_total,3) and is_equal_approx(b.damage_total,2),"oldest layer consumed; next tick splits remaining layers")
	check(a.rotation==0 if a.has("rotation") else true,"DOT does not fabricate rotations")
	check(a.trigger==2 and b.trigger==2,"each participant counted once per tick")
	# Healing overflow uses the same actual amount, before deterministic share allocation.
	var healing:=mixed()
	p=healing.state.teams[0][0]
	p.hp=p.maximum("hp")-2.4
	healing.t01.apply_status(p,"生机",2,p,0,false,-1,healing.t01.item_source("weapon"))
	healing.t01.apply_status(p,"生机",1,p,0,false,-1,healing.t01.item_source("second"))
	healing.advance(1)
	check(is_equal_approx(metrics(healing,"weapon").hp_restored,1.6) and is_equal_approx(metrics(healing,"second").hp_restored,.8),"actual capped healing conserved")
	# Cancellation consumes origins in the same order as gameplay.
	var cancel:=mixed()
	p=cancel.state.teams[0][0];e=cancel.state.teams[1][0]
	cancel.t01.apply_status(e,"毒蚀",2,p,0,false,-1,cancel.t01.item_source("weapon"))
	cancel.t01.apply_status(e,"毒蚀",1,p,0,false,-1,cancel.t01.item_source("second"))
	cancel.t01.apply_status(e,"生机",2,e,0)
	origins=Attribution.pool(e,"毒蚀")
	check(origins.size()==1 and origins[0].instance_id=="second","opposition retains correct remaining origin")
	# Termination keeps last actual damage, including overkill cap, then freezes.
	e.hp=.7
	cancel.advance(1)
	a=metrics(cancel,"second")
	check(is_equal_approx(a.damage_total,.7) and cancel.replay.frozen,"terminal damage captured before cleaned states disappear")
	var snapshot:=cancel.replay.snapshot()
	cancel.replay.consume([{"kind":"damage","value":100,"instance_id":"second"}])
	check(cancel.replay.snapshot()==snapshot,"frozen snapshot cannot grow")

func test_shields()->void:
	var sim:=mixed()
	var p:PartyMemberState=sim.state.teams[0][0]
	var e:PartyMemberState=sim.state.teams[1][0]
	sim.t01.apply_status(p,"雷蕴",6,p,0,false,-1,sim.t01.item_source("weapon"))
	sim.t01.apply_status(p,"雷蕴",4,p,0,false,-1,sim.t01.item_source("second"))
	check(p.thunder_shields.size()==1 and p.thunder_shield_origins.size()==1,"thunder conversion tracks layer sources")
	check(is_equal_approx(metrics(sim,"weapon").shield_generated,60) and is_equal_approx(metrics(sim,"second").shield_generated,40),"generated shield shared by consumed layers")
	sim.t01.damage(e,p,10,"钝击","base.element.none",0,{"adjusted":true},false,{"special":true})
	check(is_equal_approx(metrics(sim,"weapon").shield_absorbed,3.6) and is_equal_approx(metrics(sim,"second").shield_absorbed,2.4),"thunder absorption follows actual FIFO shield")
	sim.t01.discard_special(p,"thunder_shield",1)
	check(is_equal_approx(metrics(sim,"weapon").shield_discarded,56.4),"replacement remainder is discarded, not absorbed")
	check(is_equal_approx(metrics(sim,"weapon").shield_absorbed,3.6),"replacement does not increase absorption")
	sim.record_trace.begin(sim.t01.record_source(p,sim.t01.item_source("weapon")),2)
	sim.cultivation.add_barrier(p,10,"fixture")
	sim.cultivation.add_barrier(p,20,"fixture")
	sim.record_trace.end()
	sim.t01.damage(e,p,10,"钝击","base.element.none",2,{"adjusted":true},false,{})
	check(is_equal_approx(metrics(sim,"weapon").generated_barrier,30),"ordinary shield records actual additions")
	check(is_equal_approx(metrics(sim,"weapon").absorbed_barrier,3),"ordinary shield owner absorption")
	check(is_equal_approx(sim.replay.unassigned_damage,20),"fixture unsourced attacker totals kept separate")
	var team_absorbed: float = sim.replay.snapshot().team_metrics[0].shield_absorbed
	var item_absorbed: float = metrics(sim,"weapon").shield_absorbed
	p.barrier += 10
	sim.t01.damage(e,p,10,"钝击","base.element.none",3,{"adjusted":true},false,{})
	sim.drain_events()
	check(is_equal_approx(sim.replay.snapshot().team_metrics[0].shield_absorbed,team_absorbed+3),"unattributed ordinary shield absorption remains in faction denominator")
	check(is_equal_approx(metrics(sim,"weapon").shield_absorbed,item_absorbed),"unattributed ordinary shield is not assigned to visible items")

func test_events_and_format()->void:
	var stats:=Stats.new()
	var events:Array[Dictionary]=[
		{"kind":"item_activated","record_sequence":1,"record_action_id":1,"instance_id":"x","stamina_cost":4},
		{"kind":"damage","record_sequence":2,"record_action_id":1,"record_group_id":1,"instance_id":"x","value":5,"armor_absorbed":4,"shield_absorbed":3},
		{"kind":"restore","record_sequence":3,"instance_id":"x","resource":"stamina","value":2}]
	stats.consume(events);stats.consume(events)
	var row:=stats.item("x")
	check(row.metrics.damage_total==12 and row.metrics.rotation==1,"unique raw events, shield+armor+hp")
	check(row.metrics.stamina_spent==4 and row.metrics.stamina_restored==2,"cost and recovery never netted")
	var item:=registry.get_item("base.map_item.qingshi_short_sword")
	var lines:=Format.lines(item,row)
	check(lines.size()==3 and lines[0].key=="damage_total" and lines[-1].key=="rotation","attack ordering")
	for mode in ["all","damage","recovery","defense","trigger"]:
		lines=Format.lines(item,row,mode)
		check(lines.size()<=3 and lines[-1].key=="rotation","rotation last "+mode)
	check(Format.lines(item,{})[0].value==0,"unactivated weapon shows damage zero")
	var recovery:=ItemData.new({"id":"test.recovery","name":"test","type":"artifact","tags":[],"cooldown":4,"effects":[{"trigger":"on_activate","effect":"restore_instant","resource":"hp"}],"size":[1,1]})
	lines=Format.lines(recovery,{"metrics":{"hp_restored":56,"stamina_restored":20,"spirit_restored":12,"rotation":4}})
	check(lines.size()==4 and lines[3].key=="rotation","three recovery rows plus rotation")
	check(Format.lines(recovery,{"metrics":{"rotation":4}}).size()==1,"zero recovery hidden")
	check(Format.formatted("stamina_spent",7.6)=="7.6","cost displayed without minus sign")

func test_contribution_totals() -> void:
	var details = preload("res://scripts/presentation/battle_replay_details.gd")
	var stats := Stats.new()
	var shared := [{"instance_id":"x", "side":0, "weight":2.0/3.0}, {"instance_id":"y", "side":0, "weight":1.0/3.0}]
	var events: Array[Dictionary] = [
		{"kind":"damage", "record_sequence":1, "record_group_id":1, "instance_id":"x", "side":0, "target_id":"enemy", "value":5, "armor_absorbed":4, "shield_absorbed":3, "critical":true},
		{"kind":"status_damage", "record_sequence":2, "record_group_id":2, "record_mode":"dot", "status":"灼烧", "replay_sources":shared, "target_id":"enemy", "value":3},
		{"kind":"damage", "record_sequence":3, "record_group_id":3, "side":0, "value":6},
		{"kind":"damage", "record_sequence":4, "record_group_id":4, "side":1, "value":9},
		{"kind":"miss", "record_sequence":5, "record_group_id":5, "instance_id":"x", "side":0},
		{"kind":"immune", "record_sequence":6, "record_group_id":6, "instance_id":"x", "side":0},
		{"kind":"status_applied", "record_sequence":7, "record_action_id":7, "status":"灼烧", "layers":2, "layers_before":0, "replay_sources":shared, "target_id":"enemy"},
		{"kind":"restore", "record_sequence":8, "side":0, "resource":"hp", "value":10},
		{"kind":"restore", "record_sequence":9, "instance_id":"x", "side":0, "resource":"hp", "value":5},
		{"kind":"restore", "record_sequence":10, "instance_id":"x", "side":0, "resource":"stamina", "value":0, "restore_reason":"resource_full"},
		{"kind":"status_failed", "record_sequence":11, "record_action_id":11, "instance_id":"x", "side":0, "status":"灼烧", "target_id":"enemy", "reason":"免疫"},
		{"kind":"status_removed", "record_sequence":12, "record_action_id":12, "instance_id":"x", "side":0, "status":"毒蚀", "target_id":"ally", "removal":"净化"},
	]
	stats.consume(events)
	stats.consume(events)
	stats.register([])
	var snapshot := stats.snapshot()
	var row := stats.item("x")
	check(snapshot.team_metrics[0].damage_total == 21 and snapshot.team_metrics[1].damage_total == 9, "team totals include unattributed damage and keep opponents separate")
	check(row.metrics.damage_total == 14 and row.effect_stats["灼烧"].metrics.damage_total == 2, "shared state damage keeps its effect and item attribution")
	check(row.metrics.attack_hits == 1 and row.metrics.attack_crits == 1, "periodic ticks do not count as attack hits or crits")
	check(row.metrics.attack_misses == 1 and row.metrics.attack_immune == 1, "miss and immunity have separate counts")
	check(snapshot.team_metrics[0].debuff_apply == 1 and row.effect_stats["灼烧"].metrics.debuff_apply == 1, "shared applications and repeated events are deduplicated")
	check(snapshot.team_metrics[0].hp_restored == 15, "restoration denominator includes other sources")
	var weapon := registry.get_item("base.map_item.qingshi_short_sword")
	var share: Dictionary = details.share(weapon, row, snapshot)
	check(is_equal_approx(share.ratio, 2.0/3.0) and not row.on_board, "departed items remain in full team share")
	check(details.share(weapon, {}, {}).percent == "—", "legacy snapshot without totals does not invent a percentage")
	check(details.primary_metric(registry.get_item("base.map_item.t01_0020")) == "stamina_restored", "stamina recovery uses its own resource denominator")
	check(details.primary_metric(registry.get_item("base.organ.xiwenlingyuan_shuixinang")) == "spirit_restored", "periodic resource recovery uses its defined resource")
	var dual_row := {"side":0, "metrics":{"hp_restored":12, "spirit_restored":6}}
	var dual_snapshot := {"team_metrics":[{"hp_restored":24, "spirit_restored":24}, {"hp_restored":100, "spirit_restored":100}]}
	var dual: Array = details.shares(registry.get_item("base.map_item.t01_0086"), dual_row, dual_snapshot)
	check(dual.size() == 2 and dual[0].percent == "50.0%" and dual[1].percent == "25.0%", "dual restoration uses separate same-faction denominators")
	dual_row.metrics.spirit_restored = 0
	check(details.shares(registry.get_item("base.map_item.t01_0086"), dual_row, dual_snapshot)[1].percent == "0.0%", "defined secondary recovery remains visible at zero actual restoration")
	for id in ["base.map_item.warm_jade", "base.map_item.t01_0027", "base.map_item.t01_0104"]:
		var combined: Array = details.shares(registry.get_item(id), {}, {})
		check(combined.size() == 2 and combined[0].key == "hp_restored" and combined[1].key == "stamina_restored", "hp and stamina recovery share cards for " + id)
	check(details.shares(weapon, row, snapshot).size() == 1, "other profiles retain one primary chart")
	check(row.restore_reasons.stamina == "resource_full", "zero recovery retains the actual cause")
	check(row.effect_stats["灼烧"].metrics.status_failed == 1 and row.effect_stats["毒蚀"].metrics.status_removed == 1, "failed applications and active removal stay in their effect rows")
	var supported := 0
	for definition: ItemData in registry._items.values():
		if definition.category not in ["weapon", "armor", "artifact", "pill", "throwable", "spell", "item"]: continue
		var formatted: Array = details.rows(definition, {"metrics": {}}, registry, {})
		if not formatted.is_empty() and formatted[0].key == details.primary_metric(definition): supported += 1
	check(supported > 100, "all registered combat item types produce a stable primary row")
	print("REPLAY_DETAIL_PROFILES: ", supported)

func test_command_costs()->void:
	for spell in ["base.spell.metal_06","base.spell.metal_08"]:
		var sim:=battle(spell)
		var p:PartyMemberState=sim.state.teams[0][0]
		sim.t01.forced_rolls.assign([0,.99,.99,.99])
		sim.cultivation.cast("spell",0)
		var a:=metrics(sim,"spell")
		var w:=metrics(sim,"weapon")
		check(a.get("damage_total",0)>0 and w.get("damage_total",0)==0,"command damage belongs to spell "+spell)
		check(a.get("spirit_spent",0)>0 and w.get("stamina_spent",0)>0,"separate actual fees "+spell)
		check(w.get("rotation",0)==0 and a.rotation==1,"command not weapon cycle "+spell)
		check(sim.replay.item("spell").participants==["weapon"],"participants retained "+spell)

func test_derived_and_passive()->void:
	for status in ["锋痕","附炎","寒霜"]:
		var sim:=mixed()
		var p:PartyMemberState=sim.state.teams[0][0]
		var e:PartyMemberState=sim.state.teams[1][0]
		sim.t01.apply_status(p if status=="附炎" else e,status,2,p,0,false,-1,sim.t01.item_source("second"))
		sim.t01.forced_rolls.assign([0,.99,.99])
		if status=="寒霜":sim.cultivation.trigger_frost(p,e,0,0)
		else:sim.t01.attack_item(p,e,sim._definitions.weapon,{"value":10,"damage_type":"斩击"},0,sim.t01.item_source("weapon"))
		var m:=metrics(sim,"second")
		if status=="寒霜":check(m.debuff_apply==2 and e.frozen_until>0,"frost control attributed to actual pool source")
		else:check(m.get("damage_status",0)>0 and m.get("trigger",0)==1,"derived source survives consumption "+status)
		check(sim.record_trace.current().is_empty(),"balanced derived scopes "+status)
	var sim:=mixed()
	var p:PartyMemberState=sim.state.teams[0][0]
	check(p.inventory.add_item("passive","base.organ.yanbilingyuan_hujing",Vector2i(5,5)),"passive fixture")
	check(p.inventory.add_item("periodic","base.organ.biyetengling_xulubao",Vector2i(6,5)),"periodic fixture")
	sim.attach(p,0,"passive",false);sim.attach(p,0,"periodic",false)
	p.hp=100;p.spirit-=20
	sim.item_rules.wake(0)
	sim.advance(10)
	var m:=metrics(sim,"passive")
	check(m.buff_apply==1 and m.trigger==1 and m.get("rotation",0)==0,"passive actual instance and no rotation")
	m=metrics(sim,"periodic")
	check(m.spirit_restored==7 and m.trigger==1 and m.get("rotation",0)==0,"periodic restore counts trigger only")

func test_support_and_replacement()->void:
	var sim:=mixed()
	var p:PartyMemberState=sim.state.teams[0][0]
	var e:PartyMemberState=sim.state.teams[1][0]
	p.temporary_effects.test={"until":100,"physical_bonus":.2,"replay_sources":Attribution.sources(sim.t01.item_source("second"))}
	sim.t01.damage(p,e,10,"斩击","base.element.none",0,sim.t01.item_source("weapon"),true,{})
	check(is_equal_approx(metrics(sim,"second").damage_assist,2),"additive support measured at formula")
	e.hp=1
	sim.t01.damage(p,e,10,"斩击","base.element.none",1,sim.t01.item_source("weapon"),true,{})
	check(is_equal_approx(metrics(sim,"second").damage_assist,2),"overkill does not inflate support")
	sim=mixed();p=sim.state.teams[0][0];e=sim.state.teams[1][0]
	p.temporary_effects.test={"until":100,"element":"base.element.fire","reduction":.2,"replay_sources":Attribution.sources(sim.t01.item_source("second"))}
	sim.t01.damage(e,p,10,"法术型","base.element.fire",0,sim.t01.item_source("enemy_weapon"),true,{})
	check(is_equal_approx(metrics(sim,"second").damage_mitigated,2),"single resistance measured as actual mitigation")
	sim=battle("base.spell.metal_03");p=sim.state.teams[0][0];e=sim.state.teams[1][0]
	sim.cultivation.cast("spell",0)
	sim.t01.damage(e,p,10,"钝击","base.element.none",0,{"adjusted":true},false,{"special":true})
	sim.cultivation.cast("spell",1)
	var m:=metrics(sim,"spell")
	check(m.shield_generated==60 and m.shield_discarded==26 and m.shield_absorbed==4,"real sword screen replacements distinguish generation / discarded / absorbed")
