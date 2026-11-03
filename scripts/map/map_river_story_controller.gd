extends Node
## Adapter for the existing map modal, dialogue and reward views.
var map: Control
var signs: RefCounted
var choices: HBoxContainer
var retry_begin := ""
var _gate_signature := ""
var _claiming := false
var _claim_scheduled := false

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
		for id in ["invite_doctor","clinic_arrival","gift_book","closing"]:
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
	set_process(false)
	if not RiverQuest.story(map.loadout).parcels.is_empty(): _claim_parcels()
	try_arrival(map.travel.current_node_id)

func owns_dialogue() -> bool:
	return map.event_state.active_id.begins_with(RiverQuest.PREFIX)

func try_arrival(point: String, manual := false) -> bool:
	if map.event_state.is_active(): return owns_dialogue()
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
