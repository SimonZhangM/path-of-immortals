extends SceneTree

var checks := 0
var failures := 0
var requests := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 3: await process_frame

func move_to(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await settle()

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	await move_to(point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func check_art(dialog: MapEncounterDialog) -> void:
	for index in 3:
		var button := dialog.action_buttons[index] as TextureButton
		var key := "button_selected" if index == dialog.selected_index else "button_idle"
		check(button.texture_normal.resource_path == dialog.options.actions[index][key], "art follows selection")
		check(button.texture_hover == button.texture_normal and button.texture_pressed == button.texture_normal and button.texture_disabled == button.texture_normal, "pointer and busy states preserve art")

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920,1080)
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute("res://artifacts/encounter-selection-20261101")
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry loads")
	for profile in ["qingshihewan_cliff_encounter", "wumingjiuci_encounter_n04"]:
		var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/%s.json" % profile))
		var enemy := PartyMemberState.new(registry.get_enemy(event.enemy_id), registry)
		var dialog := MapEncounterDialog.new()
		root.add_child(dialog)
		dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dialog.retreat_requested.connect(func(): requests += 1)
		dialog.fight_requested.connect(func(): requests += 1)
		dialog.intimidate_requested.connect(func(): requests += 1)
		dialog.present(event,enemy)
		await settle()
		check_art(dialog)
		if DisplayServer.get_name() == "headless":
			for index in 2:
				await click(dialog.action_buttons[index])
				check(dialog.selected_index == index and requests == 0, "first click selects only")
				check_art(dialog)
				await move_to(Vector2(20,20))
				check_art(dialog)
				await move_to(dialog.action_buttons[index].get_global_rect().get_center())
				check_art(dialog)
			await click(dialog.action_buttons[1])
			check(requests == 1, "second click still requests encounter action once")
			check_art(dialog)
			dialog.set_busy(true)
			check_art(dialog)
			dialog.set_busy(false)
			await click(dialog.action_buttons[2])
			check(dialog.selected_index==1 and requests==1 and dialog.disabled_masks[2].visible, "disabled intimidation cannot select or execute")
			dialog.present(event,enemy)
			check(dialog.selected_index == -1, "reopen resets selection")
			check_art(dialog)
			requests = 0
		else:
			dialog.select_action(0)
			await settle()
			check_art(dialog)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/encounter-selection-20261101/%s.png" % profile)
		dialog.queue_free()
		await settle()
	print("ENCOUNTER SELECTION STYLE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
