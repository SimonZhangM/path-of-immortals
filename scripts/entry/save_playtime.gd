extends Node
const Metadata = preload("res://scripts/entry/save_metadata.gd")
const Slots = preload("res://scripts/entry/save_slot_policy.gd")
const Checkpoints = preload("res://scripts/entry/save_checkpoints.gd")
const Schedule = preload("res://scripts/entry/save_checkpoint_schedule.gd")
const Settings = preload("res://scripts/settings/game_settings.gd")
var elapsed := 0.0
var schedule := Schedule.new()
var session_started := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_settings.call_deferred()

func _connect_settings() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings!=null and not settings.settings_changed.is_connected(_sync_preferences):
		settings.settings_changed.connect(_sync_preferences)
	_sync_preferences()

func _sync_preferences() -> void:
	schedule.configure_preferences(bool(Settings.value("auto_save",true)),float(Settings.value("auto_save_minutes",10))*60.0)
	Checkpoints.sync_preferences()

func _process(delta: float) -> void:
	if Metadata.active_path.is_empty():
		elapsed = 0.0
		schedule = Schedule.new()
		session_started = -1
		Checkpoints.pending_quick.clear()
		return
	if session_started!=Metadata.started_ms:
		schedule = Schedule.new()
		session_started = Metadata.started_ms
		Checkpoints.pending_quick.clear()
	_sync_preferences()
	var scene := get_tree().current_scene
	var paused := get_tree().paused
	if scene!=null and scene.has_method("is_system_menu_open"):
		paused = paused or scene.is_system_menu_open() or scene.is_save_browser_open()
	var safe: bool = scene!=null and scene.has_method("can_save_timed_checkpoint") and scene.can_save_timed_checkpoint()
	Checkpoints.retry_pending(0.0 if paused else delta,Metadata.active_path,safe and not paused)
	if Slots.is_working(Metadata.active_path) and schedule.advance(delta,paused,safe):
		var checkpoint_error: String = Checkpoints.write(scene.loadout,scene.inventory_save_path,"auto","timer")
		schedule.complete(checkpoint_error.is_empty())
		if not checkpoint_error.is_empty(): push_warning(checkpoint_error)
	elapsed += delta
	if elapsed >= 30.0:
		elapsed = 0.0
		var error := Metadata.flush()
		if error != OK: push_warning("游戏时长暂未保存："+error_string(error))

func _exit_tree() -> void:
	Metadata.stop()
