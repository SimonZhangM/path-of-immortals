extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 8: await process_frame

func _run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	root.add_child(scene)
	game.set_process(false)
	await settle()
	check(game.startup_error.is_empty(), "actual encounter battle starts")
	var ui = scene.get_node("MainUI")
	var card: PartyMemberCard = ui.ally_panel.cards[0]
	var bar_positions := []
	for key in ["hp","stamina","spirit"]: bar_positions.append(card.stat_bars[key].global_position)
	var face := card.portrait.global_position
	game.party[0].armor_capacity_sources.test = 10
	game.party[0].inventory.add_item("test.armor-display", "base.organ.cslz_hide", Vector2i.ZERO)
	card.refresh(game.party[0])
	await settle()
	check(card.armor_status.visible, "armor line appears")
	for index in 3:
		check(card.stat_bars[["hp","stamina","spirit"][index]].global_position.is_equal_approx(bar_positions[index]), "armor does not move resource row")
	check(card.portrait.global_position.is_equal_approx(face), "extra states do not move portrait")
	check(ui.ally_panel.combat_status.get_parent() == card.resources and ui.ally_panel.combat_status.global_position.y > card.stat_bars.spirit.get_global_rect().end.y, "other states below spirit")
	game.party[0].armor_capacity_sources.erase("test")
	game.party[0].inventory.take("test.armor-display")
	card.refresh(game.party[0])
	await settle()
	check(card.stat_bars.hp.global_position.is_equal_approx(bar_positions[0]), "removing armor leaves bars fixed")
	for value in ["00.00","02.61","123.45"]:
		ui._time.text = value
		await settle()
		check(absf(ui._time.get_global_rect().get_center().x - ui._timer_frame.get_global_rect().get_center().x) < 1, "digits alone centered: " + value)
		var font: Font = ui._time.get_theme_font("font")
		var digit_width: float = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,39).x * ui.scale.x
		check(ui._time_seconds.global_position.x > ui._time.get_global_rect().get_center().x + digit_width * .5, "suffix follows one space")
	check(is_equal_approx(CooldownRing.SIZE_SCALE,2.0/3.0), "CD disc diameter reduced by one third")
	var enemy_board: BoardLayout = game.enemies[0].board
	check(enemy_board.texture_path == "res://assets/zhenpan-qshw-cslz.webp" and enemy_board.grid_size == Vector2i(3,3), "boar-only new 3x3 board")
	check(enemy_board.resource_bonuses.is_empty() and game.enemies[0].maximum("hp") == 96, "new board does not alter stats")
	check(game.registry.get_board(game.registry.get_enemy("base.enemy.wild_dog").board_layout).texture_path != enemy_board.texture_path, "other enemy boards unchanged")
	check((load(enemy_board.texture_path) as Texture2D).get_image().has_mipmaps(), "new board mipmaps")
	check((load("res://assets/zhuangtai-tl.webp") as Texture2D).get_image().has_mipmaps(), "updated stamina icon imported with mipmaps")
	var axe := ""
	for entry: Dictionary in game.storage.entries():
		if entry.item_id == "base.map_item.t01_0003": axe = entry.instance_id
	check(game.equip(axe,0,Vector2i.ZERO), "equip actual柴斧")
	game.start_battle()
	game.party[0].definition.max_hp = 10000
	game.party[0].hp = 10000
	game.party[0].stamina = 0
	game._process(8.5)
	check(game.simulation.state.item_runtime[axe].activation_count == 0, "unaffordable axe does not attack")
	check(game.simulation.timeline.remaining(axe) == 8500000, "unaffordable axe immediately restarts full CD")
	check(game.party[0].stamina == 0, "wasted cycle charges nothing")
	game.party[0].stamina = 6
	game._process(.1)
	check(game.simulation.state.item_runtime[axe].activation_count == 0, "mid-cycle resource recovery does not release stored hit")
	game._process(8.4)
	check(game.simulation.state.item_runtime[axe].activation_count == 1, "next full cycle attacks normally")
	game._process(8.5)
	check(game.simulation.state.item_runtime[axe].activation_count == 1 and game.simulation.timeline.remaining(axe) == 8500000, "repeated shortfall wastes another cycle")
	# Manual non-prepared mode retains its existing ready/request semantics.
	game.simulation.timeline.set_mode(axe,false)
	game._process(8.5)
	check(game.simulation.timeline.remaining(axe) == 0, "manual ready behavior preserved")
	game.simulation.timeline.set_mode(axe,true)
	game.party[0].definition.max_hp = 50
	game.party[0].hp = 28
	game.party[0].stamina = 6
	game.party[0].armor_capacity_sources.test = 10
	game.pause_battle()
	ui._refresh()
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-cycle-layout.png")
	scene.queue_free()
	await settle()
	print("BATTLE CYCLE/LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
