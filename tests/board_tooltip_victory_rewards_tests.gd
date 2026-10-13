extends SceneTree

var checks := 0
var failures := 0
var dismissals := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 10: await process_frame
func screenshot(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + path + ".png")
func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	root.add_child(scene)
	game.set_process(false)
	check(game.startup_error.is_empty(), "actual battle startup")
	var registry := game.registry
	var model := game._durable_loadout
	var tips: Array[ItemTooltip] = []
	for record: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/qinglan_boards.json")):
		var item := registry.get_item(record.id)
		var text := ItemTooltip.effect_text(item)
		check(text.contains(record.origin_description), "board origin: " + record.name)
		check(text.contains(registry.get_cultivation(record.required_cultivation).name + "及以上"), "required rank: " + record.name)
		var layout := registry.get_board(record.board_layout)
		for status: String in layout.status_capacity_bonuses:
			if layout.status_capacity_bonus(status) > 0:
				check(text.contains("%s+%d" % [status,layout.status_capacity_bonus(status)]), "actual bonus: " + status)
		if record.id in ["base.map_item.bag_board", "base.map_item.qinglan_board_6"]:
			var tip := ItemTooltip.new()
			tip.configure(item)
			tip.z_index = 100
			root.add_child(tip)
			tip.position = Vector2(60 + tips.size()*800,50)
			tips.append(tip)
	var rich := ItemTooltip._colored(ItemTooltip.effect_text(registry.get_item("base.map_item.qinglan_board_6")), ItemTooltip.highlighted_keywords(),31)
	for resource: String in ItemTooltip.RESOURCE_STYLES:
		check(rich.contains(ItemTooltip.RESOURCE_STYLES[resource].icon),"inline resource icon: " + resource)
	for status: String in ["生机","轻灵","坚韧","失衡","驱散"]:
		check(rich.contains("[color=#%s]%s" % [ItemTooltip._keyword_color(status),status]), "existing status color: " + status)
	var hidden := ItemTooltip.new()
	hidden.configure(registry.get_item("base.map_item.qinglan_board_6"),{},-1,0,false)
	check(hidden.description == MapItemQuality.UNKNOWN_DESCRIPTION, "unidentified board never leaks bonuses")
	hidden.free()
	var card := MapInventoryItemCard.new()
	card.configure(model.records["base.map_item.qinglan_board_6"],"阵盘")
	root.add_child(card)
	card.position = Vector2(1750,80)
	card.size = Vector2(190,254)
	check(card.find_child("ItemName",true,false).get_theme_color("font_color") == Color("f9f8c8"),"card name matches tooltip title color")
	await settle()
	check(tips[1].size.y > tips[0].size.y,"tooltip natural height grows with content")
	for tip in tips:
		check(tip.position.y + tip.size.y < 1440,"tooltip stays within native screen")
		check(tip.find_child("BoardDescriptionSlot",true,false)==null,"no fixed blank spacer")
	print("Tooltip sizes: ",tips[0].size, " / ",tips[1].size)
	await screenshot("board-descriptions-native")
	for tip in tips: tip.queue_free()
	card.queue_free()
	await settle()
	# Exercise actual banner tween, including its cancellation and unchanged final mask.
	var banner = scene.get_node("MainUI").victory_banner
	banner.dismissed.connect(func(): dismissals += 1)
	banner.present("base.cultivation.spirit_transformation")
	banner._fade.pause()
	check(banner.modulate.a == 0 and banner.timer.is_stopped(),"banner and shade begin transparent")
	banner._fade.custom_step(0.25)
	check(is_equal_approx(banner.modulate.a,0.5),"halfway fade applies to artwork and shade together")
	check(banner.get_node("VictoryShade").color.a == 0.5,"final mask remains fifty percent")
	await screenshot("victory-fade-half")
	banner._fade.custom_step(0.26)
	check(is_equal_approx(banner.modulate.a,1.0) and not banner.timer.is_stopped(),"half-second fade then 1.5-second hold")
	await screenshot("victory-fade-complete")
	banner.dismiss()
	banner.dismiss()
	check(dismissals == 1 and banner._fade == null and banner.timer.is_stopped(),"skip cancels tween/timer exactly once")
	banner.present("base.cultivation.mortal")
	banner.reset()
	await create_timer(0.1).timeout
	check(not banner.visible and banner.timer.is_stopped(),"reset cannot resurrect hold timer")
	# Settlement retry must not award progression until inventory commit succeeds.
	var flow = load("res://scripts/map/map_battle_return.gd").new()
	flow.manager = game
	flow.player_status = MapPlayerStatus.new()
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/status_header.json"))
	check(flow.player_status.configure(registry,config).is_empty(),"map status configured")
	flow.player_status.cultivation_progress = 27
	flow.player_status.experience = 45
	var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cliff_encounter.json"))
	var event_registry := MapEventRegistry.new()
	assert(event_registry.configure([event],[event.point_id]).is_empty())
	MapEventState.session_completed.clear()
	flow.events = MapEventState.new(event_registry,{})
	flow.event_id = event.id
	flow._loot_rolls = [0,0,0,0,0]
	game.start_battle()
	game.simulation._finish("victory",0)
	flow.save_path = "res://artifacts/nonexistent-reward-directory/save.json"
	flow._record_result()
	check(not flow.reward_error.is_empty() and flow.player_status.cultivation_progress == 27 and flow.player_status.experience == 45,"failed commit grants no progression")
	flow.save_path = ""
	flow._record_result()
	check(flow.reward_error.is_empty() and flow.player_status.cultivation_progress == 32 and flow.player_status.experience == 47,"victory grants exactly five cultivation/two experience")
	flow._record_result()
	flow._recorded = false # Even a repeated event-resolution attempt must be idempotent.
	flow._record_result()
	check(flow.player_status.cultivation_progress == 32 and flow.player_status.experience == 47,"repeated settlement cannot duplicate progression")
	# Respawn creates a new battle, with the old first-victory receipt retained.
	check(flow.events.respawn_encounter(event.id), "encounter can respawn")
	check(flow.events.try_start(event.point_id,event.point_id,true,"click"), "respawned enemy can be challenged again")
	game.restart()
	game.start_battle()
	game.simulation._finish("victory",0)
	var next_flow = load("res://scripts/map/map_battle_return.gd").new()
	next_flow.manager = game
	next_flow.player_status = flow.player_status
	next_flow.events = flow.events
	next_flow.event_id = flow.event_id
	next_flow.save_path = ""
	next_flow._loot_rolls = [0.99,0.99,0.99,0.99,0.99]
	next_flow._record_result()
	check(next_flow.reward_error.is_empty() and game.loot_item_ids.is_empty(), "repeat kill is not a first victory; zero material drops")
	check(flow.player_status.cultivation_progress == 37 and flow.player_status.experience == 49, "every kill awards progression even without material drops")
	next_flow._record_result()
	check(flow.player_status.cultivation_progress == 37 and flow.player_status.experience == 49, "second battle also awards only once")
	next_flow.free()
	for bad: Variant in [[],{"cultivation":-1},{"experience":1.5},{"unknown":5}]:
		check(not ContentRegistry.progression_rewards_error(bad).is_empty(),"invalid reward rejected")
	check(ContentRegistry.progression_rewards_error({"cultivation":5,"experience":2}).is_empty(),"valid progression data")
	flow.free()
	scene.queue_free()
	await settle()
	print("BOARD TOOLTIP / VICTORY REWARDS: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
