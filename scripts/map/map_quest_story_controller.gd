extends Node
## Reuses the map dialogue/reward views and modal gate; no second dialogue UI.
var map: Control
var model: GDScript = preload("res://scripts/quests/quest_story.gd")
var waiting_idle := false
var retry_begin := ""
var signs: RefCounted
var defer_receipt_button: Button

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
	if model in [QuestStory,FishingNetQuest,MerchantRoadQuest]:
		signs = preload("res://scripts/map/map_quest_signs.gd").new()
		signs.configure(map.content.get_node("Points"), map.sign_motion)
	map.loadout.changed.connect(refresh_signs)
	refresh_signs()

func refresh_signs() -> void:
	if signs==null: return
	var points: Array[String] = []
	if model==MerchantRoadQuest:
		for location: Dictionary in [MerchantRoadQuest.data.road,MerchantRoadQuest.data.shop]:
			if map.definition.id==location.map_id and not MerchantRoadQuest.arrival(map.loadout,location.map_id,location.point_id).is_empty(): points.append(location.point_id)
		signs.show_task_at(points,"side")
		return
	if model==FishingNetQuest:
		if map.definition.id==FishingNetQuest.data.dock.map_id:
			for location: Dictionary in [FishingNetQuest.data.dock,FishingNetQuest.data.reef]:
				if not FishingNetQuest.arrival(map.loadout,location.map_id,location.point_id).is_empty(): points.append(location.point_id)
		signs.show_task_at(points,"side")
		return
	if map.definition.id==model.data.shop.map_id and (model.actionable_shop(map.loadout) or HomecomingQuest.available(map.loadout)):
		points.append(model.data.shop.point_id)
	if map.definition.id==HomecomingQuest.data.home.map_id and (HomecomingQuest.guidance_available(map.loadout) or HomecomingQuest.preparation_available(map.loadout) or HomecomingQuest.rejoice_available(map.loadout)):
		points.append(HomecomingQuest.data.home.point_id)
	signs.show_task_at(points,"main")

func _process(_delta: float) -> void:
	# Staged loading disables this node until the loading cover has disappeared.
	if not map._location_active or MapPresentation.transitioning or not map.is_visible_in_tree(): return
	if not map.startup_error.is_empty() or map.event_state.is_active(): return
	if map.is_breakthrough_open() or map.is_inventory_open() or map.is_task_open() or map.is_technique_open() or map.is_world_map_open() or map.is_system_menu_open() or map.is_save_browser_open() or map.is_exit_open(): return
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
	var scene: String = model.interaction(map.loadout,map.definition.id,point_id) if clicked and model in [HerbQuest,HomecomingQuest,FishingNetQuest] else model.arrival(map.loadout,map.definition.id,point_id)
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
		var record: Dictionary = model.reward_record(map.loadout)
		if model in [HomecomingQuest,FishingNetQuest]:
			var event: Dictionary = model.event(saved.active)
			map.dialogue.present(event,DialogueJournal.render_text(event.lines[saved.line],map.loadout.narrative),event.line_speakers[saved.line],"dialogue_paused",int(saved.line))
			var handover: bool = model==FishingNetQuest and FishingNetQuest.handing_over(map.loadout)
			map.reward_dialog.present(record,"任务物品",handover,false,not handover)
			map.reward_dialog.card.loadout = map.loadout
			map.reward_dialog.card.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			map.dialogue.dismiss()
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
		if model==FishingNetQuest and model.story(map.loadout).active=="retrieve" and error.begins_with("储物袋容量不足"):
			_offer_receipt_deferral()
		return
	map.reward_dialog.pick_sound.play()
	map.reward_dialog.hide()
	if model.story(map.loadout).active.is_empty(): finish()
	else: present()

func finish() -> void:
	if is_instance_valid(defer_receipt_button): defer_receipt_button.hide()
	map.dialogue.dismiss()
	map.event_state.active_id = ""
	map.event_state.phase = ""
	map.event_state.line_index = 0
	map.event_state._active_snapshot = {}
	map.travel.paused = false
	map._saved_loadout_revision = map.loadout.revision
	refresh_signs()
	# Arrival may contain the area intro followed by its first herb observation.
	if model==QuestStory: try_arrival(map.travel.current_node_id)

func _offer_receipt_deferral() -> void:
	# Keep the persisted receipt at the reef while letting the player make bag space.
	if defer_receipt_button==null:
		defer_receipt_button = Button.new()
		defer_receipt_button.text = "先整理行囊"
		defer_receipt_button.position = Vector2(170,465)
		defer_receipt_button.size = Vector2(200,40)
		defer_receipt_button.add_theme_font_size_override("font_size",22)
		map.reward_dialog.canvas.add_child(defer_receipt_button)
		defer_receipt_button.pressed.connect(func():
			map.reward_dialog.hide()
			finish())
	defer_receipt_button.show()

func after_gathering() -> void:
	var pending: Array = QuestStory.story(map.loadout).pending
	if not pending.is_empty(): begin(pending[0])
