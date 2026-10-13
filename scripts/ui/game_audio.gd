class_name GameAudio
extends Node

signal sound_played(kind: String)

const STREAMS := {
	"click": preload("res://assets/click.ogg"),
	"pick": preload("res://assets/gameplay-bag-pick.ogg"),
	"place": preload("res://assets/gameplay-bag-place.ogg"),
	"invalid": preload("res://assets/gameplay-bag-invalid.ogg"),
	"hit": preload("res://assets/sword_slashing.ogg")
}
var players: Dictionary = {}
var music: AudioStreamPlayer
var _victory_started := false

func configure(manager: GameManager, defer_music: bool = false) -> void:
	for kind in STREAMS:
		var player := AudioStreamPlayer.new()
		player.stream = STREAMS[kind]
		player.volume_db = -8 if kind == "hit" else -4
		player.max_polyphony = 8 if kind == "hit" else 3
		add_child(player)
		players[kind] = player
	manager.inventory_interaction.connect(play)
	music = AudioStreamPlayer.new()
	music.name = "BattleMusic"
	music.volume_db = -6
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	manager.battle_restarted.connect(start_music)
	if not defer_music:
		start_music()

func start_music() -> void:
	_victory_started = false
	var track := preload("res://assets/battle.mp3").duplicate() as AudioStreamMP3
	track.loop = true
	track.loop_offset = 0.0
	music.stream = track
	music.volume_db = -6.0
	music.play()

func play_victory() -> void:
	if _victory_started: return
	_victory_started = true
	music.stop()
	var track := preload("res://assets/victory-song2.mp3").duplicate() as AudioStreamMP3
	track.loop = false
	music.stream = track
	music.volume_db = -6.0
	music.play()

func play(kind: String) -> void:
	if players.has(kind):
		players[kind].play()
		sound_played.emit(kind)

func stop_all() -> void:
	if is_instance_valid(music):
		music.stop()
	for player in players.values():
		player.stop()

func _exit_tree() -> void:
	stop_all()
