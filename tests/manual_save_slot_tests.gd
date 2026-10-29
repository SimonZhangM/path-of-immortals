extends SceneTree
const Files = preload("res://scripts/entry/save_file.gd")
const Slots = preload("res://scripts/entry/save_slot_policy.gd")
const Meta = preload("res://scripts/entry/save_metadata.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
const Catalog = preload("res://scripts/entry/save_catalog.gd")
var directory := "res://artifacts/save-kind/run-%d/" % Time.get_ticks_usec()
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func settle() -> void:
	for i in 5: await process_frame
func run() -> void:
	create_timer(65).timeout.connect(func():quit(2))
	AudioServer.set_bus_mute(0,true)
	root.mode=Window.MODE_WINDOWED
	root.content_scale_size=Vector2i.ZERO
	DirAccess.make_dir_recursive_absolute(directory)
	var actual_hash := FileAccess.get_sha256(Slots.AUTO_PATH)
	var raw := Files.read(Slots.AUTO_PATH)
	check(not raw.is_empty(),"read-only current fixture")
	Slots.auto_path=directory+"auto.json"
	Session.index_path=directory+"last.json"
	preload("res://scripts/entry/start_menu_background_cycle.gd").state_path=directory+"background.cfg"
	var manual := directory+"manual.json"
	var auto := raw.duplicate(true)
	auto.save_info={"save_kind":"auto","playtime_ms":1000,"playtime_complete":true}
	Files.write(Slots.auto_path,auto)
	raw.save_info={"save_kind":"manual","playtime_ms":8765000,"playtime_complete":true}
	raw.spirit_stones=5432
	raw.narrative.identity={"surname":"杨","given_name":"笑一"}
	# An old migration flag exercises the read-only migration path too.
	raw.respawn_rules_version=0
	Files.write(manual,raw)
	var manual_hash:=FileAccess.get_sha256(manual)
	check(Slots.is_auto(Slots.auto_path) and Slots.is_manual(manual),"separate slot policies")
	Meta.start(manual)
	check(Meta.active_path.is_empty(),"manual never starts a write timer")
	var catalog:=Catalog.new()
	catalog.index_path=directory+"slots.json"
	catalog.legacy_path=Slots.auto_path
	check(catalog.register(manual)==OK,"manual registered after fixed 01")
	var entries:=catalog.entries()
	check(entries.size()==2 and entries[0].slot==1 and entries[0].save_kind=="auto" and entries[1].slot==2 and entries[1].save_kind=="manual","01 auto / 02 manual labels")
	var page = load("res://scenes/entry/start_menu.tscn").instantiate()
	page.continue_fallback_path=Slots.auto_path
	page.save_catalog_override=catalog
	root.add_child(page)
	current_scene=page
	while page.entrance.active: await process_frame
	page._request_menu(&"load")
	await settle()
	var browser=page.save_browser
	for resolution in [Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=resolution
		await settle()
		for i in 2:
			browser.select(i)
			await settle()
			var badge:TextureRect=browser.row_buttons[i].get_node("SaveKindBadge")
			check(badge.size.y==27 and is_equal_approx(badge.size.x,27.0*4.0*0.95),"list badge keeps height and narrows five percent")
			check(not browser.canvas.has_node("SaveKindBadge"),"detail heading omits save nature")
			check(badge.texture.atlas.get_image().has_mipmaps(),"badge mipmaps")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/save-kind/%s-%d.png" % [entries[i].save_kind,resolution.x])
	page.queue_free()
	await settle()
	check(Session.begin_resume(manual),"start manual load")
	var route=load("res://scenes/maps/session_start.tscn").instantiate()
	root.add_child(route)
	current_scene=route
	while is_instance_valid(route): await process_frame
	await settle()
	var map=current_scene
	check(map.get("startup_error")=="" and map.get("loadout")!=null,"manual fully restores")
	if map.get("loadout")==null: quit(1); return
	check(map.inventory_save_path==Slots.auto_path and Session.active_path==Slots.auto_path,"gameplay switches to auto target")
	check(Session.resume_path("")==Slots.auto_path,"continue uses most recent auto progress")
	check(map.loadout.spirit_stones==5432 and DialogueJournal.full_name(map.loadout.narrative)=="杨笑一","manual gameplay state was loaded")
	check(Meta.active_path==Slots.auto_path and Meta.base_ms==8765000,"timer inherits manual history, writes only auto")
	check(Files.read(Slots.auto_path).save_info.save_kind=="auto","adopted slot retains auto classification")
	check(FileAccess.get_sha256(manual)==manual_hash,"migration and load do not modify manual")
	check(not MapLoadoutStore.save(map.loadout,manual).is_empty(),"accidental autosave to manual rejected")
	map.loadout.spirit_stones+=17
	check(MapLoadoutStore.save(map.loadout,map.inventory_save_path).is_empty(),"later autosave succeeds")
	check(Meta.flush()==OK and Files.read(Slots.auto_path).spirit_stones==5449,"timer preserves latest auto gameplay")
	map.queue_free()
	await settle()
	Meta.stop()
	check(FileAccess.get_sha256(manual)==manual_hash,"manual remains frozen after normal save and exit")
	var auto_hash:=FileAccess.get_sha256(Slots.auto_path)
	# Failed restoration cannot overwrite the previous auto slot.
	var bad:=directory+"invalid-manual.json"
	Files.write(bad,{"version":2,"board_id":"bad.board","owned_units":{},"placements":[],"save_info":{"save_kind":"manual"}})
	var bad_hash:=FileAccess.get_sha256(bad)
	check(Session.begin_resume(bad),"bad full-state envelope accepted for validation")
	route=load("res://scenes/maps/session_start.tscn").instantiate()
	root.add_child(route)
	current_scene=route
	while is_instance_valid(route): await process_frame
	await settle()
	check(current_scene.scene_file_path.ends_with("start_menu.tscn") and current_scene.error_label.visible,"bad manual returns to menu")
	check(FileAccess.get_sha256(Slots.auto_path)==auto_hash and FileAccess.get_sha256(bad)==bad_hash,"failed load preserves both files")
	check(FileAccess.get_sha256(Slots.AUTO_PATH)==actual_hash,"real character untouched by tests")
	current_scene.queue_free()
	await settle()
	print("MANUAL_SAVE_SLOT: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
