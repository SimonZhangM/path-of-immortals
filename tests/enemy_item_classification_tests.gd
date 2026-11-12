extends SceneTree

var checks := 0
var failures: Array[String] = []
const DIR := "res://artifacts/enemy-item-tags-20261110/"
const ARMOR := ["无甲","轻甲","重甲","灵甲"]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func combat_tag(tag: String) -> bool:
	return tag in ARMOR or EffectSystem.ARMOR_MULTIPLIERS.has(tag)
func settle() -> void:
	for i in 5: await process_frame

func run() -> void:
	create_timer(35).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(DIR)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(),"base content loads")
	var created := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(created.error.is_empty(),"materials registered")
	check(registry.get_enemy("base.enemy.wild_dog").innate_armor_type=="无甲" and registry.get_enemy("base.test.dummy").innate_armor_type=="无甲","approved test armor definitions explicit")
	check(registry.get_item("base.weapon.dog_claw").effects[0].damage_type=="斩击","approved claw damage classification explicit")
	for definition: Dictionary in registry._enemies.values():
		if not definition.has("presentation"): continue
		var enemy := PartyMemberState.new(definition,registry)
		enemy.equip_definition_loadout()
		for entry: Dictionary in enemy.inventory.get_instances():
			var item := registry.get_item(entry.item_id)
			var tags := ItemTooltip.classification_tags(item,false,enemy.armor_type)
			if item.armor_capacity>0: check(enemy.armor_type in tags,"organ inherits owning monster armor: "+item.id)
			else: check(not tags.any(func(tag): return tag in ARMOR),"nonarmor organ has no borrowed armor type: "+item.id)
			for effect: Dictionary in item.effects:
				if effect.get("effect")=="damage": check(effect.damage_type in tags and tags.count(effect.damage_type)==1,"actual item attack type shown once: "+item.id)
		for drop: Dictionary in definition.get("loot",[]):
			var item := registry.get_item(drop.item_id)
			check(item!=null and not ItemTooltip.classification_tags(item,false,enemy.armor_type).any(combat_tag),"drop material has no combat classification: "+drop.item_id)
	var contaminated := registry.get_item("base.material.xiwenlingyuan_shuiwenyuanpi")
	var prior_tags := contaminated.tags.duplicate()
	contaminated.tags.append_array(["灵甲","法术型"])
	check(not ItemTooltip.classification_tags(contaminated,false,"灵甲").any(combat_tag),"material guard rejects inherited combat tags")
	contaminated.tags=prior_tags
	var manager := GameManager.new()
	manager.registry=registry
	manager.party.append(PartyMemberState.new(registry.get_character(GameManager.PARTY_IDS[0]),registry))
	var enemy := PartyMemberState.new(registry.get_enemy("base.enemy.xiwenlingyuan"),registry)
	enemy.equip_definition_loadout()
	manager.enemies.append(enemy)
	manager.simulation=BattleSimulation.new(manager.party,manager.enemies,registry)
	var board := InventoryView.new()
	board.manager=manager
	board.enemy_side=true
	for pair in [["base.organ.xiwenlingyuan_shuiwenyuanpi","base.material.xiwenlingyuan_shuiwenyuanpi","灵甲"],["base.organ.xiwenlingyuan_xiwenyuanwei","base.material.xiwenlingyuan_xiwenyuanwei","钝击"]]:
		board._tooltip_entry=enemy.inventory.get_instances().filter(func(entry:Dictionary):return entry.item_id==pair[0])[0]
		var organ_tip: ItemTooltip=board.build_item_tooltip("")
		var material_tip := ItemTooltip.new()
		material_tip.configure(registry.get_item(pair[1]))
		root.add_child(organ_tip)
		root.add_child(material_tip)
		organ_tip.position=Vector2(450,240)
		material_tip.position=Vector2(1330,240)
		await settle()
		var actual: Array=organ_tip.find_child("CategoryTags",true,false).get_children().map(func(label:Label):return label.text)
		check(pair[2] in actual,"real enemy board tooltip receives owner and attack classification")
		var material_tags: Array=material_tip.find_child("CategoryTags",true,false).get_children().map(func(label:Label):return label.text)
		check(not material_tags.any(combat_tag),"real material tooltip omits source combat classification")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(DIR+("armor" if pair[2]=="灵甲" else "attack")+"-and-material.png")
		organ_tip.queue_free()
		material_tip.queue_free()
		await settle()
	board.free()
	manager.free()
	FileAccess.open(DIR+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("ENEMY ITEM TAGS: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
