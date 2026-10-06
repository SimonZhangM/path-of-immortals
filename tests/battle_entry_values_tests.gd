extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.enemy_id = "base.enemy.chisong_liaozhu"
	game.loadout_save_path = ""
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	current_scene = scene
	await settle()
	var ui = scene.get_node("MainUI")
	check(game.startup_error.is_empty(),"battle initializes")
	check(game.simulation.state.phase == GameState.Phase.PREPARATION,"entry waits for explicit start")
	check(ui._battle_button.caption == "战斗开始","initial caption")
	for panel in [ui.ally_panel,ui.enemy_panel]:
		for node in panel.find_children("*","InventoryView",true,false):
			check(node._board_art != null and node._board_art.size.x > 0,"board ready while scene processing disabled")
			check(node._artworks.size() == node.inventory.get_instances().size(),"items ready before fade-in")
	var member = game.party[0]
	var card = ui.ally_panel.cards[0]
	for key in ["hp","stamina","spirit"]:
		var label = card.stat_values[key]
		var before: float = label.separator_center()
		member.set(key,12.3)
		card.refresh(member)
		check(label.text.begins_with("12.3 /"),"fraction shown "+key)
		check(label.separator_center() == before,"slash stable "+key)
		check(is_equal_approx(label.position.x + label.separator_center(),(15+card.stat_bars[key].size.x)*.5),"slash centered on unobscured bar "+key)
	ui._time.text = "00.82"
	ui._layout_time_suffix()
	var decimal_x: float = (ui._time.get_global_transform()*Vector2(ui._time.separator_center(),0)).x
	var frame_x: float = (ui._timer_frame.get_global_transform()*(ui._timer_frame.size*.5)).x
	check(absf(decimal_x-frame_x)<1,"decimal centered on frame: %s / %s" % [decimal_x,frame_x])
	var tip := ItemTooltip.new()
	tip.configure(game.registry.get_item("base.material.cslz_heart"))
	root.add_child(tip)
	tip.position = Vector2(940,690)
	var tags = tip.find_child("CategoryTags",true,false)
	check(tags.get_children().all(func(label): return not label.text.begins_with("占格")),"material tooltip omits footprint")
	var organ_tip := ItemTooltip.new()
	organ_tip.configure(game.registry.get_item("base.organ.cslz_heart"))
	root.add_child(organ_tip)
	check(organ_tip.find_child("CategoryTags",true,false).get_children().any(func(label): return label.text.begins_with("占格")),"board organ retains footprint")
	organ_tip.queue_free()
	var material_card := MapInventoryItemCard.new()
	var material_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/enemy_materials.json"))[-1]
	material_record.quality = "下品"
	material_card.configure(material_record,"兽材")
	root.add_child(material_card)
	material_card.position = Vector2(2110,1040)
	material_card.size = Vector2(210,280)
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-entry-values.png")
	ui._battle_button.pressed.emit()
	ui._refresh()
	check(game.simulation.state.phase == GameState.Phase.BATTLE and not game.simulation.clock.paused,"explicit start runs battle")
	check(ui._battle_button.caption == "战斗暂停","running caption unchanged")
	ui._battle_button.pressed.emit()
	ui._refresh()
	check(game.simulation.clock.paused and ui._battle_button.caption == "战斗继续","later pause caption unchanged")
	check(game.simulation.state.time_usec == 0,"no automatic simulation during entry")
	scene.queue_free()
	tip.queue_free()
	material_card.queue_free()
	await settle()
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.arrival_point_id = "base.map.qingshihewan.point.n12"
	root.add_child(map)
	current_scene = map
	await settle()
	check(map._try_start_event(map.arrival_point_id,"click",true),"actual map encounter opens")
	map._confirm_encounter()
	var presentation := root.get_node("MapPresentation")
	while current_scene == map or presentation.transitioning: await process_frame
	var entered := current_scene
	var entered_game: GameManager = entered.get_node("GameManager")
	check(entered_game.simulation.state.phase == GameState.Phase.PREPARATION and entered_game.simulation.state.time_usec == 0,"map transition completes without autostart")
	check(entered.get_node("MainUI")._battle_button.caption == "战斗开始","actual encounter starts with start caption")
	entered.queue_free()
	await settle()
	print("ENTRY VALUES: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
