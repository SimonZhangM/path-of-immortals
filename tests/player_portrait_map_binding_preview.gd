extends SceneTree

const PLAYER_FRAMES = preload("res://scripts/presentation/player_portrait_frames.gd")
const BUBBLE = preload("res://scripts/dialogue/dialogue_bubble.gd")

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for i in 6: await process_frame

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	map.defer_location_save = true
	assert(map.player_status == null)
	root.add_child(map)
	await settle()
	assert(map.startup_error.is_empty(), map.startup_error)
	assert(map.dialogue.player_status == map.player_status)
	assert(map.status_header.state == map.player_status)
	var event: Dictionary = map.event_registry.events["base.map_event.qingshihewan.wounded_disciple"]
	for rank: String in PLAYER_FRAMES.portrait_paths:
		map.player_status.cultivation_rank_id = rank
		map.player_status.changed.emit()
		map.dialogue.present(event, "这是……法器？", "base.map_player.chen_yu")
		var expected: Texture2D = map.status_header.portrait.texture
		assert(map.dialogue.portrait.texture == expected)
		assert(expected.atlas.resource_path == PLAYER_FRAMES.portrait_paths[rank])
		var bubble = BUBBLE.new()
		bubble.configure("player", ["头像一致性检查"], NpcDialogueLibrary.new(), map.player_status, map.player_status.display_name)
		assert(bubble.portrait.texture == expected)
		bubble.free()
		map.dialogue.present(event, "弟子头像保持不变。", event.speaker_id)
		assert(map.dialogue.portrait.texture.atlas.resource_path == event.speakers[event.speaker_id].portrait)
	map.dialogue.present(event, "这是……法器？", "base.map_player.chen_yu")
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/player-portrait-map-binding.png")
	var status: MapPlayerStatus = map.player_status
	map.queue_free()
	await settle()
	var next_map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	next_map.inventory_save_path = ""
	next_map.player_status = status
	next_map.defer_map_music = true
	next_map.defer_location_save = true
	root.add_child(next_map)
	await settle()
	assert(next_map.startup_error.is_empty(), next_map.startup_error)
	assert(next_map.dialogue.player_status == status)
	assert(next_map.status_header.state == status)
	next_map.queue_free()
	await settle()
	print("PASS: actual cold-map initialization, shared header/dialogue status, six realm faces, popup player bubbles, unchanged NPC portrait and inherited map status. No mouse or durable save.")
	quit()
