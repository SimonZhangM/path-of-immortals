extends "res://scripts/map/map_quest_story_controller.gd"
const ChoiceStyle = preload("res://scripts/map/map_task_choice_style.gd")
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
	map.dialogue.resized.connect(_layout_choices)
	map.dialogue.picture.layout_changed.connect(_layout_choices)
	refresh_signs()

func refresh_signs() -> void:
	if signs==null: return
	signs.show_task_at(DeerRestQuest.marker_points(map.loadout,map.definition.id),"side")

func present() -> void:
	var saved := DeerRestQuest.story(map.loadout)
	if saved.active.is_empty(): return
	if saved.reward_pending:
		occupy(saved.active,"reward")
		map._ensure_event_views()
		map.dialogue.dismiss()
		choices.hide()
		map.reward_dialog.present(DeerRestQuest.reward_record(map.loadout),"任务物品",false,false,true)
		map.reward_dialog.card.loadout = map.loadout
		map.reward_dialog.card.mouse_filter = Control.MOUSE_FILTER_STOP
		return
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

func accept_reward() -> void:
	if not DeerRestQuest.story(map.loadout).reward_pending or map.reward_dialog.accept_button.disabled: return
	map.reward_dialog.accept_button.disabled = true
	var error := DeerRestQuest.command(map.loadout,map.inventory_save_path,"accept")
	if not error.is_empty():
		map.reward_dialog.error_label.text = error
		map.reward_dialog.accept_button.disabled = false
		if error.begins_with("储物袋容量不足"): _offer_receipt_deferral()
		return
	map.reward_dialog.pick_sound.play()
	map.reward_dialog.hide()
	finish()

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
	ChoiceStyle.apply(button)
	button.pressed.connect(func(): choose(action))
	choices.add_child(button)
	return button

func _layout_choices() -> void:
	if choices==null: return
	ChoiceStyle.layout(choices, map)
