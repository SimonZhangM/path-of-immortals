extends SceneTree

var checks := 0
var failures := 0
var exit_calls := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 8: await process_frame
func click(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
func screenshot(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + path + ".png")
func pretend_exit() -> String:
	exit_calls += 1
	return "测试返回失败，可重试"

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560, 1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	var flow = load("res://scripts/map/map_battle_return.gd").new()
	flow.name = "MapBattleReturn"
	flow.manager = game
	flow.save_path = "res://artifacts/victory-flow-test.json"
	flow.map_scene_path = "res://scenes/maps/qingshihewan.tscn"
	var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cliff_encounter.json"))
	var events := MapEventRegistry.new()
	assert(events.configure([event], [event.point_id]).is_empty())
	flow.events = MapEventState.new(events, {})
	flow.event_id = event.id
	flow.point_id = event.point_id
	flow._loot_rolls = [0,0,0,0,0]
	scene.add_child(flow)
	var ui = scene.get_node("MainUI")
	ui.battle_exit_handler = pretend_exit
	root.add_child(scene)
	current_scene = scene
	game.set_process(false)
	game.loadout_save_path = flow.save_path
	assert(game.startup_error.is_empty())
	await settle()
	var banner = ui.victory_banner
	for rank: String in banner.paths:
		banner.present(rank)
		var texture := banner.artwork.texture as AtlasTexture
		check(texture.atlas.resource_path == banner.paths[rank], "correct banner for " + rank)
		check(texture.atlas.get_image().has_mipmaps(), "banner mipmaps " + rank)
	banner.reset()
	game.start_battle()
	game.simulation._finish("victory", 0)
	game._process(0)
	ui._refresh()
	await settle()
	check(ui.victory_view == ui.VictoryView.BANNER and banner.visible, "victory shows banner first")
	check(banner.artwork.texture.atlas.resource_path.ends_with("huashen.webp"), "uses player realm, not mortal enemy")
	check(banner.get_node("VictoryShade").color.a == 0.5, "half-opacity black mask")
	check(banner.timer.wait_time == 1.5, "1.5 seconds presentation hold")
	check(not ui.victory_rewards.visible and not ui._retreat_dialog.visible, "no overlapping reward/legacy modal")
	check(game.loot_item_ids.size() == 5, "structured awarded drops published")
	var receipt := game._durable_snapshot.duplicate(true)
	await screenshot("victory-banner")
	# Click the location where the next modal's confirm button will be: it must
	# dismiss only the banner, never click through and finish the battle.
	click(Vector2(1426, 955))
	await settle()
	check(ui.victory_view == ui.VictoryView.REWARDS and exit_calls == 0, "click skips banner without confirming next modal")
	var reward = ui.victory_rewards
	check(reward.grid.columns == 3 and reward.grid.get_child_count() == 5, "five distinct drops, three columns")
	check(reward.scroll.get_v_scroll_bar().max_value > reward.scroll.size.y, "second row scrollable")
	check(reward.review_button.position.x < reward.accept_button.position.x, "review left and confirm right")
	check(reward.grid.get_child(0).size.x < 152, "cards smaller than story reward card")
	await screenshot("victory-rewards")
	click(reward.scroll.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	await settle()
	check(reward.scroll.scroll_vertical > 0, "mouse wheel scrolls reward cards")
	reward.scroll.scroll_vertical = 10000
	await settle()
	var last: Control = reward.grid.get_child(4)
	check(last.get_global_rect().end.y < reward.scroll.get_global_rect().end.y, "last row fully visible when scrolled")
	await screenshot("victory-rewards-scrolled")
	click(reward.review_button.get_global_rect().get_center())
	await settle()
	check(ui.victory_view == ui.VictoryView.REVIEW and not banner.visible and not reward.visible, "review removes modals and mask")
	check(ui._battle_button.caption == "离开战场" and ui._battle_button.action_icon == null and ui._battle_button.icon_reference == null, "review exit has no icon")
	check(not ui._battle_button.disabled and ui._bag_button.disabled and ui._retreat_button.disabled and not ui._log_button.disabled, "review permits exit and battle log only")
	check(not game.can_adjust() and game.simulation.state.is_finished(), "review cannot modify or resume battle")
	await screenshot("victory-review")
	click(ui._battle_button.get_global_rect().get_center())
	await settle()
	check(ui.victory_view == ui.VictoryView.REWARDS and reward.grid.get_child_count() == 5, "leave battlefield reopens same rewards")
	check(game._durable_snapshot == receipt, "review cycling cannot duplicate rewards")
	check(flow._award_victory().is_empty() and game._durable_snapshot == receipt and game.loot_item_ids.size() == 5, "settlement retry uses saved receipt")
	# Error remains in the modal; both actions become usable again.
	click(reward.accept_button.get_global_rect().get_center())
	await create_timer(0.15).timeout
	check(exit_calls == 1 and reward.visible and not reward.accept_button.disabled and reward.error_label.text.contains("失败"), "confirm failure shows retryable error")
	# Empty and one-item layouts have no invented reward.
	var drops := game.loot_item_ids.duplicate()
	game.loot_item_ids.clear()
	ui._show_victory_rewards()
	await settle()
	check(reward.empty_label.visible and reward.grid.get_child_count() == 0, "zero drops show explicit empty state")
	game.loot_item_ids.append(drops[0])
	ui._show_victory_rewards()
	await settle()
	check(not reward.empty_label.visible and reward.grid.get_child_count() == 1, "one drop uses one card")
	game.loot_item_ids.assign(drops)
	# Two-second fade followed by the existing three-second hold.
	reward.hide()
	ui.victory_view = ui.VictoryView.BANNER
	banner.present("base.cultivation.spirit_transformation")
	await create_timer(4.8).timeout
	check(banner.visible, "banner remains before fade plus hold ends")
	await create_timer(0.35).timeout
	check(not banner.visible and reward.visible and ui.victory_view == ui.VictoryView.REWARDS, "automatically opens rewards after three seconds")
	reward.hide()
	ui.victory_view = ui.VictoryView.BANNER
	banner.present("base.cultivation.spirit_transformation")
	click(Vector2(50, 200), MOUSE_BUTTON_RIGHT)
	await settle()
	check(not banner.visible and reward.visible and banner.timer.is_stopped(), "right click also dismisses once and cancels timer")
	# Failure/withdrawal must never enter victory presentation.
	game.restart()
	game.simulation._finish("defeat", 0)
	ui._refresh()
	check(ui.victory_view == ui.VictoryView.NONE and not banner.visible and ui._retreat_dialog.visible, "defeat stays on failure flow")
	# Restore finished victory display and use the actual return transition.
	game.simulation.state.result = "victory"
	game.loot_item_ids.assign(drops)
	ui.victory_view = ui.VictoryView.REWARDS
	ui._show_victory_rewards()
	ui.battle_exit_handler = flow.return_to_map
	click(reward.accept_button.get_global_rect().get_center())
	await create_timer(2.5).timeout
	check(not is_instance_valid(scene), "confirm leaves battle through real map transition")
	var maps := root.get_children().filter(func(node): return node.scene_file_path == "res://scenes/maps/qingshihewan.tscn")
	check(maps.size() == 1 and maps[0].startup_error.is_empty(), "original map opens successfully")
	if maps.size() == 1:
		check(maps[0].loadout.battle_rewards.size() == 1, "returned map retains one victory receipt")
		check(maps[0].loadout.storage_records().filter(func(record): return record.category == "beast").size() == 5, "returned map retains all five reward materials")
	for map in maps: map.queue_free()
	await settle()
	root.get_node("MapPresentation").music.stop()
	# Give the audio mixer a turn to release the map track before process exit.
	await create_timer(0.2).timeout
	print("VICTORY FLOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
