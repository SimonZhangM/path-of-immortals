extends Node
## Adapter for the existing map modal, dialogue and reward views.
var map: Control
var signs: RefCounted
var choices: HBoxContainer
var retry_begin := ""
var _gate_signature := ""
var _claiming := false
var _claim_scheduled := false
var completion_notice: Control

func _ready() -> void:
	map.startup_error = RiverQuest.configuration_error()
	if not map.startup_error.is_empty(): return
	var registry := MapEventRegistry.new()
	for id: String in RiverQuest.data.scenes:
		var event := RiverQuest.event(id)
		registry.events[event.id] = event
	map.startup_error = map.dialogue.prepare(registry)
	signs = preload("res://scripts/map/map_quest_signs.gd").new()
	signs.configure(map.content.get_node("Points"), map.sign_motion)
	choices = HBoxContainer.new()
	choices.name = "RiverStoryChoices"
	choices.z_index = 45
	choices.add_theme_constant_override("separation",20)
	choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(choices)
	choices.hide()
	map.resized.connect(_layout_choices)
	map.loadout.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var gates := RiverQuest.gates(map.loadout,map.definition.id)
	# Merge gates before publishing them so independent quest adapters cannot overwrite each other.
	if map.definition.id==FishingNetQuest.data.reef.map_id and not FishingNetQuest.route_open(map.loadout):
		gates.routes[FishingNetQuest.data.route_id] = true
		gates.points[FishingNetQuest.data.reef.point_id] = true
	var signature := JSON.stringify(gates)
	if signature!=_gate_signature:
		_gate_signature = signature
		map.travel.blocked_routes = gates.routes
		map.travel.hidden_points = gates.points
		map._exploration_presented = false
		if map.exploration!=null: map._visit_exploration(map.travel.current_node_id)
	var points: Array[String] = []
	var optional_points: Array[String] = []
	if map.definition.id==RiverQuest.RIVER and RiverQuest.enabled(map.loadout):
		if not RiverQuest.done(map.loadout,"injured") or RiverQuest.allowed(map.loadout,"medicine") or RiverQuest.allowed(map.loadout,"return_jade") or RiverQuest.allowed(map.loadout,"pickup"):
			points.append(RiverQuest.data.scenes.injured.point_id)
	elif map.definition.id==RiverQuest.TOWN:
		for id in ["invite_doctor","clinic_arrival","gift_book","gift_board","closing"]:
			if RiverQuest.allowed(map.loadout,id): points.append(RiverQuest.data.scenes[id].point_id)
	elif map.definition.id==RiverQuest.SHRINE:
		for id in ["root_discovery","mirror","fox_notice","array","wood_door","stone_door"]:
			var scene: Dictionary = RiverQuest.data.scenes[id]
			if scene.get("optional",false): optional_points.append(scene.point_id)
			if RiverQuest.allowed(map.loadout,id): points.append(scene.point_id)
		if RiverQuest.done(map.loadout,"fox_notice") and not RiverQuest.done(map.loadout,"fox_rescue"): points.append(RiverQuest.data.scenes.fox_notice.point_id)
	if map.definition.id==RiverQuest.TOWN and points.is_empty() and HerbQuest.has_clinic_marker(map.loadout):
		points.append(HerbQuest.data.clinic.point_id)
		optional_points.append(HerbQuest.data.clinic.point_id)
	signs.show_at(points,optional_points)
	if not _claiming and not _claim_scheduled and not RiverQuest.story(map.loadout).parcels.is_empty():
		_claim_scheduled = true
		_claim_parcels.call_deferred()

func _claim_parcels() -> void:
	_claim_scheduled = false
	if not map._location_active or not map.is_visible_in_tree(): return
	_claiming = true
	var error := RiverQuest.command(map.loadout,map.inventory_save_path,"claim_parcels")
	_claiming = false
	if not error.is_empty(): push_warning(error)
	if not map.event_state.is_active(): set_process(true)

func _process(_delta: float) -> void:
	if not map._location_active or MapPresentation.transitioning or not map.is_visible_in_tree() or not map.startup_error.is_empty(): return
	if map.event_state.is_active(): return
	if map.is_breakthrough_open() or map.is_inventory_open() or map.is_task_open() or map.is_technique_open() or map.is_world_map_open() or map.is_system_menu_open() or map.is_save_browser_open() or map.is_exit_open(): return
	set_process(false)
	if not RiverQuest.story(map.loadout).parcels.is_empty(): _claim_parcels()
	try_arrival(map.travel.current_node_id)

func owns_dialogue() -> bool:
	return map.event_state.active_id.begins_with(RiverQuest.PREFIX)

func try_arrival(point: String, manual := false) -> bool:
	if map.event_state.is_active(): return owns_dialogue()
	if RiverQuest.training_notice_pending(map.loadout):
		_show_completion_notice()
		return true
	var scene := RiverQuest.arrival(map.loadout,map.definition.id,point,manual)
	if scene.is_empty(): return false
	begin(scene)
	return true

func try_exit(point: String) -> bool:
	if not RiverQuest.exit_blocked(map.loadout,map.definition.id): return false
	if point!=RiverQuest.data.scenes.blocked_exit.point_id: return false
	var scene := RiverQuest.arrival(map.loadout,map.definition.id,point)
	begin("blocked_exit" if scene.is_empty() else scene)
	return true

func occupy(scene: String) -> void:
	map.event_state.active_id = RiverQuest.PREFIX+scene
	map.event_state._active_snapshot = RiverQuest.event(scene)
	map.event_state.phase = "dialogue"
	map.travel.paused = true
	map._end_drag()
	map._clear_hover()

func begin(scene: String) -> void:
	occupy(scene)
	var error := RiverQuest.command(map.loadout,map.inventory_save_path,"begin",scene)
	retry_begin = scene if not error.is_empty() else ""
	if not error.is_empty():
		var event := RiverQuest.event(scene)
		map.dialogue.present(event,event.lines[0]+"\n"+error,event.line_speakers[0])
		return
	present()

func advance() -> void:
	if is_instance_valid(completion_notice) and completion_notice.visible: return
	if not retry_begin.is_empty():
		begin(retry_begin)
		return
	var saved := RiverQuest.story(map.loadout)
	if saved.active.is_empty() or RiverQuest.data.scenes[saved.active].has("choices"): return
	var previous: String = saved.active
	var error := RiverQuest.command(map.loadout,map.inventory_save_path,"advance")
	if not error.is_empty():
		if RiverQuest.picture_page(saved)>=0:
			var event := RiverQuest.event(previous)
			map.dialogue.present(event,error,event.line_speakers[saved.line],"dialogue_paused",int(saved.line))
		else:
			map.dialogue.set_line_text(str(RiverQuest.event(previous).lines[saved.line])+"\n"+error,false)
		return
	if RiverQuest.story(map.loadout).active.is_empty(): finish(previous)
	else: present()

func present() -> void:
	if RiverQuest.training_notice_pending(map.loadout):
		_show_completion_notice()
		return
	var saved := RiverQuest.story(map.loadout)
	if saved.active.is_empty(): return
	occupy(saved.active)
	choices.hide()
	map.event_state.line_index = int(saved.line)
	map._saved_loadout_revision = map.loadout.revision
	var event := RiverQuest.event(saved.active)
	if saved.reward_pending:
		map.event_state.phase = "reward"
		map._ensure_event_views()
		if event.has("handover"):
			map.dialogue.dismiss()
		else:
			map.dialogue.present(event,DialogueJournal.render_text(event.lines[saved.line],map.loadout.narrative),event.line_speakers[saved.line],"dialogue_paused",int(saved.line))
			map.dialogue.playback.finish_reveal()
			map.dialogue.next_marker.hide()
		var transfer: Dictionary = event.get("handover",event.get("reward",{}))
		var record: Dictionary = map.loadout.records[transfer.item_id].duplicate(true)
		record.quantity = transfer.quantity
		map.reward_dialog.present(record,record.name,event.has("handover"),event.has("handover"))
		map.reward_dialog.card.loadout = map.loadout
		map.reward_dialog.card.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		map.dialogue.present(event,DialogueJournal.render_text(event.lines[saved.line],map.loadout.narrative),event.line_speakers[saved.line],"illustration" if RiverQuest.picture_page(saved)>=0 else "dialogue",int(saved.line))
		if event.has("choices"):
			_show_choices(event.choices,choose)
			map.dialogue.next_marker.hide()

func choose(id: String) -> void:
	var error := RiverQuest.command(map.loadout,map.inventory_save_path,"choose",id)
	if not error.is_empty():
		map.dialogue.set_line_text(error,false)
		return
	present()

func accept_reward() -> void:
	var saved := RiverQuest.story(map.loadout)
	if not saved.reward_pending or map.reward_dialog.accept_button.disabled: return
	var previous: String = saved.active
	map.reward_dialog.accept_button.disabled = true
	var error := RiverQuest.command(map.loadout,map.inventory_save_path,"accept")
	if not error.is_empty():
		map.reward_dialog.error_label.text = error
		map.reward_dialog.accept_button.disabled = false
		# Reservation is explicit and persistent; a full bag cannot trap the story.
		if not RiverQuest.data.scenes[previous].has("handover") and error.begins_with("储物袋容量不足"):
			_show_choices([{"id":"reserve","text":"先包好，空位够时收入行囊"}],reserve_reward)
		return
	map.reward_dialog.pick_sound.play()
	map.reward_dialog.hide()
	if RiverQuest.story(map.loadout).active.is_empty(): finish(previous)
	else: present()

func reserve_reward(_id: String) -> void:
	var previous: String = RiverQuest.story(map.loadout).active
	var error := RiverQuest.command(map.loadout,map.inventory_save_path,"reserve")
	if not error.is_empty():
		map.reward_dialog.error_label.text = error
		return
	map.reward_dialog.hide()
	if RiverQuest.story(map.loadout).active.is_empty(): finish(previous)
	else: present()

func _show_choices(entries: Array, callback: Callable) -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	for entry: Dictionary in entries:
		var button := Button.new()
		button.text = entry.text
		button.custom_minimum_size = Vector2(240,93)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_override("font",load("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf"))
		button.add_theme_font_size_override("font_size",24)
		for style_name in ["normal","hover","pressed","focus"]:
			var style := StyleBoxTexture.new()
			style.texture = load("res://assets/UI-game-choicebutton.webp")
			if style_name == "hover": style.modulate_color = Color(1.15,1.15,1.15)
			if style_name == "pressed": style.modulate_color = Color(0.85,0.85,0.85)
			style.content_margin_left = 24
			style.content_margin_right = 24
			style.content_margin_top = 0
			style.content_margin_bottom = 0
			button.add_theme_stylebox_override(style_name,style)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func(): callback.call(entry.id))
		choices.add_child(button)
	var button_size := Vector2(240,93)
	for button: Button in choices.get_children():
		button_size = button_size.max(button.get_combined_minimum_size())
	for button: Button in choices.get_children():
		button.custom_minimum_size = button_size
	choices.show()
	_layout_choices.call_deferred()

func _layout_choices() -> void:
	if choices==null: return
	var factor: float = minf(map.size.x/1920.0,map.size.y/1080.0)
	choices.scale = Vector2.ONE*factor
	choices.size = choices.get_combined_minimum_size()
	var top: float = map.dialogue.background.position.y-(choices.size.y+20)*factor
	if map.event_state.phase=="reward": top = map.size.y*0.73
	choices.position = Vector2((map.size.x-choices.size.x*factor)*0.5,maxf(100*factor,top))

func finish(previous: String) -> void:
	map.dialogue.dismiss()
	choices.hide()
	map.event_state.active_id = ""
	map.event_state.phase = ""
	map.event_state.line_index = 0
	map.event_state._active_snapshot = {}
	map.travel.paused = false
	map._saved_loadout_revision = map.loadout.revision
	refresh()
	if RiverQuest.training_notice_pending(map.loadout):
		_show_completion_notice()
		return
	if previous=="beasts_gone":
		map.travel.stop_at_current_node()
		map._try_open_exit(map.travel.current_node_id)
		return
	# Dismissed optional visits and blocked exits never reopen in a tight loop.
	if previous in ["fox_leave","blocked_exit","medicine_missing","jade_missing","doctor_away","bringing_back"] or previous.ends_with("_again"): return
	if try_arrival(map.travel.current_node_id): return
	if map.travel.hidden_points.has(map.travel.current_node_id): return
	# A story on an encounter node must not consume the ordinary encounter.
	if map.event_state.try_start(map.travel.current_node_id,map.travel.current_node_id,true,"arrival"):
		map.travel.paused = true
		map._present_event_progress()

func _show_completion_notice() -> void:
	if completion_notice==null:
		# Load on demand to avoid a static UI/quest script dependency cycle.
		completion_notice = load("res://scripts/map/map_exit_dialog.gd").new()
		completion_notice.name = "RiverTrainingNotice"
		completion_notice.z_index = 100
		map.add_child(completion_notice)
		completion_notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		completion_notice.confirmed.connect(_confirm_completion_notice)
	map.dialogue.dismiss()
	choices.hide()
	map.event_state.active_id = RiverQuest.PREFIX+"training_notice"
	map.event_state.phase = "notice"
	map.travel.paused = true
	map._end_drag()
	map._clear_hover()
	completion_notice.present_notice(RiverQuest.data.training_notice)

func _confirm_completion_notice() -> void:
	if not is_instance_valid(completion_notice) or not completion_notice.visible: return
	var error := RiverQuest.command(map.loadout,map.inventory_save_path,"acknowledge_training_notice")
	if not error.is_empty():
		completion_notice.error_label.text = error
		return
	completion_notice.hide()
	if RiverQuest.story(map.loadout).active.is_empty(): finish("")
	else: present()

func handle_notice_input(event: InputEvent) -> bool:
	return is_instance_valid(completion_notice) and completion_notice.handle_confirmation_input(event)
