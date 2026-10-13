extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	root.size = Vector2i(2560, 1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var registry := ContentRegistry.new()
	assert(registry.load_base_content())
	var created := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	assert(created.error.is_empty())
	var model: MapLoadoutState = created.state
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_inventory.json"))
	var catalog := MapInventoryCatalog.new()
	catalog.configure(config)
	var samples: Array[Dictionary] = []
	for display_name in ["普通行囊", "火砂", "毒针", "柳叶镖", "飞针", "镇土丹", "开山斧", "培元丹", "回灵丹"]:
		for record: Dictionary in model.storage_records():
			if record.name != display_name: continue
			record.quantity = [3,36,27,64,38,6,1,15,9][samples.size()]
			record.acquired_at = 100 - samples.size()
			samples.append(record)
			break
	assert(samples.size() == 9)
	assert(catalog.replace_entries(samples).is_empty())
	var ui := MapInventoryScreen.new()
	ui.configure(catalog, config, model.board, model)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show()
	await settle()
	assert(ui.grid.columns == 5)
	var expected_width := ((ui.grid.get_parent().get_parent() as Control).size.x - 4 * ui.STORAGE_CARD_GAP) / 5.0
	for card: MapInventoryItemCard in ui.grid.get_children():
		assert(absf(card.size.x - expected_width) <= 1.0)
		assert(absf(card.size.y - card.size.x * card.STORAGE_ASPECT) <= 1.0)
		assert(card.canvas.get_node("NameShade").size == Vector2(186,37))
		assert(card.artwork_rect().size.is_equal_approx(Vector2.ONE * card.size.x))
		var original := MapInventoryItemCard.new()
		original.configure(card.entry, "")
		original.set_card_width(card.size.x)
		original.size = Vector2(card.size.x, card.size.x * original.CARD_ASPECT)
		original._layout()
		var original_art: MapItemArtwork = original.canvas.get_node("ItemArtwork")
		var current_art: MapItemArtwork = card.canvas.get_node("ItemArtwork")
		assert((current_art.size*current_art.scale*card.canvas.scale).is_equal_approx(original_art.size*original_art.scale*original.canvas.scale))
		original.free()
		assert(card.quality_badge == null and card.canvas.get_node_or_null("CategoryTags") == null)
		var title: Label = card.canvas.get_node("ItemName")
		assert(title.get_theme_color("font_color") == Color.WHITE)
		assert(card.canvas.get_node("NameShade").z_index >= card.canvas.get_node("ItemArtwork").z_index)
		if int(card.entry.quantity) > 1:
			var quantity: Label = card.canvas.get_node("Quantity")
			assert(quantity.text == str(int(card.entry.quantity)))
			assert(quantity.get_theme_stylebox("normal").corner_radius_top_left > 0)
			assert(quantity.get_rect().end.y <= title.position.y)
		if card.quantity_picker != null:
			assert(card.quantity_picker.position == Vector2(7,7))
			assert(card.selected_quantity() == 1)
			assert(card.quantity_picker.max_value == mini(10, int(card.entry.quantity)))
	assert(ui.grid.get_theme_constant("h_separation") == ui.grid.get_theme_constant("v_separation"))
	var tip := ItemTooltip.new()
	tip.configure(registry.get_item(samples[6].id), {}, -1, 0, true)
	root.add_child(tip)
	tip.position = Vector2(330, 330)
	tip.z_index = 100
	await settle()
	var badge: TextureRect = tip.find_child("QualityBadge", true, false)
	var tooltip_title: Label = tip.find_child("ItemTitle", true, false)
	assert(badge != null and badge.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	assert((badge.texture as AtlasTexture).atlas.get_image().has_mipmaps())
	assert(badge.get_global_rect().end.x < tooltip_title.global_position.x)
	assert(tip.find_child("CategoryTags", true, false).get_child_count() > 0)
	assert(not tip.find_child("KeywordInset", true, false).visible)
	(ui.grid.get_child(6) as MapInventoryItemCard).set_selected(true)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/square-inventory-cards.png")
		tip.show_keyword("疲惫")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/item-selected-keyword.png")
	# Shared battle cards use the same square presentation; rewards keep their
	# existing portrait cards until separately requested.
	var battle := BattleInventoryItemCard.new()
	battle.configure(samples[1], "掷具", true)
	battle.set_card_width(131.833333)
	assert(is_equal_approx(battle.custom_minimum_size.y, battle.custom_minimum_size.x * battle.STORAGE_ASPECT))
	assert(battle.quality_badge == null)
	battle.free()
	var reward := MapInventoryItemCard.new()
	reward.configure(samples[0], "阵盘")
	assert(reward.quality_badge != null and not reward.square_layout)
	reward.free()
	tip.queue_free()
	ui.queue_free()
	await settle()
	print("CARD LAYOUT: unchanged width/five columns, square image plus original name strip/equal gaps, selection marks, masked names/counts, quantity selector, tooltip badge/core/single definition, battle shared and rewards unchanged passed; static only, no real save")
	quit()
