extends SceneTree

const EVENT := "base.map_event.qingshihewan.cliff_encounter"
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for frame in 8: await process_frame

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(2560,1440)
	for reason in ["retreat", "hp_zero"]:
		MapEventState.session_completed.clear()
		var scene = load("res://scenes/main/main.tscn").instantiate()
		var game: GameManager = scene.get_node("GameManager")
		game.loadout_save_path = ""
		game.enemy_id = "base.enemy.chisong_liaozhu"
		root.add_child(scene)
		current_scene = scene
		game.set_process(false)
		await settle()
		check(game.startup_error.is_empty(), "isolated actual battle loads")
		var content := MapEventRegistry.new()
		var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_events/qingshihewan_cliff_encounter.json"))
		check(content.configure([event], [event.point_id]).is_empty(), "encounter definition loads")
		var flow = load("res://scripts/map/map_battle_return.gd").new()
		flow.manager = game
		flow.events = MapEventState.new(content)
		flow.event_id = EVENT
		flow.map_scene_path = "res://scenes/maps/qingshihewan.tscn"
		flow.point_id = event.point_id
		flow.facing = "left"
		flow.save_path = ""
		scene.add_child(flow)
		var ui = scene.get_node("MainUI")
		ui.battle_exit_handler = flow.return_to_map
		if reason == "retreat": await check_art(game, ui)
		var before := game._durable_snapshot.duplicate(true)
		game.start_battle()
		for index in 100: game.simulation.t01.forced_rolls.append(.5)
		if reason == "retreat":
			check(game.request_retreat(), "retreat requested through game command")
		else:
			game.party[0].hp = 1
		game._process(3.0)
		ui._refresh()
		check(game.simulation.state.result == "defeat", reason + " is defeat")
		check(game.simulation.state.finish_reason == ("retreat" if reason == "retreat" else "defeat"), "finish cause retained")
		check(reason == "retreat" or game.party[0].hp == 0, "enemy attack actually reduced hp to zero")
		check(ui._result_heading.text == "战斗失败" and ui._retreat_dialog.visible, "defeat heading and return dialog")
		check(game._durable_snapshot == before and game.loot_summary.is_empty(), "failure grants no items or first-victory receipts")
		check(not flow._award_victory().is_empty(), "reward entry rejects failure")
		check(not flow.events.completed.has(EVENT), "failed battle keeps encounter unresolved")
		check((await flow.return_to_map()).is_empty(), "actual return to map succeeds")
		await settle()
		var map = current_scene
		check(map.has_method("_try_start_event"), "returned to actual map")
		if map.has_method("_try_start_event"):
			map.set_process(false)
			check(map.travel.current_node_id == event.point_id, "return to same path node")
			check(map.content.get_node("Points/N12/Sign").visible and not map.event_state.completed.has(EVENT), "enemy sign remains visible")
			check(map._encounter_enemies.has(EVENT) and map.event_state.try_start(event.point_id, event.point_id, true), "enemy remains available for another challenge")
		map.queue_free()
		await settle()
	MapEventState.session_completed.clear()
	print("BATTLE OUTCOME ART: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_art(game: GameManager, ui: Control) -> void:
	var bag: InventoryView = ui.ally_panel.bags[0]
	for row: Dictionary in game.storage.entries():
		if row.item_id == "base.map_item.short_iron_hammer":
			check(game.equip(row.instance_id, 0, Vector2i.ZERO), "sample hammer equipped")
	await settle()
	var instance: Dictionary = game.party[0].inventory.get_instances()[0]
	var item := game.registry.get_item(instance.item_id)
	var footprint := bag.board_layout.footprint_rect(instance.cell, item.grid_size, bag.size)
	var battle_art: MapItemArtwork = bag._artworks[instance.instance_id]
	var map_art := MapItemArtwork.new()
	map_art.configure(game._durable_loadout.records[item.id])
	ui.add_child(map_art)
	map_art.place_on_board(footprint)
	check(map_art.texture.region == battle_art.texture.region, "same map/battle transparent crop")
	check(map_art.size.is_equal_approx(battle_art.size) and map_art.position.is_equal_approx(battle_art.position), "same footprint artwork dimensions and optical alignment")
	var preview := ItemDragPreview.new()
	ui.add_child(preview)
	preview.configure(game,item,instance,footprint.size)
	check(preview.artwork.size.is_equal_approx(battle_art.size), "drag uses same artwork size as board")
	check(preview.artwork.texture.region == map_art.texture.region, "drag crop matches map")
	for art in [map_art, battle_art, preview.artwork]:
		check(art.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "shared mipmap filtering")
		check(art.has_node("ItemOutline") and art.get_node("ItemOutline").get_child_count() == 16, "shared one-pixel smooth silhouette")
		check(art.get_node("ItemGlow").material.shader == MapItemArtwork.GLOW_SHADER, "shared map glow shader")
	map_art.queue_free()
	preview.queue_free()
	for key in ["hide", "tusk", "hoof", "mane", "heart"]:
		var record: Dictionary = game._durable_loadout.records["base.material.cslz_"+key]
		check(record.quality == "下品" and record.card_frame == "res://assets/level-1.webp", "mortal drop defaults to lower quality " + key)
		var card := MapInventoryItemCard.new()
		card.configure(record,"兽材")
		check(card.frame.resource_path == "res://assets/level-1.webp", "actual material card has grey background")
		card.free()
	var raw := {"source_enemy_id": "base.enemy.chisong_liaozhu"}
	check(MapItemQuality.material_record(raw,game.registry).quality == "下品", "default derived from enemy realm")
	raw.quality = "灵品"
	check(MapItemQuality.material_record(raw,game.registry).quality == "灵品", "explicit material exception overrides default")
	check(MapItemQuality.material_record({"source_enemy_id":"missing"},game.registry).is_empty(), "invalid default source rejected")
	check(ui.enemy_panel.cards[0].portrait_frame == null, "baked enemy portrait kept without adding a second frame")
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-shared-artwork.png")
		var comparison := PanelContainer.new()
		comparison.position = Vector2(500,500)
		ui.add_child(comparison)
		var row := HBoxContainer.new()
		comparison.add_child(row)
		for label_text in ["地图阵盘显示", "战斗阵盘显示", "战斗拖拽显示"]:
			var column := VBoxContainer.new()
			row.add_child(column)
			var label := Label.new()
			label.text = label_text
			column.add_child(label)
			var holder := Control.new()
			holder.custom_minimum_size = footprint.size
			column.add_child(holder)
			if label_text == "战斗拖拽显示":
				var drag := ItemDragPreview.new()
				holder.add_child(drag)
				drag.configure(game,item,instance,footprint.size)
				drag.position = Vector2.ZERO
			else:
				var art := MapItemArtwork.new()
				art.configure(game._durable_loadout.records[item.id] if label_text == "地图阵盘显示" else MapItemArtwork.battle_record(game,item))
				holder.add_child(art)
				art.place_on_board(Rect2(Vector2.ZERO,footprint.size))
		var material_card := MapInventoryItemCard.new()
		material_card.configure(game._durable_loadout.records["base.material.cslz_heart"], "灵材")
		row.add_child(material_card)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/battle-artwork-comparison.png")
		comparison.queue_free()
