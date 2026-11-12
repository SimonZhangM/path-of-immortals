extends SceneTree
const Music = preload("res://scripts/entry/entry_music.gd")
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
	for i in 5: await process_frame
func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	# Hidden test windows may lose focus; playback checks must keep advancing.
	check(root.get_node("GameSettings").apply_values({"background_pause":false,"background_mute":false}).is_empty(),"isolated playback fixture disables focus pausing")
	AudioServer.set_bus_mute(0,false)
	AudioServer.set_bus_volume_db(0,-90.0)
	Session.index_path = "res://artifacts/entry-music-isolated-index.json"
	preload("res://scripts/entry/start_menu_background_cycle.gd").state_path = "res://artifacts/entry-music-background.cfg"
	var paths := ["user://inventory_loadout.json","user://manual_save_02.json","user://save_slots.json"]
	var hashes := []
	for path in paths: hashes.append(FileAccess.get_sha256(path))
	var page = load("res://scenes/entry/start_menu.tscn").instantiate()
	root.add_child(page)
	current_scene = page
	while page.entrance.active: await process_frame
	var music = page.music
	check(music.playing and music.stream is AudioStreamMP3,"menu automatically starts music")
	check(music.stream.data==load("res://assets/game-start1.mp3").data and not music.stream.loop,"menu starts with game-start1 without single-track looping")
	music.seek(music.stream.get_length()-0.15)
	await create_timer(0.6).timeout
	check(music.playing and music.get_playback_position()<1.5 and music.stream.data==load("res://assets/game-start2.mp3").data,"actual end of game-start1 advances to game-start2")
	music.seek(music.stream.get_length()-0.15)
	await create_timer(0.6).timeout
	check(music.playing and music.get_playback_position()<1.5 and music.stream.data==load("res://assets/game-start1.mp3").data,"actual end of game-start2 returns to game-start1")
	music.seek(music.stream.get_length()-0.15)
	await create_timer(0.6).timeout
	check(music.stream.data==load("res://assets/game-start2.mp3").data,"playlist continues alternating on later cycles")
	page._open_saves()
	await settle()
	check(page.music==music and music.playing,"save browser retains same player")
	page._close_saves()
	page._request_menu(&"settings")
	check(page.music==music and music.playing,"settings entry does not stop music")
	page.settings_panel.closed.emit()
	await settle()
	page._begin_journey()
	while is_instance_valid(page) or root.has_node("EntrySceneCrossfade"): await process_frame
	check(current_scene.scene_file_path.ends_with("character_preparation.tscn") and root.get_node("EntryMusic")==music and music.playing,"preparation preserves continuous player")
	change_scene_to_file("res://scenes/entry/start_menu.tscn")
	await scene_changed
	page = current_scene
	while page.entrance.active: await process_frame
	check(page.music==music and music.playing,"return to menu preserves continuous player")
	check(music.stream.data==load("res://assets/game-start2.mp3").data,"menu navigation preserves current playlist track")
	page._navigating = true
	page._load_game("res://artifacts/entry-music-intentionally-missing-save.json")
	check(not music.playing and root.has_node("GameLoadingOverlay"),"entry music stops immediately at loading")
	while page._navigating: await process_frame
	await settle()
	check(page.music==music and music.playing and not root.has_node("GameLoadingOverlay"),"failed loading restores menu music")
	for i in paths.size(): check(hashes[i]==FileAccess.get_sha256(paths[i]),"real save unchanged")
	music.stop()
	music.stream = null
	music.queue_free()
	await settle()
	print("ENTRY_MUSIC_LIFECYCLE: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
