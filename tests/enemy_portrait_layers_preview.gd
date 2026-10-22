extends SceneTree

const FRAMES = preload("res://scripts/presentation/enemy_portrait_frames.gd")
const FRAME_PATH := "res://assets/UI-monster-fanren-portraitframe.webp"
const ENEMIES := ["chisong_liaozhu", "huiji_shanlang", "qingke_heyuan", "qingling_yanzhi"]
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

func check_layers(portrait: TextureRect, frame: TextureRect, label: String) -> void:
	check(frame != null and frame.visible, label + " separate frame visible")
	if frame == null: return
	check(frame.texture.resource_path == FRAME_PATH, label + " mortal frame")
	check(portrait.texture.get_size() == Vector2(627,627), label + " new borderless source loaded")
	check(frame.texture.get_size() == Vector2(627,627), label + " half-size frame source loaded")
	check(frame.texture.get_image().has_mipmaps() and portrait.texture.get_image().has_mipmaps(), label + " mipmaps")
	check(frame.get_parent() == portrait and not portrait.clip_contents, label + " overlay not clipped")
	check(frame.mouse_filter == Control.MOUSE_FILTER_IGNORE, label + " decorative layer ignores mouse")
	check(frame.get_global_rect().get_center().is_equal_approx(portrait.get_global_rect().get_center()), label + " centers aligned")
	check(frame.size.is_equal_approx(portrait.size * FRAMES.canvas_scale()), label + " shared scale")
	var image_radius: float = portrait.size.x * FRAMES.geometry.portrait_radius / FRAMES.geometry.portrait_canvas_size
	var hole_radius: float = frame.size.x * FRAMES.geometry.frame_inner_radius / FRAMES.geometry.frame_canvas_size
	var outer_radius: float = frame.size.x * FRAMES.geometry.frame_outer_radius / FRAMES.geometry.frame_canvas_size
	check(image_radius > hole_radius and image_radius < outer_radius, label + " image covers aperture and stays inside outer rim")

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	var gallery := Image.create(1600,1000,false,Image.FORMAT_RGBA8)
	gallery.fill(Color("17212b"))
	var first_battle := Rect2()
	var first_frame := Rect2()
	var first_modal := Rect2()
	var first_modal_frame := Rect2()
	for viewport_size in [Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = viewport_size
		for i in ENEMIES.size():
			var scene: Node = load("res://scenes/main/main.tscn").instantiate()
			var game: GameManager = scene.get_node("GameManager")
			game.use_saved_loadout = true
			game.loadout_save_path = ""
			game.enemy_id = "base.enemy." + ENEMIES[i]
			scene.process_mode = Node.PROCESS_MODE_DISABLED
			root.add_child(scene)
			await settle()
			check(game.startup_error.is_empty(), ENEMIES[i]+" actual battle startup: "+game.startup_error)
			if not game.startup_error.is_empty(): quit(1); return
			var ui = scene.get_node("MainUI")
			var card: PartyMemberCard = ui.enemy_panel.cards[0]
			var ally: PartyMemberCard = ui.ally_panel.cards[0]
			check_layers(card.portrait,card.portrait_frame,ENEMIES[i]+" battle")
			check(card.portrait.size == Vector2(272,272), "battle original portrait size preserved")
			check(card.portrait.position.is_equal_approx(Vector2(-18,-18+card.portrait_vertical_offset)), "battle original position preserved")
			check(card.name_label.text == game.enemies[0].definition.name, "nameplate text unchanged")
			check(not game.enemies[0].definition.portrait_includes_frame, "registry resolves borderless profile")
			check(ally.portrait_frame.texture.resource_path.begins_with("res://assets/player-level-"), "player frame unchanged")
			if i == 0:
				first_battle = card.portrait.get_global_rect()
				first_frame = card.portrait_frame.get_global_rect()
			else:
				check(card.portrait.get_global_rect().is_equal_approx(first_battle), "four enemies share battle portrait size and position")
				check(card.portrait_frame.get_global_rect().is_equal_approx(first_frame), "four enemies share battle frame size and position")
			# Refreshing health/cultivation must not replace the independent monster frame.
			card._last_cultivation_id = "refresh-test"
			card.refresh(game.enemies[0])
			check(card.portrait_frame.texture.resource_path == FRAME_PATH, "refresh preserves mortal overlay")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var shot := root.get_texture().get_image()
				if i == 0: shot.save_png("res://artifacts/enemy-portrait-battle-%d.png" % viewport_size.x)
				if viewport_size.x == 2560:
					var crop := shot.get_region(Rect2i(card.portrait_frame.get_global_rect().grow(6)))
					crop.resize(360,360,Image.INTERPOLATE_LANCZOS)
					gallery.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(i*400+20,20))
			var modal := MapEncounterDialog.new()
			root.add_child(modal)
			modal.size = Vector2(viewport_size)
			var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cliff_encounter.json"))
			modal.present(event,game.enemies[0])
			await settle()
			check_layers(modal.portrait,modal.portrait_frame,ENEMIES[i]+" encounter")
			var factor: float = minf(viewport_size.x/1920.0,viewport_size.y/1080.0)*MapEncounterDialog.DISPLAY_SCALE
			check(modal.portrait.size == (Vector2.ONE*183*factor).round(), "encounter original portrait size preserved")
			if i == 0:
				first_modal = modal.portrait.get_global_rect()
				first_modal_frame = modal.portrait_frame.get_global_rect()
			else:
				check(modal.portrait.get_global_rect().is_equal_approx(first_modal), "four encounter portraits equal")
				check(modal.portrait_frame.get_global_rect().is_equal_approx(first_modal_frame), "four encounter frames equal")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var shot := root.get_texture().get_image()
				if i == 0: shot.save_png("res://artifacts/enemy-portrait-encounter-%d.png" % viewport_size.x)
				if viewport_size.x == 2560:
					var crop := shot.get_region(Rect2i(modal.portrait_frame.get_global_rect().grow(5)))
					crop.resize(280,280,Image.INTERPOLATE_LANCZOS)
					gallery.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(i*400+60,480))
			# Reused dialogs hide their frame when presenting an unrelated legacy fixture.
			FRAMES.show_definition(modal.portrait_frame,{})
			check(not modal.portrait_frame.visible and modal.portrait_frame.texture == null, "no stale overlay on a legacy portrait")
			modal.queue_free()
			scene.queue_free()
			await settle()
	if DisplayServer.get_name() != "headless": gallery.save_png("res://artifacts/enemy-portrait-layers-gallery.png")
	print("Enemy portrait layers: %d checks, %d failures. Static rendering only; no input or durable save." % [checks,failures])
	quit(1 if failures else 0)
