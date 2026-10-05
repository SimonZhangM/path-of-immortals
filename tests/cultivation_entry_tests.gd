extends SceneTree

const SAVE := "res://artifacts/cultivation-entry-save.json"
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: "+label)
func settle() -> void:
	for i in 6: await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/cultivation-"+label+".png")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(1920,1080)
	var actual_before := FileAccess.get_file_as_bytes(MapLoadoutStore.DEFAULT_PATH)
	for prefix in [SAVE,SAVE+".cultivation.json"]:
		for suffix in ["",".tmp",".bak"]:
			if FileAccess.file_exists(prefix+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix+suffix))
	var manager := GameManager.new()
	manager.use_saved_loadout=true; manager.loadout_save_path=SAVE
	root.add_child(manager); manager.set_process(false)
	check(manager.startup_error.is_empty(),"real game manager loads old save without learning file")
	check(manager.party[0].knowledge.learned.is_empty(),"old save grants no learned spells")
	var inventory_before := FileAccess.get_file_as_bytes(SAVE)
	check(manager.record_book_acquired("base.cultivation_book.metal_04"),"acquire book through durable command")
	check(manager.equip_known_book("base.cultivation_book.metal_04",Vector2i(2,1),true),"real zero-stage book equips vertically")
	check(manager.record_cultivation_achievement("base.cultivation_book.metal_04",1),"record achieved stage through durable command")
	check(manager.record_cultivation_achievement("base.cultivation_book.metal_04",2),"record second stage")
	check(manager.choose_cultivation_branch("base.cultivation_book.metal_04",2,"剑锋"),"branch persists through manager")
	check(manager.equip_learned_spell("base.spell.metal_01",Vector2i.ZERO),"learned spell independent placement")
	check(not manager.equip_learned_spell("base.spell.metal_01",Vector2i(1,0)),"real entry rejects duplicate spell")
	var expected := manager.party[0].knowledge.snapshot()
	var old_path := manager.loadout_save_path
	manager.loadout_save_path = "res://artifacts/no-such-parent/cultivation-entry"
	check(not manager.record_cultivation_achievement("base.cultivation_book.metal_04",3),"failed disk write rejects achievement")
	check(manager.party[0].knowledge.snapshot()==expected,"failed write rolls back in memory")
	manager.loadout_save_path=old_path
	check(FileAccess.get_file_as_bytes(SAVE)==inventory_before,"learning never rewrites inventory file")
	manager.queue_free(); await settle()
	manager=GameManager.new(); manager.use_saved_loadout=true; manager.loadout_save_path=SAVE
	root.add_child(manager); manager.set_process(false)
	check(manager.startup_error.is_empty() and manager.party[0].knowledge.snapshot()==expected,"learning survives real entry reload")
	check(manager._durable_snapshot.owned_units.size()==115,"all115 inventory preserved after reload")
	var before := manager.party[0].knowledge.snapshot()
	var invalid := FileAccess.open(SAVE+".cultivation.json",FileAccess.WRITE); invalid.store_string("{bad"); invalid.close()
	check(not CultivationStore.load_into(manager.party[0].knowledge,manager.registry.library,4,SAVE+".cultivation.json").is_empty() and manager.party[0].knowledge.snapshot()==before,"corrupt learning file reports error and retains state")
	manager.queue_free(); await settle()
	var scene: Node = load("res://scenes/main/cultivation_preview.tscn").instantiate()
	manager=scene.get_node("GameManager"); manager.preview_spell_id="base.spell.metal_03"; manager.preview_branch="返剑"
	root.add_child(scene); manager.set_process(false); await settle()
	var ui: Control = scene.get_node("MainUI")
	check(manager.startup_error.is_empty() and manager.party[0].definition.max_spirit==50,"preview real scene with approved resource baseline")
	check(manager.party[0].inventory.get_instances().size()==3,"preview spell weapon and original book visible")
	manager.set_all_automatic(false)
	check(manager.set_item_automatic("preview.spell",false),"per-item manual command")
	check(not manager.set_item_automatic(GameManager.CLAW_INSTANCE,false),"UI command cannot change enemy mode")
	ui._battle_button.pressed.emit()
	manager._process(8)
	check(manager.simulation.state.item_runtime["preview.spell"].activation_count==0,"manual waits at zero in real scene")
	check(manager.activate_manual("preview.spell"),"real manual activation command")
	await settle()
	check(ui.ally_panel.combat_status.text.contains("剑幕 30"),"authoritative sword screen visible")
	manager.simulation.timeline.apply_control(manager.party[0],"silence","spells",3_000_000,"fixture",8_000_000)
	manager._process(0); await settle()
	check(ui.ally_panel.combat_status.text.contains("沉默"),"control visible with Chinese name")
	var log_button: Button = ui.find_child("BattleLogButton",true,false)
	log_button.pressed.emit(); await settle()
	check(ui._log_panel.visible and ui._log_label.text.contains("回锋剑幕") and ui._log_label.text.contains("沉默"),"real log lists spell fee and control")
	await capture("screen-and-log")
	ui._log_panel.hide()
	var spell_bag: InventoryView = ui.ally_panel.bags[0]
	spell_bag._get_tooltip(spell_bag.board_layout.footprint_rect(Vector2i.ZERO,Vector2i.ONE,spell_bag.size).get_center())
	var tooltip: ItemTooltip = spell_bag._make_custom_tooltip("")
	root.add_child(tooltip); tooltip.position=Vector2(900,180)
	check(tooltip.description.contains("返剑反击15") and tooltip.description.contains("生成30点剑幕"),"tooltip shows resolved branch effects with empty image")
	await settle(); await capture("spell-tooltip")
	tooltip.queue_free(); await settle()
	manager.pause_battle(); manager.set_adjustment(true)
	check(manager.unequip(0,"preview.book"),"known book unequip")
	check(manager.equip_known_book("base.cultivation_book.metal_04",Vector2i(2,1),true),"vertical book placed via manager")
	var bag: InventoryView = ui.ally_panel.bags[0]
	var point := bag.board_layout.footprint_rect(Vector2i(2,1),Vector2i(1,2),bag.size).get_center()
	var drag := bag.drag_data_at(point)
	check(not drag.is_empty() and drag.instance_id=="run.base.cultivation_book.metal_04","vertical book hit uses both cells")
	var destination := bag.board_layout.footprint_rect(Vector2i(1,1),Vector2i(1,2),bag.size).get_center()
	check(bag._can_drop_data(destination,drag) and bag._hover_dimensions==Vector2i(1,2),"vertical book drag preserves shape")
	bag._drop_data(destination,drag)
	check(manager.party[0].inventory.get_instance(drag.instance_id).cell==Vector2i(1,1),"vertical book drop uses actual footprint")
	await capture("vertical-book")
	scene.queue_free(); await settle()
	# Every definition is also built through the actual GameManager entry, using
	# the same 3x3 board and 50 spirit instead of the simulation test's large pool.
	var library := CultivationLibrary.new()
	var reg := ContentRegistry.new(); reg.load_base_content(); library=reg.library
	for id: String in library.spells:
		manager=GameManager.new(); manager.cultivation_preview=true; manager.preview_spell_id=id
		root.add_child(manager); manager.set_process(false)
		check(manager.startup_error.is_empty(),"preview startup "+id)
		manager.start_battle()
		manager._process(13)
		check(manager.simulation.configuration_error.is_empty(),"preview settlement "+id)
		check(manager.simulation.state.item_runtime["preview.spell"].activation_count>0,"preview actually activates "+id)
		manager.queue_free(); await process_frame
	await settle()
	check(FileAccess.get_file_as_bytes(MapLoadoutStore.DEFAULT_PATH)==actual_before,"real115 inventory bytes unchanged")
	print("CULTIVATION ENTRY CHECKS %d; FAILURES %d" % [checks,failures])
	quit(1 if failures else 0)
