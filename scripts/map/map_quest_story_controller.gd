extends Node
## Reuses the map dialogue/reward views and modal gate; no second dialogue UI.
var map: Control
var model: GDScript = preload("res://scripts/quests/quest_story.gd")
var waiting_idle := false
var retry_begin := ""
var signs: RefCounted

func _ready() -> void:
	map.startup_error = model.configuration_error()
	if not map.startup_error.is_empty():
		set_process(false)
		return
	var registry := MapEventRegistry.new()
	for scene: String in model.data.scenes:
		var event: Dictionary = model.event(scene)
		registry.events[event.id] = event
	map.startup_error = map.dialogue.prepare(registry)
	if not map.startup_error.is_empty():
		set_process(false)
		return
	if model==QuestStory:
		signs = preload("res://scripts/map/map_quest_signs.gd").new()
		signs.configure(map.content.get_node("Points"), map.sign_motion)
	map.loadout.changed.connect(refresh_signs)
	refresh_signs()

func refresh_signs() -> void:
	if signs==null: return
	var points: Array[String] = []
	if map.definition.id==model.data.shop.map_id and model.actionable_shop(map.loadout):
		points.append(model.data.shop.point_id)
	signs.show_at(points)

func _process(_delta: float) -> void:
	# Staged loading disables this node until the loading cover has disappeared.
	if not map._location_active or MapPresentation.transitioning or not map.is_visible_in_tree(): return
	if not map.startup_error.is_empty() or map.event_state.is_active(): return
	set_process(false)
	var saved: Dictionary = model.story(map.loadout)
	if model==QuestStory and saved.wake_pending and map.definition.id==model.data.home.map_id and map.travel.current_node_id==model.data.home.point_id:
		waiting_idle = true
		occupy("wake","quest_idle")
		map.travel.stop_at_current_node()
		map.travel.paused = true
		map.player.stop()
		map.player.play("idle")
		map.player.set_frame_and_progress(0,0.0)
		map.player.animation_looped.connect(_idle_finished,CONNECT_ONE_SHOT)
	else:
		try_arrival(map.travel.current_node_id)

func _idle_finished() -> void:
	if not waiting_idle: return
	waiting_idle = false
	begin("wake")

func owns_dialogue() -> bool:
	return map.event_state.active_id.begins_with(model.PREFIX)

func occupy(scene: String, phase := "dialogue") -> void:
	map.event_state.active_id = model.PREFIX+scene
	map.event_state._active_snapshot = model.event(scene)
	map.event_state.phase = phase
	map.travel.paused = true
	map._end_drag()
	map._clear_hover()

func try_arrival(point_id: String, clicked := false) -> bool:
	if map.event_state.is_active(): return owns_dialogue()
	var scene: String = HerbQuest.interaction(map.loadout,map.definition.id,point_id) if clicked and model==HerbQuest else model.arrival(map.loadout,map.definition.id,point_id)
	if scene.is_empty(): return false
	begin(scene)
	return true

func begin(scene: String) -> void:
	occupy(scene)
	var error: String = model.command(map.loadout,map.inventory_save_path,"begin",scene)
	retry_begin = scene if not error.is_empty() else ""
	if not error.is_empty():
		var event: Dictionary = model.event(scene)
		map.dialogue.present(event,event.lines[0]+"\n"+error,event.line_speakers[0])
		return
	present()

func advance() -> void:
	if waiting_idle: return
	if not retry_begin.is_empty():
		begin(retry_begin)
		return
	var previous: String = model.story(map.loadout).active
	var error: String = model.command(map.loadout,map.inventory_save_path,"advance")
	if not error.is_empty():
		map.dialogue.set_line_text(str(model.event(previous).lines[model.story(map.loadout).line])+"\n"+error,false)
		return
	if model.story(map.loadout).active.is_empty(): finish()
	else: present()

func present() -> void:
	var saved: Dictionary = model.story(map.loadout)
	if saved.active.is_empty(): return
	occupy(saved.active,"reward" if saved.reward_pending else "dialogue")
	map.event_state.line_index = int(saved.line)
	map._saved_loadout_revision = map.loadout.revision
	if saved.reward_pending:
		map._ensure_event_views()
		map.dialogue.dismiss()
		var record: Dictionary = model.reward_record(map.loadout)
		map.reward_dialog.present(record,"灵石")
	else:
		var event: Dictionary = model.event(saved.active)
		map.dialogue.present(event,DialogueJournal.render_text(event.lines[saved.line],map.loadout.narrative),event.line_speakers[saved.line],"dialogue",int(saved.line))

func accept_reward() -> void:
	if not model.story(map.loadout).reward_pending or map.reward_dialog.accept_button.disabled: return
	map.reward_dialog.accept_button.disabled = true
	var error: String = model.command(map.loadout,map.inventory_save_path,"accept")
	if not error.is_empty():
		map.reward_dialog.error_label.text = error
		map.reward_dialog.accept_button.disabled = false
		return
	map.reward_dialog.pick_sound.play()
	map.reward_dialog.hide()
	finish()

func finish() -> void:
	map.dialogue.dismiss()
	map.event_state.active_id = ""
	map.event_state.phase = ""
	map.event_state.line_index = 0
	map.event_state._active_snapshot = {}
	map.travel.paused = false
	map._saved_loadout_revision = map.loadout.revision
	refresh_signs()
	# Arrival may contain the area intro followed by its first herb observation.
	try_arrival(map.travel.current_node_id)

func after_gathering() -> void:
	var pending: Array = QuestStory.story(map.loadout).pending
	if not pending.is_empty(): begin(pending[0])
