extends SceneTree
## Read-only real catalogue preview; never activates or writes a character save.
const Catalog = preload("res://scripts/entry/save_catalog.gd")
const Files = preload("res://scripts/entry/save_file.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for index in 4: await process_frame
func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	DirAccess.make_dir_recursive_absolute("res://artifacts/save-browser")
	var before := FileAccess.get_sha256(MapLoadoutStore.DEFAULT_PATH)
	preload("res://scripts/entry/start_menu_background_cycle.gd").state_path = "res://artifacts/save-browser/preview-background.cfg"
	var page = load("res://scenes/entry/start_menu.tscn").instantiate()
	root.add_child(page)
	current_scene = page
	while page.entrance.active: await process_frame
	page._request_menu(&"load")
	await settle()
	var browser = page.save_browser
	check(browser.entries.size()>=1 and browser.entries[0].slot==1,"actual legacy save is slot 01")
	check(browser.entries[0].name=="张辰宇" and browser.entries[0].location=="青石镇","actual character and location")
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/save-browser/actual-%d.png" % resolution.x)
		check(browser.canvas.get_global_rect().end.y<=root.size.y,"read page remains in viewport")
	page._close_saves()
	page.hide()
	var world = load("res://scripts/map/map_world_map.gd").new()
	root.add_child(world)
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.present("base.map.qingshizhen",Files.read(MapLoadoutStore.DEFAULT_PATH).get("map_visited",{}))
	for icon in ["dazongmen","cunzhuang","dongxue","yiji","mijing"]:
		var texture: Texture2D = load("res://assets/UI-map-%s.webp" % icon)
		check(texture.get_image().has_mipmaps(),"updated icon mipmaps "+icon)
		var source := Image.load_from_file("res://assets/UI-map-%s.webp" % icon)
		var imported := texture.get_image()
		imported.clear_mipmaps()
		check(imported.get_size()==source.get_size(),"new icon source dimensions "+icon)
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = resolution
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/save-browser/legend-%d.png" % resolution.x)
	check(before==FileAccess.get_sha256(MapLoadoutStore.DEFAULT_PATH),"real preview never writes character")
	print("SAVE_BROWSER_PREVIEW: %d checks; %d failures" % [checks,failures])
	world.queue_free()
	page.queue_free()
	await settle()
	quit(1 if failures else 0)
