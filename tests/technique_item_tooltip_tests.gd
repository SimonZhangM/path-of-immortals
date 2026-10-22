extends "res://tests/item_selection_tooltip_tests.gd"

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	root.size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var registry := ContentRegistry.new()
	check(registry.load_base_content(), "registry loads book presentations: " + str(registry.errors))
	if not registry.errors.is_empty(): quit(1); return
	var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_item_presentations.json"))
	var artwork: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/technique_book_art.json"))
	check(copy.size() == 35 and registry.library.book_items.size() == 35, "all 35 existing book IDs covered")
	for id: String in registry.library.books:
		var item := registry.get_item(id)
		var original := CultivationLibrary.item_record(registry.library.books[id], false)
		var combat := item.combat.duplicate(true)
		combat.erase("description")
		combat.erase("flavor_description")
		check(combat == original.combat and item.grid_size == Vector2i(original.size[0], original.size[1]) and item.quality == original.quality and item.effects == original.effects, "gameplay definition unchanged: " + id)
		check(item.display_name == copy[id].name and item.icon_path == artwork[id], "name and cover match: " + id)
		check(ItemTooltip.classification_tags(item) == ["功法", "书籍"] + copy[id].tags and item.tags.size() == 4, "ordered cultivation/book/element/role tags: " + id)
		check(ItemTooltip.effect_text(item) == copy[id].description, "approved intro replaces mechanical tooltip: " + id)
		var tip := ItemTooltip.new()
		tip.configure(item)
		root.add_child(tip)
		tip.position = Vector2(560, 120)
		await settle()
		tip.reset_size()
		await settle()
		var flavor: Label = tip.find_child("FlavorDescription", true, false)
		var title: Label = tip.find_child("ItemTitle", true, false)
		var chips: HFlowContainer = tip.find_child("CategoryTags", true, false)
		var body: Control = tip.find_child("EffectDescription", true, false)
		var portrait: MapItemArtwork = tip.find_child("PortraitArtwork", true, false)
		check(flavor.text == "“%s”" % copy[id].flavor_description and tip.description == copy[id].description, "poem and intro displayed intact: " + id)
		check(chips.get_child_count() == 5 and chips.get_child(4).text == "未领悟" and tip.find_child("QualityBadge", true, false) == null, "book label and actual mastery: " + id)
		var progress: HBoxContainer = tip.find_child("BookPracticeProgress", true, false)
		var target: Label = progress.get_node("PracticeNextStage")
		check(progress.get_node("PracticeValue").text == "0.0/600.0" and progress.get_node("PracticeBar").value == 0 and target.text == "第一重", "initial practice and next stage: " + id)
		check(progress.get_global_rect().end.y < body.get_global_rect().position.y and tip.find_child("BookPracticeDivider",true,false) != null, "practice row separated above intro: " + id)
		check(progress.get_global_rect().encloses(target.get_global_rect()), "next-stage chip fits progress row: " + id)
		check(portrait.texture != null and is_zero_approx(portrait.rotation), "upright illustrated cover: " + id)
		check(root.get_visible_rect().encloses(tip.get_global_rect()), "tooltip fits 1080p: %s %s" % [id, tip.get_global_rect()])
		check(flavor.get_global_rect().end.y < body.get_global_rect().position.y and title.get_global_rect().end.y <= chips.get_global_rect().position.y, "header, poem and intro do not overlap: " + id)
		if DisplayServer.get_name() != "headless" and id in ["base.cultivation_book.fire_03", "base.cultivation_book.wood_01", "base.cultivation_book.metal_05"]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(tip.get_global_rect())).save_png("res://artifacts/technique-item-%s.png" % id.get_slice(".", 2))
		tip.queue_free()
		await settle(2)
	for id: String in registry.library.spells:
		var mechanics := registry.get_item(id).combat.duplicate(true)
		mechanics.erase("presentation")
		check(mechanics == CultivationLibrary.item_record(registry.library.spells[id], true).combat, "spell mechanics unaffected: " + id)
	var screen := MapTechniqueScreen.new()
	screen.configure(registry.library)
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.show()
	await settle()
	check(screen.book_cards.size() == 35, "35 live book cards")
	for card: MapTechniqueBookCard in screen.book_cards:
		check(not card.has_meta(ItemTooltipHost.SOURCE_META) and card.tooltip_text.is_empty(), "technique sidebar has no tooltip: " + card.book_id)
	var host := ItemTooltipHost.for_control(screen)
	var card: MapTechniqueBookCard = screen.book_cards[0]
	var selected := screen.selected_book_id
	if DisplayServer.get_name() == "headless":
		await hover(card.get_global_rect().get_center())
		check(not is_instance_valid(host.tooltip), "technique sidebar hover stays silent")
		check(screen.selected_book_id == selected, "hover never switches selection")
		await click(screen.book_cards[1].get_global_rect().get_center())
		check(screen.selected_book_id == screen.book_cards[1].book_id, "book selection still works")
		screen.category_buttons[1].button_pressed = true
		await settle()
		check(not is_instance_valid(host.tooltip), "category switch hides previous tooltip")
		var wood_card: MapTechniqueBookCard = screen.book_cards[5]
		await hover(wood_card.get_global_rect().get_center())
		check(not is_instance_valid(host.tooltip), "other category also has no sidebar tooltip")
		screen.hide()
		await settle()
		check(not is_instance_valid(host.tooltip), "closing screen dismisses tooltip")
	else:
		await settle(12)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/technique-item-screen.png")
		host.dismiss(false)
	screen.queue_free()
	await settle()
	print("TECHNIQUE ITEM TOOLTIPS: %d checks, %d failures; no save IO; targeted mouse only in headless" % [checks, failures])
	quit(1 if failures else 0)
