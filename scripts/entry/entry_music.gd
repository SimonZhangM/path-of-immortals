extends "res://scripts/ui/music_player.gd"
## One player for the entire pre-game flow, independent of individual pages.
const NODE_NAME := "EntryMusic"
const CONFIG := "res://data/ui/start_menu.json"
static var _pending_player: AudioStreamPlayer
var _fade: Tween
var playlist: Array = []
var track_index := 0

static func ensure_for(tree: SceneTree) -> AudioStreamPlayer:
	var existing := tree.root.get_node_or_null(NODE_NAME)
	if existing != null:
		if not existing.playing: existing.start_playback()
		return existing
	if is_instance_valid(_pending_player): return _pending_player
	var player = load("res://scripts/entry/entry_music.gd").new()
	player.name = NODE_NAME
	_pending_player = player
	# The root is locked while the initial scene enters the tree.
	# Defer attachment and reuse the pending player if another page requests it.
	tree.root.add_child.call_deferred(player)
	return player

static func stop_for_loading(tree: SceneTree) -> void:
	var player := tree.root.get_node_or_null(NODE_NAME)
	if player != null: player.stop()

static func finish_for(tree: SceneTree, seconds: float) -> void:
	var player := tree.root.get_node_or_null(NODE_NAME)
	if player != null: player.fade_out(seconds)

func _ready() -> void:
	if _pending_player == self: _pending_player = null
	process_mode = Node.PROCESS_MODE_ALWAYS
	preload("res://scripts/settings/game_settings.gd").ensure_audio_buses()
	bus = "Music"
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)).music
	playlist = config.playlist.duplicate()
	finished.connect(_next_track)
	music_gain = db_to_linear(float(config.volume_db))
	_play_track()

func _play_track() -> void:
	var track := load(playlist[track_index]).duplicate() as AudioStreamMP3
	track.loop = false
	stream = track
	start_playback()

func _next_track() -> void:
	track_index = (track_index+1)%playlist.size()
	_play_track()

func fade_out(seconds: float) -> void:
	if _fade != null and _fade.is_valid(): _fade.kill()
	if seconds <= 0.0:
		stop()
		queue_free()
		return
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(self, "music_gain", 0.0, seconds)
	_fade.tween_callback(stop)
	_fade.tween_callback(queue_free)
