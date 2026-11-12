extends "res://scripts/map/map_quest_story_controller.gd"
## Shared dialogue/art/reward widgets; only the optional acceptance needs a choice.
var choice_dialog: MapExitDialog
var recovery_dialog: MapExitDialog
var arrived_now := false

func _ready() -> void:
	super._ready()
	if not map.startup_error.is_empty(): return
	signs = preload("res://scripts/map/map_quest_signs.gd").new()
	signs.configure(map.content.get_node("Points"),map.sign_motion)
	refresh_signs()

func refresh_signs() -> void:
	if signs==null: return
	var points := OldBenchQuest.marker_points(map.loadout,map.definition.id)
	signs.show_task_at(points,"side")

func record_arrival(point_id: String) -> void:
	arrived_now = true
	set_process(true)

func try_arrival(point_id: String, clicked := false) -> bool:
	if map.event_state.is_active(): return owns_dialogue()
	var scene := OldBenchQuest.interaction(map.loadout,map.definition.id,point_id) if clicked else OldBenchQuest.arrival(map.loadout,map.definition.id,point_id)
	# Deferred offers reopen on a later real arrival at the yellow marker.
	if arrived_now and scene.is_empty() and point_id in OldBenchQuest.marker_points(map.loadout,map.definition.id):
		scene = OldBenchQuest.interaction(map.loadout,map.definition.id,point_id)
	arrived_now = false
	if scene.is_empty(): return false
	begin(scene)
	return true

func present() -> void:
	var saved := OldBenchQuest.story(map.loadout)
	if saved.active.is_empty(): return
	var event := OldBenchQuest.event(saved.active)
	occupy(saved.active,"reward" if saved.reward_pending else "dialogue")
	map.event_state.line_index = int(saved.line)
	map._saved_loadout_revision = map.loadout.revision
	var paused: bool = saved.reward_pending or saved.choice_pending
	map.dialogue.present(event,DialogueJournal.render_text(event.lines[saved.line],map.loadout.narrative),event.line_speakers[saved.line],"dialogue_paused" if paused else "dialogue",int(saved.line))
	if saved.reward_pending:
		map._ensure_event_views()
		var handover := OldBenchQuest.handing_over(map.loadout)
		map.reward_dialog.present(OldBenchQuest.reward_record(map.loadout),"任务物品",handover,false,not handover)
		map.reward_dialog.card.loadout = map.loadout
		map.reward_dialog.card.mouse_filter = Control.MOUSE_FILTER_STOP
	if saved.choice_pending:
		_ensure_choice()
		choice_dialog.present_confirmation("替周伯去铁匠铺取件？")
		choice_dialog.confirm_button.get_node("Caption").text = "去取件"
		choice_dialog.cancel_button.get_node("Caption").text = "稍后再来"

func _ensure_choice() -> void:
	if choice_dialog!=null: return
	choice_dialog = MapExitDialog.new()
	map.add_child(choice_dialog)
	choice_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_dialog.confirmed.connect(func(): choose(true))
	choice_dialog.cancelled.connect(func(): choose(false))

func choose(help_now: bool) -> void:
	choice_dialog.set_busy(true)
	var error := OldBenchQuest.command(map.loadout,map.inventory_save_path,"choose_yes" if help_now else "choose_later")
	if not error.is_empty():
		choice_dialog.error_label.text = error
		choice_dialog.set_busy(false)
		return
	choice_dialog.hide()
	present()

func handle_choice_input(event: InputEvent) -> bool:
	if is_instance_valid(choice_dialog) and choice_dialog.visible: return choice_dialog.handle_confirmation_input(event)
	if is_instance_valid(recovery_dialog) and recovery_dialog.visible: return recovery_dialog.handle_confirmation_input(event)
	return false

func advance() -> void:
	if OldBenchQuest.story(map.loadout).choice_pending: return
	if not retry_begin.is_empty():
		begin(retry_begin)
		return
	var error := OldBenchQuest.command(map.loadout,map.inventory_save_path,"advance")
	if not error.is_empty():
		if error.begins_with("请将工具包"):
			_show_recovery(error)
		else:
			map.dialogue.set_line_text(str(OldBenchQuest.event(OldBenchQuest.story(map.loadout).active).lines[OldBenchQuest.story(map.loadout).line])+"\n"+error,false)
		return
	if OldBenchQuest.story(map.loadout).active.is_empty(): finish()
	else: present()

func begin(scene: String) -> void:
	if scene in ["repair","returning"] and OldBenchQuest.tool_unit(map.loadout).is_empty() and not OldBenchQuest.story(map.loadout).tools_returned:
		occupy(scene)
		_show_recovery("请将工具包放回行囊，再来帮忙。")
		return
	super.begin(scene)

func _show_recovery(message: String) -> void:
	if recovery_dialog==null:
		recovery_dialog = MapExitDialog.new()
		map.add_child(recovery_dialog)
		recovery_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		recovery_dialog.confirmed.connect(func():
			recovery_dialog.hide()
			finish())
	recovery_dialog.present_notice(message)

func accept_reward() -> void:
	if not OldBenchQuest.story(map.loadout).reward_pending or map.reward_dialog.accept_button.disabled: return
	map.reward_dialog.accept_button.disabled = true
	var error := OldBenchQuest.command(map.loadout,map.inventory_save_path,"accept")
	if not error.is_empty():
		map.reward_dialog.error_label.text = error
		map.reward_dialog.accept_button.disabled = false
		if error.begins_with("储物袋容量不足") or error.begins_with("请将工具包"): _offer_receipt_deferral()
		return
	if is_instance_valid(defer_receipt_button): defer_receipt_button.hide()
	map.reward_dialog.pick_sound.play()
	map.reward_dialog.hide()
	if OldBenchQuest.story(map.loadout).active.is_empty(): finish()
	else: present()

func finish() -> void:
	arrived_now = false
	set_process(false)
	if is_instance_valid(choice_dialog): choice_dialog.hide()
	super.finish()
