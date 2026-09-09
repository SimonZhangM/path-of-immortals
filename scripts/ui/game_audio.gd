class_name GameAudio
extends Node

signal sound_played(kind: String)

const STREAMS := {
	"pick": preload("res://assets/gameplay-bag-pick.ogg"),
	"place": preload("res://assets/gameplay-bag-place.ogg"),
	"invalid": preload("res://assets/gameplay-bag-invalid.ogg"),
	"hit": preload("res://assets/sword_slashing.ogg")
}
var players: Dictionary = {}
var music: AudioStreamPlayer

func configure(manager: GameManager) -> void:
	for kind in STREAMS:
		var player := AudioStreamPlayer.new()
		player.stream = STREAMS[kind]
		player.volume_db = -8 if kind == "hit" else -4
		player.max_polyphony = 8 if kind == "hit" else 3
		add_child(player)
		players[kind] = player
	var click := AudioStreamPlayer.new()
	click.stream = _make_click()
	click.volume_db = -4
	click.max_polyphony = 3
	add_child(click)
	players["click"] = click
	manager.inventory_interaction.connect(play)
	music = AudioStreamPlayer.new()
	music.name = "BattleMusic"
	var track := preload("res://assets/battle.mp3").duplicate() as AudioStreamMP3
	track.loop = true
	track.loop_offset = 0.0
	music.stream = track
	music.volume_db = -6
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	music.play()

func play(kind: String) -> void:
	if players.has(kind):
		players[kind].play()
		sound_played.emit(kind)

static func _make_click() -> AudioStreamWAV:
	# A short, soft two-tone tap. Synthesized once; independent of simulation.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	var frames := 3528
	var samples := PackedByteArray()
	samples.resize(frames * 2)
	for index in frames:
		var time := float(index) / stream.mix_rate
		var envelope := minf(time / 0.002, 1.0) * exp(-time * 75.0) * (1.0 - float(index) / frames)
		var value := (sin(TAU * 1150 * time) + 0.35 * sin(TAU * 1870 * time)) * envelope * 0.24
		samples.encode_s16(index * 2, int(value * 32767))
	stream.data = samples
	return stream

func stop_all() -> void:
	if is_instance_valid(music):
		music.stop()
	for player in players.values():
		player.stop()

func _exit_tree() -> void:
	stop_all()
