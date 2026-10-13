extends SceneTree

var commands := 0
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 4: await process_frame
func run() -> void:
	create_timer(15).timeout.connect(func(): quit(2))
	root.size = Vector2i(2560,1440)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var registry := ContentRegistry.new()
	assert(registry.load_base_content())
	var model := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	assert(model.error.is_empty())
	var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cliff_encounter.json"))
	var enemy := PartyMemberState.new(registry.get_enemy(event.enemy_id),registry)
	enemy.equip_definition_loadout()
	var dialog := MapEncounterDialog.new()
	root.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.intimidate_requested.connect(func(): commands+=1)
	dialog.present(event,enemy)
	await settle()
	assert(dialog.intimidate_button.disabled and dialog.action_cards[2].disabled)
	assert(dialog.disabled_masks[2].visible and not dialog.disabled_masks[0].visible and not dialog.disabled_masks[1].visible)
	assert(dialog.disabled_masks[2].get_global_rect().encloses(dialog.action_cards[2].get_global_rect()))
	assert(dialog.disabled_masks[2].get_theme_stylebox("panel").bg_color==Color(0.09,0.09,0.09,0.68))
	assert(dialog.intimidate_button.tooltip_text.contains("胜利3次，且至少高一个等级"))
	dialog.select_action(2)
	dialog.activate_action(2)
	dialog.intimidate_button.pressed.emit()
	dialog.action_cards[2].pressed.emit()
	assert(dialog.selected_index==-1 and commands==0)
	assert(not dialog.selection_frames[2].visible and dialog.intimidate_button.texture_hover==dialog._idle_textures[2])
	dialog.set_busy(true)
	dialog.set_busy(false)
	assert(dialog.intimidate_button.disabled and not dialog.fight_button.disabled and not dialog.retreat_button.disabled)
	dialog.select_action(1)
	assert(dialog.selected_index==1 and dialog.selection_frames[1].visible)
	dialog.present(event,enemy)
	assert(dialog.intimidate_button.disabled and dialog.selected_index==-1)
	for slot in dialog.loot_slots: slot.tooltip_text=""
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/encounter-intimidate-disabled.png")
	dialog.queue_free()
	await settle()
	for node in root.find_children("*","AudioStreamPlayer",true,false):
		node.stop()
		node.stream=null
	print("INTIMIDATE DISABLED: mask, requirement text, selection/command guards, busy reset and reopen passed; no mouse or save I/O")
	quit()
