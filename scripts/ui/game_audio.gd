class_name GameAudio
extends Node

signal sound_played(kind: String)

const STREAMS := {
	"click": preload("res://assets/click.ogg"),
	"pick": preload("res://assets/gameplay-bag-pick.ogg"),
	"place": preload("res://assets/gameplay-bag-place.ogg"),
	"invalid": preload("res://assets/gameplay-bag-invalid.ogg"),
	"hit": preload("res://assets/sword_slashing.ogg"),
	"pierce": preload("res://assets/sfx-chuanci.wav"),
	"throwable": preload("res://assets/sfx-anqi.wav"),
	"blunt": preload("res://assets/sfx-dunji.ogg"),
	"magic": preload("res://assets/sfx-magic.ogg"),
	"restore": preload("res://assets/sfx-restore.ogg")
}
var players: Dictionary = {}
var music: MusicPlayer
var _victory_started := false
var _battle_track: AudioStreamMP3

func configure(manager: GameManager, defer_music: bool = false, source_map_id: String = "") -> void:
	configure_effects()
	var tracks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/battle_music.json"))
	_battle_track = load(tracks.maps.get(source_map_id, tracks.default)) as AudioStreamMP3
	manager.inventory_interaction.connect(play)
	music = MusicPlayer.new()
	music.bus = "Music"
	music.name = "BattleMusic"
	music.music_gain = db_to_linear(-6.0)
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	manager.battle_restarted.connect(start_music)
	if not defer_music:
		start_music()

func configure_effects() -> void:
	if not players.is_empty(): return
	preload("res://scripts/settings/game_settings.gd").ensure_audio_buses()
	for kind in STREAMS:
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		player.stream = STREAMS[kind]
		player.volume_db = -8 if kind in ["hit", "pierce", "throwable", "blunt", "magic", "restore"] else -4
		player.max_polyphony = 8 if kind in ["hit", "pierce", "throwable", "blunt", "magic", "restore"] else 3
		add_child(player)
		players[kind] = player

func start_music() -> void:
	_victory_started = false
	var track := _battle_track.duplicate() as AudioStreamMP3
	track.loop = true
	track.loop_offset = 0.0
	music.stream = track
	music.music_gain = db_to_linear(-6.0)
	music.start_playback()

func play_victory() -> void:
	if _victory_started: return
	_victory_started = true
	music.stop()
	var track := preload("res://assets/victory-song2.mp3").duplicate() as AudioStreamMP3
	track.loop = false
	music.stream = track
	music.music_gain = db_to_linear(-6.0)
	music.start_playback()

func play(kind: String) -> void:
	if players.has(kind):
		players[kind].play()
		sound_played.emit(kind)

static func impact_kind(event: Dictionary, registry: ContentRegistry) -> String:
	var item := registry.get_item(event.get("item_id", ""))
	if item != null and item.category == "throwable": return "throwable"
	if item != null and item.category == "spell": return "magic"
	var damage_type: String = event.get("damage_type", "")
	# Attached elemental packets may precede the physical packet of the same hit.
	if item != null and item.category == "weapon":
		for effect: Dictionary in item.effects_for("on_activate"):
			if effect.effect == "damage":
				damage_type = effect.get("damage_type", damage_type)
				break
	return {"穿刺": "pierce", "钝击": "blunt", "法术型": "magic"}.get(damage_type, "hit")

func stop_all() -> void:
	if is_instance_valid(music):
		music.stop()
	for player in players.values():
		player.stop()

func _exit_tree() -> void:
	stop_all()
