extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _settle() -> void:
	for i in 8:
		await process_frame

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	root.add_child(map)
	map.set_inventory_open(true)
	await _settle()
	var screen: MapInventoryScreen = map.inventory_screen
	var previews := {}
	for card: MapInventoryItemCard in screen.grid.get_children():
		var item := screen.loadout.registry.get_item(card.entry.id)
		var tip := card._make_custom_tooltip(card.tooltip_text) as ItemTooltip
		_check(tip != null, "map storage creates shared tooltip")
		root.add_child(tip)
		tip.z_index = 100
		tip.position = Vector2(100, 160)
		await _settle()
		var portrait := tip.find_child("ItemPortrait", true, false) as Control
		var title := tip.find_child("ItemTitle", true, false) as Label
		var body := tip.find_child("EffectDescription", true, false) as VBoxContainer
		var parsed_lines := PackedStringArray()
		var soft_wrap_spacing_unchanged := true
		for line: RichTextLabel in body.get_children():
			parsed_lines.append(line.get_parsed_text())
			soft_wrap_spacing_unchanged = soft_wrap_spacing_unchanged and not line.has_theme_constant_override("line_separation")
		_check(portrait.size == Vector2(96, 96) and portrait.find_child("ItemGlow", true, false) != null, "square portrait uses quality mist")
		_check(title.get_theme_font("font") == ItemTooltip._term_font, "item name uses the term Song font: " + item.display_name)
		for line: RichTextLabel in body.get_children():
			_check(line.get_theme_font("normal_font") == ItemTooltip._body_font and line.get_theme_font("bold_font") == ItemTooltip._term_font, "effect copy uses Kai body font and Song term font: " + item.display_name)
		_check(tip.size.x <= tip.WIDTH + 2 and tip.size.y < 780, "tooltip uses the quarter-reduced width and fits fixed1920x1080 canvas: " + item.display_name)
		_check("\n".join(parsed_lines) == tip.description and not tip.description.contains("轮转") and not tip.description.contains("敌人"), "body uses cold-down/enemy-side wording with plain-text descriptions")
		var keyword_panel := tip.find_child("KeywordPanel", true, false)
		var words := ItemTooltip.keyword_meanings(item)
		_check((keyword_panel != null) == not words.is_empty(), "tooltip includes a glossary exactly when the item has defined keyword meanings: " + item.display_name)
		var keyword_rows := tip.find_child("KeywordRows", true, false) as VBoxContainer
		if keyword_rows != null:
			for row_index in range(1, keyword_rows.get_child_count()):
				var keyword_row := keyword_rows.get_child(row_index) as RichTextLabel
				_check(keyword_row.get_theme_font("normal_font") == ItemTooltip._body_font and keyword_row.get_theme_font("bold_font") == ItemTooltip._term_font, "glossary uses Song terms and Kai explanations: " + item.display_name)
		_check(body.get_theme_constant("separation") == tip.HARD_BREAK_GAP and soft_wrap_spacing_unchanged and (keyword_rows == null or body.get_theme_constant("separation") == keyword_rows.get_theme_constant("separation")), "hard breaks match glossary row spacing while soft-wrap line spacing stays unchanged: " + item.display_name)
		if item.category == "weapon":
			var chip_row := tip.find_child("CategoryTags", true, false) as HFlowContainer
			var damage_type := "斩击" if item.display_name == "青石短剑" else ("穿刺" if item.display_name == "猎弓" else "钝击")
			_check(chip_row.get_child_count() >= 3 and (chip_row.get_child(2) as Label).text == damage_type, "weapon third chip shows attack type: " + item.display_name)
			_check(item.stamina_cost > 0 and tip.description.contains("耗费") and not words.has("消耗") and tip.description.contains("敌方"), "weapon keeps stamina cost without consumable meaning")
		if item.category == "pill":
			_check(not words.has("消耗") and tip.description.contains("使用后消耗一瓶"), "pill consumption stays in body rather than glossary")
		_check(not tip.description.contains("不超过护甲上限"), "tooltip omits redundant armor-cap wording: " + item.display_name)
		tip.hide()
		previews[item.id] = tip
	var jade_id := "owned.base.map_item.warm_jade.0"
	screen.loadout.place(screen.loadout.drag_data("storage", jade_id), Vector2i.ZERO)
	var point := screen.loadout_board.layout.footprint_rect(Vector2i.ZERO, Vector2i.ONE, screen.loadout_board.size).get_center()
	var board_token := screen.loadout_board._get_tooltip(point)
	var board_tip := screen.loadout_board._make_custom_tooltip(board_token) as ItemTooltip
	_check(board_token == jade_id and board_tip.description == previews["base.map_item.warm_jade"].description, "board and storage show identical item information")
	board_tip.free()
	_check(screen.loadout_board._get_tooltip(screen.loadout_board.layout.footprint_rect(Vector2i(2, 2), Vector2i.ONE, screen.loadout_board.size).get_center()).is_empty(), "empty board cell has no stale tooltip")
	var groups := [["qingshi_short_sword", "hemostatic_pill"], ["warm_jade", "detox_powder"], ["coarse_cloth_armor", "sinew_pill"]]
	for index in groups.size():
		var shown: Array[ItemTooltip] = []
		for side in 2:
			var tip: ItemTooltip = previews["base.map_item." + groups[index][side]]
			tip.position = Vector2(180 + side * 830, 180)
			tip.show()
			shown.append(tip)
		await _settle()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/item_tooltips_%d.png" % index)
		for tip in shown:
			tip.hide()
	for tip in previews.values():
		tip.queue_free()
	map.queue_free()
	previews.clear()
	ItemTooltip._tooltip_theme = null
	ItemTooltip._keyword_theme = null
	ItemTooltip._body_font = null
	ItemTooltip._term_font = null
	await _settle()
	await create_timer(0.2).timeout
	print("ITEM TOOLTIPS: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
