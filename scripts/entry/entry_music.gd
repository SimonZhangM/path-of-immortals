extends AudioStreamPlayer
## One player for the entire pre-game flow, independent of individual pages.
const NODE_NAME := "EntryMusic"
const CONFIG := "res://data/ui/start_menu.json"
var _fade: Tween

static func ensure_for(tree: SceneTree) -> AudioStreamPlayer:
	var existing := tree.root.get_node_or_null(NODE_NAME)
	if existing != null: return existing
	var player = load("res://scripts/entry/entry_music.gd").new()
	player.name = NODE_NAME
	tree.root.add_child(player)
	return player

static func finish_for(tree: SceneTree, seconds: float) -> void:
	var player := tree.root.get_node_or_null(NODE_NAME)
	if player != null: player.fade_out(seconds)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)).music
	var track := load(config.stream).duplicate() as AudioStreamMP3
	track.loop = true
	stream = track
	volume_db = float(config.volume_db)
	play()

func fade_out(seconds: float) -> void:
	if _fade != null and _fade.is_valid(): _fade.kill()
	if seconds <= 0.0:
		stop()
		queue_free()
		return
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(self, "volume_linear", 0.0, seconds)
	_fade.tween_callback(stop)
	_fade.tween_callback(queue_free)
