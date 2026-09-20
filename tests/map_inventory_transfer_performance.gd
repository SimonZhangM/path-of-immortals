extends SceneTree

const Metrics = preload("res://scripts/map/map_texture_metrics.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _cards(panel: MapInventoryScreen) -> Dictionary:
	var cards := {}
	for card in panel.grid.get_children():
		cards[card.entry.id] = card
	return cards

func _check_projection(panel: MapInventoryScreen) -> void:
	var entries := panel.catalog.visible_entries()
	_check(entries.size() == panel.grid.get_child_count(), "visible card count matches filtered records")
	for index in entries.size():
		_check(panel.grid.get_child(index).entry == entries[index], "visible card data/order matches catalog")

func _run() -> void:
	# Mutable resources must invalidate cached bounds and mipmap validation.
	var source := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	source.set_pixel(2, 3, Color.WHITE)
	var texture := ImageTexture.create_from_image(source)
	_check(not Metrics.inspect(texture).has_mipmaps and Metrics.inspect(texture).used_rect == Rect2i(2, 3, 1, 1), "initial texture metrics")
	source.set_pixel(5, 6, Color.WHITE)
	source.generate_mipmaps()
	texture.set_image(source)
	# Dummy rendering does not update the backing ImageTexture pixels.
	if DisplayServer.get_name() != "headless":
		_check(Metrics.inspect(texture).has_mipmaps and Metrics.inspect(texture).used_rect == Rect2i(2, 3, 4, 4), "resource change invalidates both cached metrics")
	root.size = Vector2i(1920, 1080)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	root.add_child(map)
	map.set_inventory_open(true)
	for i in 10:
		await process_frame
	var panel: MapInventoryScreen = map.inventory_screen
	var state := panel.loadout
	var id := "owned.base.map_item.qingshi_short_sword.0"
	var other := "owned.base.map_item.hunting_bow.0"
	var initial := state.snapshot()
	var width: float = panel.grid.get_child(0).size.x
	var samples_in: Array[float] = []
	var samples_out: Array[float] = []
	for cycle in 4:
		var before := _cards(panel)
		var started := Time.get_ticks_usec()
		var placed := state.place(state.drag_data("storage", id), Vector2i.ZERO)
		samples_in.append((Time.get_ticks_usec() - started) / 1000.0)
		_check(placed and panel.grid.get_child_count() == 9, "place one item")
		for card in panel.grid.get_children():
			_check(card == before[card.entry.id], "unaffected cards retain their nodes")
		await process_frame
		await process_frame
		started = Time.get_ticks_usec()
		var returned := state.take_back(state.drag_data("board", id))
		samples_out.append((Time.get_ticks_usec() - started) / 1000.0)
		_check(returned and state.snapshot() == initial, "return preserves all item identities/layout")
		await process_frame
		await process_frame
		for card in panel.grid.get_children():
			_check(is_equal_approx(card.size.x, width) and is_equal_approx(card.modulate.a, 1.0), "return retains fixed card width and opacity")
	_check(state.place(state.drag_data("storage", id), Vector2i.ZERO), "prepare exchange")
	_check(state.place(state.drag_data("storage", other), Vector2i.ZERO) and not state.storage.get_entry(id).is_empty(), "exchange returns original independent item")
	_check_projection(panel)
	_check(state.take_back(state.drag_data("board", other)), "return exchanged variant")
	panel.catalog.set_newest_first(false)
	_check_projection(panel)
	panel.catalog.set_filter("collection", "equipment")
	panel.catalog.set_filter("category", "armor")
	_check_projection(panel)
	panel.catalog.set_filter("collection", "all")
	_check_projection(panel)
	# A changed record must refresh its card instead of reusing stale labels.
	var records := state.storage_records()
	records[0].name += "测试"
	_check(panel.catalog.replace_entries(records).is_empty(), "changed record accepted")
	_check_projection(panel)
	var invalid := records.duplicate(true)
	invalid[0].icon = "res://missing-item-art.webp"
	_check(not panel.catalog.replace_entries(invalid).is_empty(), "cached validation still rejects missing assets")
	_check_projection(panel)
	print("TRANSFER synchronous drop ms: in=", samples_in, " out=", samples_out)
	print("TRANSFER checks=", checks, " failures=", failures)
	map.queue_free()
	await process_frame
	# Let the audio mixer release short placement voices before process exit.
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
