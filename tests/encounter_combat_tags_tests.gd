extends SceneTree

var checks := 0
var failures: Array[String] = []
const DIR := "res://artifacts/encounter-combat-tags-20261110/"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 4: await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR+name+".png")

func run() -> void:
	create_timer(40).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(DIR)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(2560,1440)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "content loads")
	var catalog := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(catalog.error.is_empty(), "map drop materials registered")
	var dialog := MapEncounterDialog.new()
	root.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var event: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/diecuifeng_encounter_n07.json"))
	var audit: Array = []
	for id: String in registry._enemies:
		var definition := registry.get_enemy(id)
		if not definition.has("presentation"): continue
		var enemy := PartyMemberState.new(definition,registry)
		enemy.equip_definition_loadout()
		var tags := EnemyPresentation.combat_tags(enemy)
		audit.append({"id":id,"name":definition.name,"armor":tags.armor,"attacks":tags.attacks,"missing":tags.missing})
		check(tags.missing.is_empty() and not tags.attacks.is_empty(), "explicit combat classes: "+id)
		check(tags.attacks.size()<=4, "supported unique attack count: "+id)
		var shown_event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/wumingjiuci_encounter_n10.json")) if id=="base.enemy.heiwei_cishu" else event
		dialog.present(shown_event,enemy)
		await settle()
		check(dialog.armor_label.text==definition.innate_armor_type, "armor tag from actual definition: "+id)
		var displayed: Array = dialog.attack_labels.filter(func(label: Label):return label.visible).map(func(label: Label):return label.text)
		check(displayed==tags.attacks, "attack tags from equipped item effects: "+id)
		var active_tags: Array = dialog._tag_labels.filter(func(label: Label): return label.visible)
		check(active_tags.all(func(a: Label): return active_tags.all(func(b: Label): return a==b or not a.get_rect().intersects(b.get_rect()))), "tag rows do not overlap: "+id)
		for label: Label in dialog._tag_labels:
			if not label.visible: continue
			check(label.position.y+label.size.y<=dialog.enemy_description.position.y, "tag clears prose: "+id+label.text)
		check(dialog.enemy_description.get_minimum_size().y<=dialog.enemy_description.size.y, "description fits: "+id)
		check(dialog.enemy_description.position.y+dialog.enemy_description.size.y<=dialog.loot_heading.position.y, "description clears loot: "+id)
		check(dialog.enemy_description.size.y<=dialog.enemy_description.get_meta("source_rect").size.y*(dialog.canvas.size.y/MapEncounterDialog.FRAME.size.y)+1, "description stays inside authored frame: "+id)
		if id in ["base.enemy.xiwenlingyuan","base.enemy.heiwei_cishu"]:
			await capture(id.get_slice(".",2)+"-2k")
		if id=="base.enemy.xiwenlingyuan":
			root.size=Vector2i(1920,1080)
			await settle()
			check(dialog.enemy_description.get_minimum_size().y<=dialog.enemy_description.size.y, "creek description fits 1080p")
			await capture("xiwenlingyuan-1080p")
			root.size=Vector2i(2560,1440)
	check(audit.size()==15, "all fifteen formal enemy definitions audited")
	var dog := PartyMemberState.new(registry.get_enemy("base.enemy.wild_dog"),registry)
	dog.inventory.add_item("test.claw","base.weapon.dog_claw",Vector2i.ZERO)
	var missing := EnemyPresentation.combat_tags(dog)
	check(missing.armor=="无甲" and missing.attacks==["斩击"] and missing.missing.is_empty(), "approved legacy dog classifications are explicit")
	dog.definition=dog.definition.duplicate(true)
	dog.definition.erase("innate_armor_type")
	check(EnemyPresentation.combat_tags(dog).armor.is_empty(), "missing armor is not replaced by runtime default")
	dialog.present({"pending_enemy":true,"pending_enemy_name":"待配置","title":"测试地点","description":"","presentation":{"illustration":""}},null)
	check(not dialog.armor_label.visible and dialog.attack_labels.all(func(label: Label):return not label.visible), "pending enemy clears preceding classification tags")
	FileAccess.open(DIR+"audit.json",FileAccess.WRITE).store_string(JSON.stringify({"formal":audit,"legacy_dog_missing":missing.missing,"checks":checks,"failures":failures},"\t"))
	dialog.queue_free()
	await settle()
	print("ENCOUNTER COMBAT TAGS: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
