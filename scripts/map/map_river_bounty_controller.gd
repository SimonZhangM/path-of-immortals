extends "res://scripts/map/map_quest_story_controller.gd"
## Single commission opens directly; board catalog can later feed a notice list.
var choice_dialog: MapExitDialog

func _ready() -> void:
	super._ready()
	if not map.startup_error.is_empty(): return
	signs = preload("res://scripts/map/map_quest_signs.gd").new()
	signs.configure(map.content.get_node("Points"),map.sign_motion)
	refresh_signs()

func refresh_signs() -> void:
	if signs!=null: signs.show_task_at(RiverBountyQuest.marker_points(map.loadout,map.definition.id),"commission")

func try_arrival(point_id: String, clicked := false) -> bool:
	if map.event_state.is_active(): return owns_dialogue()
	var scene := RiverBountyQuest.interaction(map.loadout,map.definition.id,point_id) if clicked else RiverBountyQuest.arrival(map.loadout,map.definition.id,point_id)
	# A missing-material reminder never blocks the bench's actionable yellow sign.
	if scene=="reminder" and not OldBenchQuest.arrival(map.loadout,map.definition.id,point_id).is_empty(): return false
	if scene.is_empty(): return false
	begin(scene)
	return true

func present() -> void:
	var saved := RiverBountyQuest.story(map.loadout)
	if saved.active.is_empty(): return
	var event := RiverBountyQuest.event(saved.active)
	occupy(saved.active,"reward" if saved.reward_pending else "dialogue")
	map.event_state.line_index = int(saved.line)
	map._saved_loadout_revision = map.loadout.revision
	map.dialogue.present(event,DialogueJournal.render_text(event.lines[saved.line],map.loadout.narrative),event.line_speakers[saved.line],"dialogue_paused" if saved.choice_pending or saved.reward_pending else "dialogue",int(saved.line))
	if saved.reward_pending:
		map._ensure_event_views()
		map.reward_dialog.present(RiverBountyQuest.reward_record(map.loadout),"委托报酬",false,false)
		map.reward_dialog.heading.text = "交付凭证"
		map.reward_dialog.accept_button.get_node("AcceptCaption").text = "确认交付"
		_ensure_deferral()
		defer_receipt_button.show()
	if saved.choice_pending:
		if choice_dialog==null:
			choice_dialog = MapExitDialog.new()
			map.add_child(choice_dialog)
			choice_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			choice_dialog.confirmed.connect(func(): choose(true))
			choice_dialog.cancelled.connect(func(): choose(false))
		choice_dialog.present_confirmation("接下清理河湾兽患的悬赏？")
		choice_dialog.confirm_button.get_node("Caption").text = "接下悬赏"
		choice_dialog.cancel_button.get_node("Caption").text = "暂不接取"

func choose(value: bool) -> void:
	choice_dialog.set_busy(true)
	var error := RiverBountyQuest.command(map.loadout,map.inventory_save_path,"choose_yes" if value else "choose_later")
	if not error.is_empty():
		choice_dialog.error_label.text = error
		choice_dialog.set_busy(false)
		return
	choice_dialog.hide()
	present()

func handle_choice_input(event: InputEvent) -> bool:
	return choice_dialog.handle_confirmation_input(event) if is_instance_valid(choice_dialog) and choice_dialog.visible else false

func advance() -> void:
	if RiverBountyQuest.story(map.loadout).choice_pending: return
	super.advance()

func _ensure_deferral() -> void:
	if defer_receipt_button!=null: return
	defer_receipt_button = Button.new()
	defer_receipt_button.text = "稍后交付"
	defer_receipt_button.position = Vector2(170,465)
	defer_receipt_button.size = Vector2(200,40)
	defer_receipt_button.add_theme_font_size_override("font_size",22)
	map.reward_dialog.canvas.add_child(defer_receipt_button)
	defer_receipt_button.pressed.connect(func():
		var error := RiverBountyQuest.command(map.loadout,map.inventory_save_path,"defer_delivery")
		if not error.is_empty():
			map.reward_dialog.error_label.text = error
			return
		map.reward_dialog.hide()
		finish())

func finish() -> void:
	set_process(false)
	if is_instance_valid(choice_dialog): choice_dialog.hide()
	super.finish()
