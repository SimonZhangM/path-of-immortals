extends Node
## Sounds only: no battle effects or simulation commands are created here.
const WEAPON_VOLUME_SCALE := 0.8
var session: RefCounted
var view: CanvasItem
var registry: ContentRegistry
var audio: GameAudio
var sound_volumes: Dictionary = {}
var music: MusicPlayer
var map_music_snapshot: Dictionary = {}
var music_focused := false
var adjusting := false
var music_started := false
var result_transition := false

func set_result_transition(value: bool) -> void:
	result_transition=value
	_sync()

func set_adjusting(value: bool) -> void:
	adjusting=value
	_sync()

func configure(value: RefCounted, screen: CanvasItem, content: ContentRegistry) -> void:
	session=value; view=screen; registry=content
	audio=GameAudio.new()
	add_child(audio)
	audio.configure_effects()
	for sound: String in audio.players:
		sound_volumes[sound]=audio.players[sound].volume_linear
	music=MusicPlayer.new()
	music.name="BreakthroughMusic"
	music.bus="Music"
	music.music_gain=db_to_linear(-6.0)
	music.process_mode=Node.PROCESS_MODE_ALWAYS
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/breakthrough_layout.json"))
	var track := load(str(config.music)).duplicate() as AudioStreamMP3
	track.loop=true
	track.loop_offset=0.0
	music.stream=track
	add_child(music)
	if session.runtime!=null:
		session.runtime.presentation_events.connect(present)
	session.changed.connect(_sync)
	view.visibility_changed.connect(_sync)
	_sync()

func _sync() -> void:
	if session.phase!="running" or not view.is_visible_in_tree(): audio.stop_all()
	# A restored paused attempt is not an instruction to start its music.
	if not session.started and not result_transition: music_started=false
	elif session.phase in ["running","succeeded"]: music_started=true
	var active: bool=music_started and (session.started or result_transition) and (view.is_visible_in_tree() or (adjusting and view.get_parent().is_visible_in_tree()))
	if active and not music_focused:
		map_music_snapshot=MapPresentation.suspend_for_overlay()
		music_focused=true
		music.set_context_paused(false)
		if not music.playing: music.start_playback()
	elif not active:
		_release_music()
		if not session.started and not result_transition: music.stop(); music.set_context_paused(false)

func _release_music() -> void:
	if not music_focused: return
	music.set_context_paused(true)
	music_focused=false
	MapPresentation.resume_from_overlay(map_music_snapshot)
	map_music_snapshot.clear()

func _exit_tree() -> void:
	_release_music()
	if is_instance_valid(music): music.stop()

func present(events: Array[Dictionary]) -> void:
	if session.phase!="running" or not view.is_visible_in_tree(): return
	var sounded := {}
	for event: Dictionary in events:
		var kind := str(event.get("kind",""))
		var sound := ""
		if kind=="restore" and float(event.get("value",0))>0: sound="restore"
		elif kind=="damage": sound=GameAudio.impact_kind(event,registry)
		elif kind=="training_activated": sound="magic"
		if sound.is_empty(): continue
		# Match battle deduplication for multi-packet hits and resource restoration.
		var key := "%s:%s:%s:%s:%s" % ["restore" if kind=="restore" else "impact",event.get("at_usec",0),event.get("owner_id",""),event.get("instance_id",event.get("item_id","")),event.get("target_id","")]
		if sounded.has(key): continue
		sounded[key]=true
		var item := registry.get_item(str(event.get("item_id","")))
		var weapon_sound := kind=="damage" and item!=null and item.category in ["weapon","throwable"]
		var player: AudioStreamPlayer=audio.players[sound]
		player.volume_linear=float(sound_volumes[sound])*(WEAPON_VOLUME_SCALE if weapon_sound else 1.0)
		audio.play(sound)
