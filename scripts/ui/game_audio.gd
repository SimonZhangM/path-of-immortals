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
var music: AudioStreamPlayer
var _victory_started := false

func configure(manager: GameManager, defer_music: bool = false) -> void:
	for kind in STREAMS:
		var player := AudioStreamPlayer.new()
		player.stream = STREAMS[kind]
		player.volume_db = -8 if kind in ["hit", "pierce", "throwable", "blunt", "magic", "restore"] else -4
		player.max_polyphony = 8 if kind in ["hit", "pierce", "throwable", "blunt", "magic", "restore"] else 3
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
