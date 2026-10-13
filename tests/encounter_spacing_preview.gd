extends SceneTree

func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(15).timeout.connect(func(): quit(2))
	root.size=Vector2i(2560,1440)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	var registry := ContentRegistry.new()
	assert(registry.load_base_content())
	assert(MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag")).error.is_empty())
	var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_encounter_n12.json"))
	var enemy := PartyMemberState.new(registry.get_enemy(event.enemy_id),registry)
	enemy.equip_definition_loadout()
	var dialog := MapEncounterDialog.new()
	root.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.present(event,enemy)
	for slot in dialog.loot_slots:
		assert(slot.get_meta("source_rect").position.y==528)
		slot.tooltip_text=""
	for label in dialog.loot_names: assert(label.get_meta("source_rect").position.y==613)
	for i in 3:
		assert(dialog.action_cards[i].get_meta("source_rect").position.y==658)
		assert(dialog.action_buttons[i].get_meta("source_rect").position.y==718)
		assert(dialog.selection_frames[i].get_meta("source_rect").position.y==656)
		assert(dialog.disabled_masks[i].get_meta("source_rect").position.y==656)
	assert(dialog.backing.material.get_shader_parameter("offset_y")==3.0)
	assert(dialog.intimidate_button.disabled)
	for i in 5: await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var shifted := root.get_texture().get_image()
		shifted.save_png("res://artifacts/encounter-spacing.png")
		# Moving a strip must not tint/darken the rest of the source artwork.
		dialog.backing.material=null
		await RenderingServer.frame_post_draw
		var original := root.get_texture().get_image()
		for source in [Vector2(620,300),Vector2(1370,230),Vector2(650,500)]:
			var pixel := Vector2i(dialog.canvas.position+(source-dialog.FRAME.position)*1.2)
			assert(shifted.get_pixelv(pixel).is_equal_approx(original.get_pixelv(pixel)))
	dialog.queue_free()
	for i in 4: await process_frame
	print("ENCOUNTER SPACING: loot -3; cards/text/buttons/baked art/masks +3; static only")
	quit()
