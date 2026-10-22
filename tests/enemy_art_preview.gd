extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func settle() -> void:
	for i in 8: await process_frame
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var scene = load("res://scenes/main/main.tscn").instantiate()
	var game: GameManager = scene.get_node("GameManager")
	game.use_saved_loadout = true
	game.loadout_save_path = ""
	game.enemy_id = "base.enemy.chisong_liaozhu"
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	check(game.startup_error.is_empty(),"real battle loads: "+game.startup_error)
	await settle()
	var ui = scene.get_node("MainUI")
	var bag: InventoryView = ui.enemy_panel.bags[0]
	var portrait: TextureRect = ui.enemy_panel.cards[0].portrait
	var metrics := {"board_size":[bag.size.x,bag.size.y],"board_center":[bag.get_global_rect().get_center().x,bag.get_global_rect().get_center().y],"portrait_size":[portrait.size.x,portrait.size.y],"portrait_position":[portrait.global_position.x,portrait.global_position.y],"player_size":[ui.ally_panel.bags[0].size.x,ui.ally_panel.bags[0].size.y]}
	print("Geometry: ",metrics," stage=",bag.get_parent().get_global_rect()," flags=",bag.size_flags_vertical)
	if baseline:
		FileAccess.open("res://artifacts/enemy-art-baseline.json",FileAccess.WRITE).store_string(JSON.stringify(metrics))
	else:
		check(bag.size.is_equal_approx(Vector2.ONE*548*.9),"enemy board reduced10percent")
		check(bag.get_global_rect().get_center().is_equal_approx(bag.get_parent().get_global_rect().get_center()),"enemy board centered in original stage")
		check(portrait.size==Vector2(272,272),"portrait keeps fixed display size despite new source resolution")
		if FileAccess.file_exists("res://artifacts/enemy-art-baseline.json"):
			var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/enemy-art-baseline.json"))
			check(bag.get_global_rect().get_center().is_equal_approx(Vector2(previous.board_center[0],previous.board_center[1])),"enemy board previous center preserved")
			check(portrait.global_position.is_equal_approx(Vector2(previous.portrait_position[0],previous.portrait_position[1])),"portrait previous position preserved")
			check(ui.ally_panel.bags[0].size.is_equal_approx(Vector2(previous.player_size[0],previous.player_size[1])),"player board unchanged")
		check(bag._board_art.get_rect().is_equal_approx(bag.board_layout.art_rect(bag.size)),"board and item mapping share scaled geometry")
		check(game.enemies[0].inventory.occupied_cells()==9 and bag.board_layout.grid_size==Vector2i(3,3),"pig nine cells preserved")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/enemy-art-battle-%s.png"%("before" if baseline else "after"))
	var registry: ContentRegistry = game.registry
	scene.queue_free()
	await settle()
	if not baseline:
		await gallery(registry)
	print("Enemy art preview: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func gallery(registry: ContentRegistry) -> void:
	# Read authoring profiles without inventing gameplay for the four future species.
	var profiles: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/enemy_art.json"))
	check(profiles.size()==8,"eight named portrait/board profiles")
	var canvas := Control.new(); root.add_child(canvas)
	var bg := ColorRect.new(); bg.size=Vector2(2560,1440); bg.color=Color("101821"); canvas.add_child(bg)
	for i in profiles.size():
		var profile: Dictionary = profiles[i]
		check(registry.get_enemy_art(profile.id)==profile,"profile loaded into registry")
		var enemy := registry.get_enemy(profile.id)
		if not enemy.is_empty(): check(enemy.portrait==profile.portrait and enemy.board_layout==profile.board_layout and enemy.portrait_includes_frame==profile.portrait_includes_frame and enemy.get("portrait_frame", "")==profile.get("portrait_frame", ""),"existing enemy resolves shared profile")
		var board := registry.get_board(profile.board_layout)
		var texture: Texture2D = load(board.texture_path)
		check(board.source_size==texture.get_size() and board.grid_size==Vector2i(3,3),profile.name+" independent3x3 calibration")
		check(texture.get_image().has_mipmaps() and (load(profile.portrait) as Texture2D).get_image().has_mipmaps(),profile.name+" both mipmaps")
		var origin := Vector2((i%4)*640,(i/4)*720)
		var head := TextureRect.new(); head.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; head.texture=load(profile.portrait); head.position=origin+Vector2(55,12); head.size=Vector2(150,150); head.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; head.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; canvas.add_child(head)
		var label := Label.new(); label.text=profile.name; label.position=origin+Vector2(215,65); label.add_theme_font_size_override("font_size",32); canvas.add_child(label)
		var art := TextureRect.new(); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.texture=texture; art.position=origin+Vector2(50,170); art.size=Vector2(540,540); art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; canvas.add_child(art)
		for x in board.x_lines:
			var line := Line2D.new(); line.width=1;line.default_color=Color(0.2,1,1,.65); line.points=PackedVector2Array([board.source_to_view(Vector2(x,board.y_lines[0]),art.size),board.source_to_view(Vector2(x,board.y_lines[-1]),art.size)]);art.add_child(line)
		for y in board.y_lines:
			var line := Line2D.new(); line.width=1;line.default_color=Color(0.2,1,1,.65); line.points=PackedVector2Array([board.source_to_view(Vector2(board.x_lines[0],y),art.size),board.source_to_view(Vector2(board.x_lines[-1],y),art.size)]);art.add_child(line)
		for cell_y in 3:
			for cell_x in 3:
				var cell := Vector2i(cell_x,cell_y)
				check(board.cell_at(board.footprint_rect(cell,Vector2i.ONE,art.size).get_center(),art.size)==cell,profile.name+" mapped cell")
	if DisplayServer.get_name()!="headless":
		await settle();await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/enemy-art-calibration.png")
	canvas.queue_free(); await settle()
