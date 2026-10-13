extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1920, 1080)
	var stage := Control.new()
	root.add_child(stage)
	var backdrop := ColorRect.new()
	backdrop.color = Color("101d27")
	backdrop.size = Vector2(1920, 1080)
	stage.add_child(backdrop)
	var boards: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/qinglan_boards.json"))
	var records: Array[Dictionary] = []
	for level in range(1, 7):
		for record: Dictionary in boards:
			if record.id == "base.map_item.qinglan_board_%d" % level:
				assert(record.quality == MapItemQuality.QUALITIES[level - 1])
				records.append(record)
	assert(records.size() == 6)
	assert(records[5].name == "青岚 · 太虚" and records[5].quality == "玄品")
	assert(records[5].card_frame == "res://assets/level-7.webp")
	assert(MapItemQuality.background_path("玄品") == "res://assets/level-7.webp")
	assert(MapItemQuality.background_path("仙品") == "res://assets/level-6.webp")
	assert(MapItemQuality.color("玄品") == Color("e33d3d"))
	assert(MapItemQuality.color("仙品") == Color("e9bd47"))
	assert(MapItemQuality.level("玄品") == 6 and MapItemQuality.level("仙品") == 7)
	# Seventh grade is a display-only fixture, never granted to a player.
	var fairy := records[5].duplicate(true)
	fairy.quality = "仙品"
	fairy.name = "仙品预览"
	records.append(fairy)
	for row in 2:
		var width := 190.0 if row == 0 else 120.0
		var heading := Label.new()
		heading.text = "七档品质（实际六阵盘＋仙品显示夹具）" if row == 0 else "小尺寸奖励卡 · 同一底边定位"
		heading.position = Vector2(100, 65 + row * 400)
		heading.add_theme_font_size_override("font_size", 26)
		stage.add_child(heading)
		for index in 7:
			var card := MapInventoryItemCard.new()
			card.configure(records[index], "阵盘")
			card.set_card_width(width)
			card.size = Vector2(width, width * card.CARD_ASPECT)
			card.position = Vector2(100 + index * 240, 120 + row * 400)
			stage.add_child(card)
			card._layout()
			var badge := card.quality_badge
			assert(badge != null)
			var texture := badge.texture as AtlasTexture
			assert(texture.atlas.resource_path == "res://assets/levelbq-%d.webp" % (index + 1))
			assert(texture.atlas.get_image().has_mipmaps())
			assert(texture.region == Rect2(texture.atlas.get_image().get_used_rect()))
			assert(badge.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
			assert(badge.modulate == Color.WHITE and badge.self_modulate == Color.WHITE)
			assert(badge.get_rect().get_center().is_equal_approx(Vector2(width * 0.5, card.size.y)))
			assert(is_equal_approx(badge.size.x, width * 42.0 / 190.0))
			assert(is_equal_approx(badge.size.aspect(), texture.get_size().aspect()))
			assert(card.frame.resource_path == MapItemQuality.background_path(records[index].quality))
			assert(card.background.material.get_shader_parameter("line_color") == Color.from_string(records[index].get("card_border_color", ""), MapItemQuality.color(records[index].quality)))
			assert(card.canvas.get_node("CategoryTags").get_child(0).text == records[index].board_level)
	for i in 5: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://artifacts/item-quality-badges.png") == OK)
	print("PASS: seven quality badges, real board qualities, source bounds, mipmaps, two card sizes, bottom centers; existing realm tags and borders preserved")
	stage.queue_free()
	await process_frame
	quit()
