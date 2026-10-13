extends SceneTree

const LOCATIONS := [
	[1,1,"雾松崖径","qingling_yanzhi"], [2,7,"河心乱礁","qingke_heyuan"],
	[3,10,"青溪渡口","qingke_heyuan"], [4,12,"夹壁山径","huiji_shanlang"],
	[5,30,"落英林径","chisong_liaozhu"], [6,21,"回水岭径","huiji_shanlang"],
	[7,28,"临溪石坡","qingling_yanzhi"], [8,33,"南湾沙洲","huiji_shanlang"],
	[9,24,"断阶水口","qingke_heyuan"], [10,17,"翻车商道","chisong_liaozhu"],
	[11,26,"南岸深林","qingling_yanzhi"]
]
var checks := 0
var failures := 0
var commands := [0,0,0]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
func settle() -> void:
	for i in 5: await process_frame
func click_at(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
	await settle()
func hover(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event,true)
	await settle()
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var rendering := DisplayServer.get_name() != "headless"
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = "res://artifacts/encounter-redesign-%d.json" % Time.get_ticks_usec()
	map.defer_map_music = true
	root.add_child(map)
	current_scene = map
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(), "actual map initializes")
	var dialog: MapEncounterDialog = map.encounter_dialog
	for path in ["res://assets/tanchuang-zaoyuzhan.webp",dialog.options.illustration_frame]:
		check((load(path) as Texture2D).get_image().has_mipmaps(),"shell/frame mipmaps")
	for row in LOCATIONS:
		var point := "base.map.qingshihewan.point.n%02d" % row[1]
		var id: String = map.event_registry.by_point[point]
		var event: Dictionary = map.event_registry.events[id]
		map.travel.current_node_id = point
		map.travel.mode = "idle"
		map.travel.node_arrived.emit(point)
		await settle()
		var definition: Dictionary = map.loadout.registry.get_enemy(event.enemy_id)
		check(dialog.visible and map.event_state.phase=="encounter", "arrival opens new popup")
		check(event.title==row[2] and event.enemy_id=="base.enemy."+row[3],"fixed location/species")
		check(dialog.heading.text==event.title and dialog.description.text==event.description and not event.description.is_empty(),"fixed location prose wins over random species copy")
		var picture := "res://assets/battle-qingheshiwan-%02d.webp" % row[0]
		check(dialog.location_illustration.texture.resource_path==picture,"numbered location illustration")
		check(dialog.location_illustration.texture.get_image().has_mipmaps(),"illustration mipmaps")
		check(dialog.location_frame.get_meta("source_rect").size==Vector2(463,694),"native inset frame dimensions")
		check(dialog.location_frame.get_global_rect().encloses(dialog.location_illustration.get_global_rect()),"image stays inside frame")
		check(dialog.location_illustration.clip_contents and dialog.location_illustration.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"same inset clipping as mining")
		check(dialog.rank_label.text==definition.presentation.rank_label and dialog.category_label.text==definition.presentation.category_label,"actual category and rank")
		check(dialog.enemy_description.text==definition.presentation.description,"authored enemy introduction")
		check(dialog.trait_labels.filter(func(label): return label.visible).size()==definition.presentation.traits.size(),"one or two actual mechanic traits")
		check(dialog.description.size.y <= 106 and dialog.description.get_minimum_size().y<=106,"full location copy fits header")
		for label in dialog._tag_labels:
			if label.visible:
				check(label.get_global_rect().end.y < dialog.enemy_description.get_global_rect().position.y,"tags do not overlap introduction")
		check(dialog.loot_slots.size()==definition.loot.size(),"all actual material drops shown")
		for i in dialog.loot_slots.size():
			var slot := dialog.loot_slots[i]
			check(slot.item.id==definition.loot[i].item_id and slot.item.id.begins_with("base.material."),"drop is material, not equipped organ")
			check(slot.get_theme_stylebox("panel").border_width_left==1,"drop image framed")
			if rendering: slot.tooltip_text=""
		if rendering and row[0] in [1,2,4,5]:
			await settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/encounter-new-%02d.png" % row[0])
		map._retreat_encounter()
		check(not dialog.visible and not map.event_state.completed.has(id),"leaving preserves enemy and completion")
	if not rendering:
		# Isolated native GUI input only for this task's new three-card behavior.
		var event: Dictionary = map.event_registry.events[map.event_registry.by_point["base.map.qingshihewan.point.n30"]]
		var enemy: PartyMemberState = map._encounter_enemies[event.id]
		var sample := MapEncounterDialog.new()
		root.add_child(sample)
		sample.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sample.retreat_requested.connect(func(): commands[0]+=1)
		sample.fight_requested.connect(func(): commands[1]+=1)
		sample.intimidate_requested.connect(func(): commands[2]+=1)
		for index in 3:
			sample.present(event,enemy)
			await settle()
			var button := sample.action_buttons[index]
			check(button.texture_normal.get_image().has_mipmaps() and sample._selected_textures[index].get_image().has_mipmaps(),"both button states mipmapped")
			if not sample._action_enabled(index):
				check(button.disabled and sample.action_cards[index].disabled and sample.disabled_masks[index].visible,"unavailable action is masked and disabled")
				sample.activate_action(index)
				check(commands[index]==0 and sample.selected_index==-1,"unavailable action cannot emit or select")
				continue
			await hover(button.get_global_rect().get_center())
			check(button.is_hovered() and button.texture_hover==sample._idle_textures[index],"unselected hover stays idle")
			await click_at(button.get_global_rect().get_center())
			check(commands[index]==0 and sample.selected_index==index,"first button click only selects")
			check(button.texture_normal==sample._idle_textures[index] and button.texture_hover==sample._selected_textures[index],"selected button only lights on hover")
			await click_at(button.get_global_rect().get_center())
			check(commands[index]==1,"second button click emits exactly one command")
			var card_point := sample.action_cards[index].get_global_rect().position+Vector2(50,28)
			await hover(card_point)
			check(not button.is_hovered(),"leaving selected button restores idle")
			sample.set_busy(true)
			await click_at(button.get_global_rect().get_center())
			check(commands[index]==1 and sample.action_cards[index].disabled,"busy blocks card/action input")
			sample.set_busy(false)
		sample.present(event,enemy)
		await click_at(sample.action_cards[1].get_global_rect().position+Vector2(50,28))
		check(sample.selected_index==1 and commands[1]==1,"card click selects without executing")
		sample.queue_free()
		await settle()
		# Real new UI -> existing fight transition; isolated save, no OS input.
		map.travel.current_node_id = event.point_id
		map.travel.node_arrived.emit(event.point_id)
		dialog.fight_button.pressed.emit()
		check(current_scene==map and dialog.selected_index==1,"first fight click stays on map")
		dialog.fight_button.pressed.emit()
		var presentation := root.get_node("MapPresentation")
		while current_scene==map or presentation.transitioning: await process_frame
		var battle := current_scene
		var manager: GameManager = battle.get_node("GameManager")
		manager.set_process(false)
		check(manager.startup_error.is_empty() and manager.enemy_id==event.enemy_id,"real fight transition preserves enemy")
		check(manager.simulation.state.phase==GameState.Phase.PREPARATION,"enters battle paused")
		check(battle.get_node("MainUI")._backdrop.texture.resource_path==EnemyPresentation.background_path(enemy.definition),"location illustration does not replace battlefield")
		battle.queue_free()
	else:
		map.queue_free()
	await settle()
	for node in root.find_children("*","AudioStreamPlayer",true,false):
		node.stop()
		node.stream = null
	await settle()
	print("ENCOUNTER REDESIGN: %d checks; %d failures (%s)" % [checks,failures,"static render" if rendering else "targeted input/integration"])
	quit(1 if failures else 0)
