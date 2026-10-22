extends SceneTree

const PLAYER_FRAMES = preload("res://scripts/presentation/player_portrait_frames.gd")
const ENEMY_FRAMES = preload("res://scripts/presentation/enemy_portrait_frames.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 6: await process_frame

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.huiji_shanlang"
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	await settle()
	check(game.startup_error.is_empty(), "actual battle startup: " + game.startup_error)
	if not game.startup_error.is_empty(): quit(1); return
	var ui = scene.get_node("MainUI")
	var player: PartyMemberCard = ui.ally_panel.cards[0]
	var enemy: PartyMemberCard = ui.enemy_panel.cards[0]
	var rewards = ui.victory_rewards
	var story := MapRewardDialog.new()
	story.use_small_reward_art(MapExitDialog.DESIGN_SIZE.y)
	ui.add_child(story)
	story.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var categories: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json")).categories
	var records: Array[Dictionary] = []
	for raw: Dictionary in game._durable_loadout.records.values():
		if raw.name == "山狼利爪":
			var copy := raw.duplicate(true)
			copy.quantity = 1
			records.append(copy)
	check(records.size() == 1, "wolf claw reward fixture from actual catalog")
	check(GameAudio.STREAMS.magic.resource_path == "res://assets/sfx-magic.ogg" and GameAudio.STREAMS.magic.get_length() > 0, "replacement magic Ogg decodes at current path")
	for dimensions in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = dimensions
		story._layout()
		await settle()
		var enemy_rect := enemy.portrait.get_global_rect()
		var enemy_frame_rect := enemy.portrait_frame.get_global_rect()
		var enemy_visible_diameter: float = enemy_rect.size.x * 2.0 * ENEMY_FRAMES.geometry.portrait_radius / ENEMY_FRAMES.geometry.portrait_canvas_size
		for rank in ["mortal","qi_refining","foundation","golden_core","nascent_soul","spirit_transformation"]:
			game.party[0].set_cultivation_rank("base.cultivation." + rank)
			player.refresh(game.party[0])
			await settle()
			var player_rect := player.portrait.get_global_rect()
			check(is_equal_approx(player_rect.size.x,enemy_visible_diameter),rank+" portrait circle matches enemy")
			check(is_equal_approx(player_rect.get_center().y,enemy_rect.get_center().y),rank+" centers share horizontal baseline")
			check(is_equal_approx(player.nameplate.get_global_rect().get_center().y,enemy.nameplate.get_global_rect().get_center().y),rank+" nameplates aligned")
			check(player.name_label.text == game.party[0].definition.name,rank+" name without realm suffix")
			var source_scale: float = player.portrait.size.x / PLAYER_FRAMES.PORTRAIT_SOURCE_SIZE
			check(player.portrait_frame.size.is_equal_approx(PLAYER_FRAMES.SOURCE_SIZE*source_scale),rank+" frame scales with portrait")
			check((player.portrait_frame.position+PLAYER_FRAMES.SOURCE_CENTER*source_scale).is_equal_approx(player.portrait.get_rect().get_center()),rank+" frame circle centered")
			check(enemy.portrait.get_global_rect().is_equal_approx(enemy_rect) and enemy.portrait_frame.get_global_rect().is_equal_approx(enemy_frame_rect),rank+" enemy geometry unchanged")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/battle-portraits-aligned-%d.png" % dimensions.x)
		for count in [0,1,2,5]:
			var batch: Array[Dictionary] = []
			for i in count: batch.append(records[0].duplicate(true))
			rewards.present_loot(batch,categories)
			await settle()
			check(rewards.backing.texture.atlas.resource_path == story.backing.texture.atlas.resource_path,"same story reward skin")
			check(rewards.backing.get_global_rect().is_equal_approx(story.backing.get_global_rect()),"same story reward height and center")
			check(rewards.heading.position.is_equal_approx(story.heading.position),"same heading position")
			check(rewards.accept_button.get_node("AcceptCaption").text == "确定" and rewards.review_button != null,"battle actions retained")
			check(rewards.grid.get_child_count() == count and rewards.empty_label.visible == (count==0),"empty and multiple loot layouts")
			check(rewards.scroll.get_rect().end.y < rewards.accept_button.position.y,"loot viewport above actions")
			if count == 1:
				var item = rewards.grid.get_child(0)
				check(is_equal_approx(item.size.x,152),"single card matches warm jade size")
				check(rewards.scroll.get_global_rect().encloses(item.get_global_rect()),"single card fits without clipping")
				check(item.quality_badge.get_global_rect().end.y < rewards.scroll.get_global_rect().end.y,"quality badge fully visible")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/battle-reward-small-%d-%d.png" % [dimensions.x,count])
			rewards.hide()
	story.queue_free()
	scene.queue_free()
	await settle()
	print("Battle portrait/reward preview: %d checks, %d failures. No mouse, simulation or durable save." % [checks,failures])
	quit(1 if failures else 0)
