extends Node

# Presentation time only: survives map/battle scenes, never drives simulation.
const MUSIC_FADE := 3.0
const WIPE_OUT := 1.0
const WIPE_IN := 1.0
const BATTLE_FADE := 1.0
const MUSIC_VOLUME := 0.501187 # -6 dB, matching battle music.
var music: AudioStreamPlayer
var map_id := ""
var playlist: Array = []
var track_index := 0
var music_state := "stopped"
var transitioning := false
var _fade: Tween
var _layer: CanvasLayer
var _cover: ColorRect
var _mask: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.name = "MapMusic"
	add_child(music)
	music.finished.connect(_next_track)
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_cover = ColorRect.new()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_mask = ShaderMaterial.new()
	_mask.shader = preload("res://scripts/map/map_wipe.gdshader")
	_cover.material = _mask
	_layer.add_child(_cover)
	_cover.hide()

func _input(_event: InputEvent) -> void:
	if transitioning:
		get_viewport().set_input_as_handled()

func validate_music(definition: Dictionary) -> String:
	var tracks: Variant = definition.get("music", [])
	if not tracks is Array:
		return "地图音乐必须为播放列表。"
	for path in tracks:
		if not path is String or not ResourceLoader.exists(path, "AudioStream"):
			return "地图音乐文件不存在。"
	return ""

func enter_map(definition: Dictionary, seconds: float = MUSIC_FADE) -> void:
	var next_id: String = definition.get("id", "")
	var tracks: Array = definition.get("music", [])
	if next_id == map_id and tracks == playlist and music_state in ["playing", "resuming"]:
		return
	_cancel_fade()
	var resume := next_id == map_id and tracks == playlist and music_state == "paused"
	if not resume:
		music.stop()
		map_id = next_id
		playlist = tracks.duplicate()
		track_index = 0
		music.volume_linear = 0.0
		music.stream_paused = false
		if playlist.is_empty():
			music_state = "stopped"
			return
		_play_track()
	else:
		music.stream_paused = false
	music_state = "resuming"
	if seconds <= 0.0:
		music.volume_linear = MUSIC_VOLUME
		music_state = "playing"
		return
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(music, "volume_linear", MUSIC_VOLUME, seconds)
	_fade.tween_callback(func(): music_state = "playing")

func _play_track() -> void:
	var stream := load(playlist[track_index]).duplicate() as AudioStream
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = false
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	music.stream = stream
	music.play()

func _next_track() -> void:
	# A track may end during a fade: advance without changing fade or gain.
	if playlist.is_empty() or music_state in ["stopped", "paused"]:
		return
	track_index = (track_index + 1) % playlist.size()
	_play_track()

func _cancel_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()

func fade_out(pause_for_battle: bool, seconds: float = MUSIC_FADE) -> void:
	_cancel_fade()
	music_state = "pausing" if pause_for_battle else "leaving"
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(music, "volume_linear", 0.0, seconds)
	_fade.tween_callback(func():
		if pause_for_battle:
			music.stream_paused = true
			music_state = "paused"
		else:
			music.stop()
			music_state = "stopped"
	)
	await _fade.finished

# The nearest normalized map edge determines movement, independent of camera zoom.
# Exit: sweep towards that edge. Arrival: reveal away from that edge.
static func direction(point: Vector2, extent: Vector2, arriving: bool) -> Vector2:
	var offset := point / extent - Vector2(0.5, 0.5)
	var result := Vector2(signf(offset.x), 0) if absf(offset.x) >= absf(offset.y) else Vector2(0, signf(offset.y))
	if result == Vector2.ZERO:
		result = Vector2.RIGHT
	return -result if arriving else result

func _wipe(direction_value: Vector2, revealing: bool, seconds: float, gain: float) -> void:
	_mask.set_shader_parameter("direction", direction_value)
	_mask.set_shader_parameter("revealing", revealing)
	_mask.set_shader_parameter("progress", 0.0)
	var started := Time.get_ticks_usec()
	var initial_gain := music.volume_linear
	while true:
		var progress := clampf(float(Time.get_ticks_usec() - started) / (seconds * 1000000.0), 0.0, 1.0)
		_mask.set_shader_parameter("progress", progress)
		music.volume_linear = lerpf(initial_gain, gain, progress)
		if progress >= 1.0:
			break
		await get_tree().process_frame

func change_map(source: Control, destination: Control, outgoing: Vector2, incoming: Vector2) -> void:
	transitioning = true
	_cover.material = _mask
	_cover.modulate.a = 1.0
	var source_mode := source.process_mode
	var destination_mode := destination.process_mode
	source.process_mode = Node.PROCESS_MODE_DISABLED
	destination.process_mode = Node.PROCESS_MODE_DISABLED
	_cover.show()
	_cancel_fade()
	music_state = "leaving"
	await _wipe(outgoing, false, WIPE_OUT, 0.0)
	music.stop()
	music_state = "stopped"
	# Commit only under a fully opaque screen. Destination was validated in advance.
	source.hide()
	destination.show()
	get_tree().current_scene = destination
	enter_map(destination.definition, 0.0)
	music.volume_linear = 0.0
	music_state = "resuming"
	await _wipe(incoming, true, WIPE_IN, MUSIC_VOLUME)
	music_state = "playing" if not playlist.is_empty() else "stopped"
	_cover.hide()
	destination.process_mode = destination_mode
	source.process_mode = source_mode
	transitioning = false

func change_battle_scene(source: Node, destination: Node, source_view: CanvasItem, destination_view: CanvasItem, entering_battle: bool, battle_audio: GameAudio) -> void:
	source.process_mode = Node.PROCESS_MODE_DISABLED
	destination.process_mode = Node.PROCESS_MODE_DISABLED
	transitioning = true
	_cover.material = null
	_cover.color = Color.BLACK
	_cover.modulate.a = 0.0
	_cover.show()
	_cancel_fade()
	if entering_battle:
		music_state = "pausing"
	await _uniform_fade(1.0, music if entering_battle else battle_audio.music, 0.0)
	if entering_battle:
		music.stream_paused = true
		music_state = "paused"
	else:
		battle_audio.music.stop()
	source_view.hide()
	destination_view.show()
	get_tree().current_scene = destination
	if entering_battle:
		battle_audio.start_music()
		battle_audio.music.volume_linear = 0.0
	else:
		enter_map(destination.definition, 0.0)
		music.volume_linear = 0.0
		music_state = "resuming"
	await _uniform_fade(0.0, battle_audio.music if entering_battle else music, MUSIC_VOLUME)
	if not entering_battle:
		music_state = "playing"
	_cover.hide()
	destination.process_mode = Node.PROCESS_MODE_INHERIT
	transitioning = false

func _uniform_fade(alpha: float, player: AudioStreamPlayer, gain: float) -> void:
	# One presentation-only wall clock keeps picture and sound in sync, even
	# after a slow loading/render frame. It never advances simulation time.
	var started := Time.get_ticks_usec()
	var initial_alpha := _cover.modulate.a
	var initial_gain := player.volume_linear
	while true:
		var progress := clampf(float(Time.get_ticks_usec() - started) / (BATTLE_FADE * 1000000.0), 0.0, 1.0)
		_cover.modulate.a = lerpf(initial_alpha, alpha, progress)
		player.volume_linear = lerpf(initial_gain, gain, progress)
		if progress >= 1.0:
			break
		await get_tree().process_frame

func _exit_tree() -> void:
	_cancel_fade()
	if is_instance_valid(music):
		music.stop()
