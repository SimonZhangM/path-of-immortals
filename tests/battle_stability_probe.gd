extends SceneTree

var sorts := 0
var board_moves := 0
var name_changes := 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560,1440)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.loadout_save_path = ""
	game.use_saved_loadout = true
	if "--saved" in OS.get_cmdline_user_args():
		# Read only a disposable copy prepared by the caller, never the live save.
		game.loadout_save_path = "res://artifacts/battle-flicker-loadout.json"
	game.enemy_id = "base.enemy.chisong_liaozhu"
	root.add_child(scene)
	game.set_process(false)
	assert(game.startup_error.is_empty())
	var ui = scene.get_node("MainUI")
	for i in 15: await process_frame
	ui.find_child("BattleArena",true,false).sort_children.connect(func(): sorts += 1)
	ui.ally_panel.bags[0].item_rect_changed.connect(func(): board_moves += 1)
	ui.ally_panel.cards[0].name_label.minimum_size_changed.connect(func(): name_changes += 1)
	var positions := {}
	var frames := {}
	for i in 90:
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		var key := str([ui.ally_panel.position, ui.ally_panel.bags[0].get_global_rect(), ui.ally_panel.cards[0].get_global_rect(), ui._backdrop.material.get_shader_parameter("ally_board")])
		positions[key] = int(positions.get(key,0)) + 1
		if i in [15,30,45,60,75,89] and DisplayServer.get_name() != "headless":
			var screenshot := root.get_texture().get_image()
			var sha := screenshot.get_data().hex_encode().sha256_text()
			frames[sha] = int(frames.get(sha,0)) + 1
			if frames.size() < 4: screenshot.save_png("res://artifacts/battle-stability-%d.png" % i)
	print("STABILITY paused90: arena sorts=",sorts," board rect changes=",board_moves," name invalidations=",name_changes," unique layouts=",positions," image hashes=",frames)
	positions.clear()
	frames.clear()
	sorts = 0
	board_moves = 0
	game.start_battle()
	var peak_delta := 0.0
	var last_time := Time.get_ticks_usec()
	for i in 180:
		game._process(0.1)
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		peak_delta = maxf(peak_delta, (Time.get_ticks_usec() - last_time) / 1000.0)
		last_time = Time.get_ticks_usec()
		var key := str([ui.ally_panel.position,ui.ally_panel.bags[0].get_global_rect(),ui._backdrop.material.get_shader_parameter("ally_board")])
		positions[key] = int(positions.get(key,0)) + 1
		if i % 15 == 0 and DisplayServer.get_name() != "headless":
			var screenshot := root.get_texture().get_image()
			# Exposed lower-center scenery, away from item/portrait activation effects.
			var region := screenshot.get_region(Rect2i(1190,1410,180,20))
			var sha := region.get_data().hex_encode().sha256_text()
			frames[sha] = int(frames.get(sha,0)) + 1
			if i in [30,90,150]: screenshot.save_png("res://artifacts/battle-running-%d.png" % i)
	print("STABILITY running180: sorts=",sorts," moves=",board_moves," layouts=",positions," lower background hashes=",frames," peak frame ms=",peak_delta)
	scene.queue_free()
	for i in 8: await process_frame
	await create_timer(.2).timeout
	quit()
