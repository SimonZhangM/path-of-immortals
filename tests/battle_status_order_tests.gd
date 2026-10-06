extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func shown(grid: BattleStatusIcons) -> Array[String]:
	var result: Array[String] = []
	for child: Control in grid.get_children():
		if child.visible: result.append(child.name)
	return result
func settle() -> void:
	for frame in 8: await process_frame
func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0,true)
	root.size = Vector2i(2560,1440)
	var registry := ContentRegistry.new()
	check(registry.load_base_content(),"content loads")
	var catalog := MapLoadoutStore.create_state(registry,registry.get_board("base.board.bag"))
	check(catalog.error.is_empty(),"catalog loaded without save")
	var owner := PartyMemberState.new(registry.get_character("base.character.chen_yu"),registry)
	var enemy := PartyMemberState.new(registry.get_enemy("base.enemy.chisong_liaozhu"),registry)
	enemy.definition = enemy.definition.duplicate(true)
	enemy.definition.status_capacity = 40
	var simulation := BattleSimulation.new([owner],[enemy],registry)
	var grid := BattleStatusIcons.new()
	root.add_child(grid)
	grid.configure()
	grid.show_all_for_testing = false
	var rules := simulation.t01
	check(rules.apply_status(owner,"流血",2,enemy,0),"debuff first")
	check(rules.apply_status(owner,"润脉",2,owner,100),"buff second")
	check(rules.apply_status(owner,"附炎",2,owner,100),"same time buff third")
	grid.refresh(owner)
	check(shown(grid) == ["流血","润脉","附炎"],"mixed kinds follow actual event insertion, including same-time order")
	rules.apply_status(owner,"流血",3,enemy,200)
	rules.consume(owner,"流血",2)
	grid.refresh(owner)
	check(shown(grid) == ["流血","润脉","附炎"],"stacking and consuming oldest batch preserve existing icon position")
	rules.consume(owner,"流血",3)
	# Removal and reapplication between two UI frames must still go to the end.
	rules.apply_status(owner,"流血",1,enemy,300)
	grid.refresh(owner)
	check(shown(grid) == ["润脉","附炎","流血"],"reappearing state moves to end even between refreshes")
	rules.consume(owner,"附炎",2)
	grid.refresh(owner)
	check(shown(grid) == ["润脉","流血"],"expired status removed and others keep order")
	grid.show_all_for_testing = true
	grid.refresh(owner)
	check(shown(grid).size() == 21 and shown(grid)[0] == "反锋","test preview retains full reference ordering")
	grid.show_all_for_testing = false
	grid.refresh(owner)
	check(shown(grid) == ["润脉","流血"],"normal mode restores chronological order")
	owner.combat_statuses.clear()
	grid.refresh(owner)
	check(not grid.visible,"empty status grid hides")
	var slot := MapEncounterItemSlot.new()
	slot.show_item(registry.get_item("base.organ.cslz_tusk"))
	check(slot.get_theme_stylebox("panel","TooltipPanel") is StyleBoxEmpty,"encounter source suppresses native tooltip backing/shadow")
	var tip := slot._make_custom_tooltip("") as ItemTooltip
	var panel := tip.find_child("SummaryPanel",true,false) as PanelContainer
	check(panel.get_theme_stylebox("panel").shadow_size == 0,"custom item frame has no shadow")
	if DisplayServer.get_name() != "headless":
		var background := TextureRect.new()
		background.texture = load("res://assets/battle-qingshihewan-zhu.webp")
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		root.add_child(background)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		enemy.equip_definition_loadout()
		var dialog := MapEncounterDialog.new()
		root.add_child(dialog)
		dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cliff_encounter.json"))
		dialog.present(event,enemy)
		# Render the exact source TooltipPanel style around the custom content.
		var wrapper := PanelContainer.new()
		wrapper.add_theme_stylebox_override("panel",slot.get_theme_stylebox("panel","TooltipPanel"))
		wrapper.z_index = 100
		root.add_child(wrapper)
		wrapper.add_child(tip)
		wrapper.position = Vector2(1330,740)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/item-tooltip-no-shadow-2k.png")
		wrapper.queue_free()
		dialog.queue_free()
		background.queue_free()
	else: tip.free()
	slot.free()
	grid.queue_free()
	await settle()
	print("STATUS ORDER / TOOLTIP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
