extends "res://scripts/map/map_quest_story_controller.gd"
## Task-only encounter; the authored map encounter popup is never opened here.
var choices: HBoxContainer
var fight_button: Button
var leave_button: Button

func _ready() -> void:
	super._ready()
	if not map.startup_error.is_empty(): return
	signs = preload("res://scripts/map/map_quest_signs.gd").new()
	signs.configure(map.content.get_node("Points"),map.sign_motion)
	choices = HBoxContainer.new()
	choices.z_index = 45
	choices.add_theme_constant_override("separation",20)
	choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(choices)
	fight_button = _button("驱赶藤灵","fight")
	leave_button = _button("暂且离开","leave")
	choices.hide()
	map.resized.connect(_layout_choices)
	refresh_signs()

func refresh_signs() -> void:
	if signs==null: return
	signs.show_task_at(DeerRestQuest.marker_points(map.loadout,map.definition.id),"side")
	# The ordinary rest sign was hidden before the task unlocked it. Do not
	# restore that stale visibility snapshot when removing the yellow overlay.
	var entry: Dictionary = signs.entries[DeerRestQuest.data.tree.point_id]
	if entry.original!=null:
		entry.original.visible = DeerRestQuest.story(map.loadout).stage=="completed"

func try_arrival(point_id: String, clicked := false) -> bool:
	if map.event_state.is_active(): return owns_dialogue()
	var scene := DeerRestQuest.interaction(map.loadout,map.definition.id,point_id) if clicked else DeerRestQuest.arrival(map.loadout,map.definition.id,point_id)
	if scene.is_empty(): return false
	begin(scene)
	return true

func present() -> void:
	var saved := DeerRestQuest.story(map.loadout)
	if saved.active.is_empty(): return
	var event := DeerRestQuest.event(saved.active)
	occupy(saved.active,"dialogue_paused" if saved.choice_pending else "dialogue")
	map.event_state.line_index = int(saved.line)
	map._saved_loadout_revision = map.loadout.revision
	map.dialogue.present(event,DialogueJournal.render_text(event.lines[saved.line],map.loadout.narrative),event.line_speakers[saved.line],map.event_state.phase,int(saved.line))
	choices.visible = saved.choice_pending
	fight_button.disabled = false
	leave_button.disabled = false
	if choices.visible: _layout_choices.call_deferred()

func advance() -> void:
	if DeerRestQuest.story(map.loadout).choice_pending or map.event_state.phase=="encounter": return
	super.advance()

func finish() -> void:
	choices.hide()
	super.finish()

func choose(action: String) -> void:
	if not choices.visible or fight_button.disabled: return
	var error := DeerRestQuest.command(map.loadout,map.inventory_save_path,action)
	if not error.is_empty():
		map.dialogue.set_line_text(error,false)
		return
	choices.hide()
	if action=="leave":
		present()
		return
	fight_button.disabled = true
	map.dialogue.dismiss()
	map._ensure_event_views()
	map.event_state.active_id = DeerRestQuest.data.battle.id
	map.event_state._active_snapshot = DeerRestQuest.data.battle.duplicate(true)
	map.event_state.phase = "encounter"
	map.travel.paused = true
	map._start_encounter_battle.call_deferred(true)

func battle_error(message: String) -> void:
	# Restore the same choice view after load/save failure, without a second modal.
	begin("decision")
	map.dialogue.set_line_text(message,false)

func handle_choice_input(event: InputEvent) -> bool:
	if choices==null or not choices.visible: return false
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed):
		choose("leave")
		map.get_viewport().set_input_as_handled()
		return true
	if event is InputEventKey:
		# Keep keyboard focus navigation for the two buttons, block map shortcuts.
		if event.keycode not in [KEY_TAB,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]: map.get_viewport().set_input_as_handled()
		return true
	return false

func _button(caption: String, action: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(240,93)
	button.add_theme_font_override("font",load("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf"))
	button.add_theme_font_size_override("font_size",24)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in ["normal","hover","pressed","focus"]:
		var style := StyleBoxTexture.new()
		style.texture = load("res://assets/UI-game-choicebutton.webp")
		if style_name=="hover": style.modulate_color = Color(1.15,1.15,1.15)
		if style_name=="pressed": style.modulate_color = Color(0.85,0.85,0.85)
		style.content_margin_left = 24
		style.content_margin_right = 24
		button.add_theme_stylebox_override(style_name,style)
	button.pressed.connect(func(): choose(action))
	choices.add_child(button)
	return button

func _layout_choices() -> void:
	if choices==null: return
	var factor: float = minf(map.size.x/1920.0,map.size.y/1080.0)
	choices.scale = Vector2.ONE*factor
	choices.size = choices.get_combined_minimum_size()
	var top: float = map.dialogue.background.position.y-(choices.size.y+20)*factor
	choices.position = Vector2((map.size.x-choices.size.x*factor)*0.5,maxf(100*factor,top))
