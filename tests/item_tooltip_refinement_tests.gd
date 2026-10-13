extends SceneTree

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 8: await process_frame
func tooltip_count(node: Node) -> int:
	var count := 1 if node is ItemTooltip and node.is_visible_in_tree() else 0
	for child in node.get_children(true): count += tooltip_count(child)
	return count
func run() -> void:
	create_timer(20).timeout.connect(func(): quit(2))
	root.size = Vector2i(2560,1440)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var registry := ContentRegistry.new()
	assert(registry.load_base_content())
	var made := MapLoadoutStore.create_state(registry, registry.get_board("base.board.bag"))
	assert(made.error.is_empty())
	var model: MapLoadoutState = made.state
	var record: Dictionary
	for candidate: Dictionary in model.storage_records():
		if candidate.name == "御木丹": record = candidate; break
	assert(not record.is_empty())
	var card := MapInventoryItemCard.new()
	card.configure(record,"丹药",true)
	card.bind_loadout(model,null)
	card.position = Vector2(1300,600)
	card.set_card_width(175)
	root.add_child(card)
	await settle()
	assert(card.tooltip_text.is_empty() and card.get_tooltip().is_empty())
	assert(not card.has_method("_make_custom_tooltip"), "Item tooltip must not expose the native popup builder")
	if DisplayServer.get_name() != "headless":
		card.set_selected(true)
		var tip := card.build_item_tooltip("") as ItemTooltip
		root.add_child(tip)
		tip.position = Vector2(480,440)
		await settle()
		check_presentation(card,tip,record)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/item-tooltip-refinement.png")
		tip.queue_free()
		card.queue_free()
		await settle()
		print("TOOLTIP REFINEMENT: static tags/flavor/overlapping border/original image size passed; no mouse")
		quit()
		return
	var point := card.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	var click := InputEventMouseButton.new()
	click.position = point
	click.global_position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await create_timer(1.2).timeout
	await settle()
	assert(tooltip_count(root) == 1, "Hover must create exactly one item tooltip")
	var host := ItemTooltipHost.for_control(card)
	assert(host.pinned)
	check_presentation(card,host.tooltip,record)
	# Keeping the pointer on the selected card past another native delay must
	# still leave one tooltip, and changing identification must not rearm it.
	card.set_identified(true)
	assert(card.tooltip_text.is_empty())
	await create_timer(1.0).timeout
	assert(tooltip_count(root) == 1)
	card.queue_free()
	await settle()
	assert(tooltip_count(root) == 0)
	print("TOOLTIP REFINEMENT: one pinned tooltip after both hover delays, native callback/text removed; tags/flavor/overlapping border/original image size passed; no real save")
	quit()

func check_presentation(card: MapInventoryItemCard, tip: ItemTooltip, record: Dictionary) -> void:
	var tags: HFlowContainer = tip.find_child("CategoryTags",true,false)
	var flavor: Label = tip.find_child("FlavorDescription",true,false)
	assert(flavor != null and flavor.text == "“%s”" % record.flavor_description)
	assert(flavor.get_theme_font_size("font_size") == 20)
	assert("KaiTi" in (flavor.get_theme_font("font") as SystemFont).font_names)
	for label: Label in tags.get_children():
		assert(label.get_theme_font_size("font_size") == flavor.get_theme_font_size("font_size"))
		assert(label.get_theme_color("font_color") == flavor.get_theme_color("font_color"))
	assert(flavor.get_global_rect().position.y >= tags.get_global_rect().end.y)
	assert(flavor.get_global_rect().end.x <= tip.get_global_rect().end.x)
	assert(card.background.material.get_shader_parameter("selected") == true)
	assert(card.background.material.get_shader_parameter("line_width") == card.BORDER_WIDTH)
	assert(card._selection_overlay.get_rect() == Rect2(Vector2.ZERO,card.size))
	var art: MapItemArtwork = card.canvas.get_node("ItemArtwork")
	assert(art.size.is_equal_approx(card.ORIGINAL_ART_SIZE * card.ORIGINAL_ART_SCALE))
