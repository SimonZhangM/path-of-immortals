extends Node
## Run the scene as the initial scene, not via a SceneTree test after startup.
const Music = preload("res://scripts/entry/entry_music.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _enter_tree() -> void:
	preload("res://scripts/entry/start_menu_background_cycle.gd").state_path = "res://artifacts/entry-music-cold-background.cfg"
func _ready() -> void:
	# Exercise two requests while the engine is still attaching its main scene.
	var pending := Music.ensure_for(get_tree())
	check(Music.ensure_for(get_tree())==pending,"startup requests share pending player")
	await get_tree().create_timer(0.5).timeout
	var player := get_tree().root.get_node_or_null("EntryMusic") as AudioStreamPlayer
	check(player!=null and player==pending,"cold start attaches one music player")
	if player==null:
		get_tree().quit(1)
		return
	check(player.playing and player.stream is AudioStreamMP3 and player.stream.loop,"cold start plays looping MP3")
	check(player.stream.data==load("res://assets/game-start.mp3").data,"cold start uses game-start")
	var bus := AudioServer.get_bus_index(player.bus)
	check(not AudioServer.is_bus_mute(bus),"output bus is not muted")
	var position := player.get_playback_position()
	var peak := -200.0
	for i in 180:
		peak = maxf(peak,AudioServer.get_bus_peak_volume_left_db(bus,0))
		peak = maxf(peak,AudioServer.get_bus_peak_volume_right_db(bus,0))
		await get_tree().process_frame
	check(player.playing and player.get_playback_position()>position,"cold start playback advances")
	check(peak>-70.0,"audio mixer outputs non-silent samples")
	print("ENTRY_MUSIC_COLD_START: %d checks; %d failures; output=%s; peak_db=%.2f" % [checks,failures,AudioServer.output_device,peak])
	get_tree().quit(1 if failures else 0)
