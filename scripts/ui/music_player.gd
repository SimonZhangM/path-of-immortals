class_name MusicPlayer
extends AudioStreamPlayer
## Keep routing pauses independent from silence on the Music/Master buses.

const TRACK_END_FADE_SECONDS := 1.0
var context_paused := false
var _track_end_gain := 1.0
# Transitions control this gain. The natural track tail multiplies it separately.
var music_gain := 1.0:
	set(value):
		music_gain = maxf(value, 0.0)
		_apply_music_gain()

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_playback(from_position: float = 0.0) -> void:
	_track_end_gain = 1.0
	_apply_music_gain()
	play(from_position)
	refresh_pause()
	_refresh_track_end_gain()

func set_context_paused(value: bool) -> void:
	context_paused = value
	refresh_pause()
	_refresh_track_end_gain()

func _refresh_track_end_gain() -> void:
	if not playing or stream == null or stream_paused: return
	var length := stream.get_length()
	if length <= 0.0: return
	var seconds_left := maxf(length - get_playback_position(), 0.0) / pitch_scale
	var fade_duration := minf(TRACK_END_FADE_SECONDS, length / pitch_scale)
	_track_end_gain = clampf(seconds_left / fade_duration, 0.0, 1.0)
	_apply_music_gain()

func _apply_music_gain() -> void:
	volume_linear = music_gain * _track_end_gain

func _process(_delta: float) -> void:
	# AudioServer has no mute/volume change signal. This also sees external bus
	# changes while the scene tree is paused by background focus handling.
	refresh_pause()
	_refresh_track_end_gain()

func refresh_pause() -> void:
	var muted := false
	for bus_name: String in ["Master", bus]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0 and (AudioServer.is_bus_mute(index) or AudioServer.get_bus_volume_linear(index) <= 0.0):
			muted = true
			break
	stream_paused = context_paused or muted
