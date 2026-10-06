extends SceneTree

var checks := 0
var failures := 0
var game: GameManager

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 8: await process_frame

func stock(item_id: String) -> String:
	for entry: Dictionary in game.storage.entries():
		if entry.item_id == item_id: return entry.instance_id
	return ""

func _run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560, 1440)
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	game = scene.get_node("GameManager")
	game.loadout_save_path = ""
	root.add_child(scene)
	game.set_process(false)
	await settle()
	check(game.startup_error.is_empty(), "real battle startup")
	var ui = scene.get_node("MainUI")
	var card: PartyMemberCard = ui.ally_panel.cards[0]
	check(card.portrait_frame.texture is AtlasTexture and card.portrait_frame.texture.atlas.resource_path == "res://assets/player-level-1.webp", "same player portrait frame as map")
	check(card.portrait_frame.texture.region == Rect2(16,45,510,510), "same frame crop as map")
	check(not card.armor_status.text.contains("甲 ·") and not card.armor_status.text.contains("重甲"), "player hides armor type text")
	check(not ui.enemy_panel.cards[0].armor_status.text.contains("轻甲"), "enemy hides armor type text")
	var seconds: Label = ui.find_child("TimerSeconds", true, false)
	check(seconds.text == "秒" and seconds.get_theme_font_size("font_size") == 20 and ui._time.get_theme_font_size("font_size") == 39, "timer suffix at rounded half size")
	var digit_width: float = ui._time.get_theme_font("font").get_string_size(ui._time.text,HORIZONTAL_ALIGNMENT_LEFT,-1,39).x * ui.scale.x
	check(seconds.global_position.x > ui._time.get_global_rect().get_center().x + digit_width * .5, "space between timer and seconds")
	var dagger := stock("base.map_item.t01_0005")
	var hammer := stock("base.map_item.short_iron_hammer")
	check(game.equip(dagger, 0, Vector2i.ZERO), "equip one-cell item")
	game.start_battle()
	game.pause_battle()
	game.set_adjustment(true)
	var bag := game.party[0].inventory
	check(game.can_equip(hammer, 0, Vector2i.ZERO), "two-cell hammer can replace one occupied item")
	check(game.equip(hammer, 0, Vector2i.ZERO), "replacement succeeds")
	check(bag.get_instances().size() == 1 and bag.item_at(Vector2i(0,1)) == hammer, "incoming occupies both cells")
	check(not stock("base.map_item.t01_0005").is_empty() and stock("base.map_item.short_iron_hammer").is_empty(), "displaced item returned without duplicate")
	check(not game.simulation.state.item_runtime.has(dagger) and game.simulation.state.item_runtime.has(hammer), "runtime detaches old and attaches new")
	check(game.simulation.cooling_remaining_usec(hammer) == 3000000, "replacement keeps battle insertion cooldown")
	check(game.equip(stock("base.map_item.t01_0005"), 0, Vector2i(0,1)), "one-cell incoming may overlap lower half of one large item")
	check(bag.get_instances().size() == 1 and not stock("base.map_item.short_iron_hammer").is_empty(), "large displaced item returns whole")
	game.unequip(0, dagger)
	game.equip(stock("base.map_item.t01_0005"), 0, Vector2i.ZERO)
	var one_cell := ""
	for entry: Dictionary in game.storage.entries():
		var item := game.registry.get_item(entry.item_id)
		if item.grid_size == Vector2i.ONE and item.category == "weapon":
			one_cell = entry.instance_id
			break
	check(not one_cell.is_empty() and game.equip(one_cell,0,Vector2i(0,1)), "second one-cell obstacle prepared")
	var original := bag.get_instances()
	var stored := game.storage.entries()
	check(not game.can_equip(hammer,0,Vector2i.ZERO) and not game.equip(hammer,0,Vector2i.ZERO), "two distinct overlapped items reject replacement")
	check(bag.get_instances() == original and game.storage.entries() == stored, "failed replacement is atomic")
	check(not game.can_equip(hammer,0,Vector2i(0,2)), "replacement cannot exceed board")
	var opened := InventoryState.new(game.registry,Vector2i(3,3))
	opened.add_item("test.opened", "base.pill.huichun", Vector2i.ZERO)
	opened.use_consumable("test.opened")
	check(opened.replacement_target(game.storage.peek_units(hammer,1),Vector2i.ZERO).is_empty(), "opened bottle cannot be displaced")
	opened.locked = true
	check(opened.replacement_target(game.storage.peek_units(hammer,1),Vector2i.ZERO).is_empty(), "locked inventory rejects replacement")
	for entry: Dictionary in bag.get_instances(): game.unequip(0,entry.instance_id)
	game.equip(hammer,0,Vector2i.ZERO)
	await settle()
	var board: InventoryView = ui.ally_panel.bags[0]
	var item := game.registry.get_item("base.map_item.short_iron_hammer")
	var preview := board.make_drag_preview(item, bag.get_instance(hammer))
	root.add_child(preview)
	preview.position = Vector2(600,600)
	var art: ItemDragPreview = preview.get_child(0)
	var board_rect := board.board_layout.footprint_rect(Vector2i.ZERO,item.grid_size,board.size)
	var displayed := ItemDragPreview.fitted_icon_rect(art.texture,board_rect).size * board.get_global_transform().get_scale()
	var dragged := ItemDragPreview.fitted_icon_rect(art.texture,Rect2(Vector2.ZERO,art.size)).size * art.get_global_transform().get_scale()
	check(displayed.is_equal_approx(dragged), "drag art matches actual 2K board art size")
	preview.queue_free()
	if DisplayServer.get_name() != "headless":
		var isolated := SubViewport.new()
		isolated.size = Vector2i(512,512)
		isolated.transparent_bg = true
		isolated.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(isolated)
		var transparent_preview := board.make_drag_preview(item,bag.get_instance(hammer))
		isolated.add_child(transparent_preview)
		transparent_preview.position = Vector2(256,256)
		await RenderingServer.frame_post_draw
		var pixels := isolated.get_texture().get_image()
		var local_art: ItemDragPreview = transparent_preview.get_child(0)
		var corner: Vector2 = local_art.get_global_transform() * Vector2(6,6)
		check(pixels.get_pixelv(Vector2i(corner)).a == 0.0, "cooling item drag has transparent footprint, no black rectangle")
		pixels.save_png("res://artifacts/battle-polish-drag.png")
		isolated.queue_free()
	game.set_adjustment(false)
	var modal := MapEncounterDialog.new()
	root.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cliff_encounter.json"))
	var enemy := PartyMemberState.new(game.registry.get_enemy(event.enemy_id), game.registry)
	modal.present(event, enemy)
	await settle()
	check(modal.visible and modal.canvas.scale.x > 1.0, "modal is rendered at actual 2K scale")
	var rows := modal.enemy_summary.get_children()
	check(rows.size() == 4, "four centered summary rows")
	var labels := []
	for row in rows:
		labels.append(row.get_child(1).get_child(0))
	check(rows[1].get_child(1).get_child(1).text == "穿刺主，钝击辅", "attack wording")
	var trait_text: Label = rows[3].get_child(1).get_child(1)
	check(trait_text.text == "高气血·蓄势爆发" and trait_text.get_line_count() == 1, "trait value is single line")
	check(is_equal_approx(trait_text.global_position.y,labels[3].global_position.y), "trait label and value share one row")
	check(absf(modal.enemy_summary.get_global_rect().get_center().y - modal.enemy_summary.get_parent().get_global_rect().get_center().y) < 1, "four rows centered")
	for row in rows:
		check(row.get_combined_minimum_size().x <= modal.enemy_summary.get_parent().size.x, "row fits frame width")
	var line: TextureRect = modal.find_child("EnemyItemsDivider",true,false)
	var line_color: Color = line.texture.gradient.colors[1]
	check(Color(line_color,1.0).is_equal_approx(Color("aeada8")), "divider grey color")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-polish-encounter.png")
	modal.queue_free()
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-polish-ui.png")
	scene.queue_free()
	await settle()
	print("BATTLE POLISH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
