extends SceneTree

const SAVE := "res://artifacts/map-exit-dialog-test.json"
const EXIT := "base.map.qingshihewan.point.east_exit"
const NEIGHBOR := "base.map.qingshihewan.point.n15"
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)

func _settle() -> void:
	for frame in 6:
		await process_frame

func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)

func _clean() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func _run() -> void:
	_clean()
	root.size = Vector2i(1920, 1080)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = SAVE
	root.add_child(map)
	current_scene = map
	map.set_process(false)
	await _settle()
	_check(map.startup_error.is_empty(), "source map initializes")
	_check(map.travel.current_node_id == EXIT and not map.is_exit_open(), "initial arrival does not auto-open exit")
	var point: Vector2 = map.map_to_screen(map.travel.node_positions[EXIT])
	map.travel.request_destination(NEIGHBOR)
	map.travel.advance(1000)
	_check(map.travel.current_node_id == NEIGHBOR, "move to nearby node")
	_click(point)
	await _settle()
	_check(not map.is_exit_open() and map.travel.mode != "idle", "remote click travels rather than opening modal")
	_click(point)
	await _settle()
	_check(not map.is_exit_open(), "moving click cannot open modal")
	map.travel.advance(1000)
	map.player.present(map.travel)
	_check(map.travel.current_node_id == EXIT and not map.is_exit_open(), "reaching exit still requires another click")
	_click(point)
	await _settle()
	var modal: MapExitDialog = map.exit_dialog
	_check(map.is_exit_open() and map.travel.paused, "stationary repeat click opens and pauses")
	_check(modal.heading.text == "前往 青石镇" and modal.message.text == "确定离开这里吗？", "requested title and question")
	var font := modal.message.get_theme_font("font")
	var font_size := modal.message.get_theme_font_size("font_size")
	var kai_center := modal.message.position.x + font.get_string_size("确定离", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + font.get_string_size("开", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	_check(is_equal_approx(kai_center, MapExitDialog.DESIGN_SIZE.x * 0.5 - 3.0), "question mark is excluded: 开 aligns 3px left of modal center")
	_check(modal.confirm_button.texture_normal.resource_path.ends_with("button-queren.webp") and modal.cancel_button.texture_normal.resource_path.ends_with("button-quxiao.webp"), "distinct requested button assets")
	for button in [modal.confirm_button, modal.cancel_button]:
		_check(button.size.is_equal_approx(map.reward_dialog.accept_button.size), "button dimensions match reward")
		_check(is_equal_approx(MapExitDialog.DESIGN_SIZE.y - button.get_rect().end.y, MapRewardDialog.DESIGN_SIZE.y - map.reward_dialog.accept_button.get_rect().end.y), "bottom gap matches reward")
		_check(button.get_node("Caption").get_theme_font_size("font_size") == 26 and button.get_node("Caption").get_global_rect().get_center().is_equal_approx(button.get_global_rect().get_center()), "unchanged centered caption")
	_check(is_equal_approx(modal.cancel_button.position.x - modal.confirm_button.get_rect().end.x, 80.0 * 2.0 / 3.0), "button gap reduced by one third")
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = dimensions
		await _settle()
		map.reward_dialog._layout()
		_check(modal.canvas.get_global_rect().get_center().is_equal_approx(map.reward_dialog.canvas.get_global_rect().get_center()), "both modals share screen center")
		_check(modal.message.get_global_rect().end.y < modal.confirm_button.get_global_rect().position.y, "body and actions do not overlap")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			shot.save_png("res://artifacts/map_exit_dialog_%d.png" % dimensions.x)
			if dimensions.x == 1920:
				shot.get_region(Rect2i(modal.canvas.get_global_rect().grow(20))).save_png("res://artifacts/map_exit_dialog_detail.png")
	root.size = Vector2i(1920, 1080)
	await _settle()
	_key(KEY_I)
	_key(KEY_SPACE)
	_click(Vector2(80, 300))
	_check(map.is_exit_open() and not map.is_inventory_open(), "inventory/space/outside clicks cannot bypass modal")
	_click(modal.cancel_button.get_global_rect().get_center())
	await _settle()
	_check(not map.is_exit_open() and not map.travel.paused and current_scene == map, "real cancel click remains at source")
	_click(map.map_to_screen(map.travel.node_positions[EXIT]))
	await _settle()
	_key(KEY_ESCAPE)
	_check(not map.is_exit_open(), "escape cancels")
	_click(map.map_to_screen(map.travel.node_positions[EXIT]))
	await _settle()
	map.inventory_save_path = "res://artifacts/missing-exit-folder/inventory.json"
	_click(modal.confirm_button.get_global_rect().get_center())
	await _settle()
	_check(map.is_exit_open() and current_scene == map and not modal.error_label.text.is_empty() and not modal.confirm_button.disabled, "failed save keeps modal open and retryable")
	map.inventory_save_path = SAVE
	var before: Dictionary = map.loadout.snapshot()
	_click(modal.confirm_button.get_global_rect().get_center())
	await _settle()
	var destination = current_scene
	_check(destination != map and destination.definition.id == "base.map.qingshizhen", "real confirm loads town")
	_check(destination.startup_error.is_empty() and destination.travel.current_node_id == "base.map.qingshizhen.point.n25", "town starts at configured southwest bridge entrance")
	_check(destination.inventory_save_path == SAVE and destination.loadout.snapshot() == before, "inventory and custom save path survive transition")
	destination.set_process(false)
	_check(destination.exit_dialog != null and not destination.is_exit_open(), "town has reciprocal exit without automatic opening")
	var town_point := "base.map.qingshizhen.point.n25"
	var nearby: String = destination.travel.adjacency[town_point][0].to
	destination.travel.request_destination(nearby)
	destination.travel.advance(1000)
	var town_position: Vector2 = destination.map_to_screen(destination.travel.node_positions[town_point])
	_click(town_position)
	await _settle()
	_check(not destination.is_exit_open() and destination.travel.mode != "idle", "remote town exit click travels first")
	destination.travel.advance(1000)
	destination.player.present(destination.travel)
	_check(not destination.is_exit_open(), "arrival in town does not open return dialog")
	_click(town_position)
	await _settle()
	var return_modal: MapExitDialog = destination.exit_dialog
	_check(destination.is_exit_open() and return_modal.heading.text == "前往 青石河湾", "standing on town node and clicking opens return title")
	_check(return_modal.message.text == "确定离开这里吗？" and return_modal.confirm_button.size.is_equal_approx(MapRewardDialog.ACTION_SIZE), "same message and buttons in reverse direction")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(Rect2i(return_modal.canvas.get_global_rect().grow(20))).save_png("res://artifacts/map_return_dialog_detail.png")
	_click(return_modal.cancel_button.get_global_rect().get_center())
	await _settle()
	_check(current_scene == destination and not destination.is_exit_open(), "reverse cancel stays in town")
	_click(town_position)
	await _settle()
	destination._active_exit.target_point = "base.map.qingshihewan.point.missing"
	_click(return_modal.confirm_button.get_global_rect().get_center())
	await _settle()
	_check(current_scene == destination and destination.is_exit_open() and return_modal.error_label.text == "目的地路径节点不存在。", "invalid arrival node leaves source live and retryable")
	_click(return_modal.cancel_button.get_global_rect().get_center())
	await _settle()
	_click(town_position)
	await _settle()
	_click(return_modal.confirm_button.get_global_rect().get_center())
	await _settle()
	var river = current_scene
	river.set_process(false)
	_check(river.definition.id == "base.map.qingshihewan" and river.travel.current_node_id == EXIT, "reverse confirmation returns exactly to paired river node")
	_check(not river.is_exit_open() and river.loadout.snapshot() == before, "round trip preserves inventory and does not auto-reopen modal")
	# Temporary second link proves destinations do not depend on the default spawn.
	var links: Array = river.definition.exits.duplicate(true)
	links.append({"point_id": NEIGHBOR, "title": "测试第二出口", "scene": "res://scenes/maps/qingshizhen.tscn", "target_point": "base.map.qingshizhen.point.n30"})
	_check(river._configure_exits(links).is_empty() and river.exits_by_point.size() == 2, "multiple source nodes may have independent links")
	var duplicate := links.duplicate(true)
	duplicate.append(links[0])
	_check(not river._configure_exits(duplicate).is_empty() and river.exits_by_point.size() == 2, "duplicate source rejected atomically")
	var missing_target := links.duplicate(true)
	missing_target[0].erase("target_point")
	_check(not river._configure_exits(missing_target).is_empty(), "every link requires explicit target node")
	river.travel.request_destination(NEIGHBOR)
	river.travel.advance(1000)
	_click(river.map_to_screen(river.travel.node_positions[NEIGHBOR]))
	await _settle()
	_check(river.exit_dialog.heading.text == "测试第二出口", "second node selects its own link")
	_click(river.exit_dialog.confirm_button.get_global_rect().get_center())
	await _settle()
	var second_destination = current_scene
	_check(second_destination.travel.current_node_id == "base.map.qingshizhen.point.n30" and second_destination.definition.start_point == town_point, "explicit arrival overrides default spawn without changing it")
	_check(second_destination.loadout.snapshot() == before, "second link preserves inventory too")
	second_destination.queue_free()
	await _settle()
	_clean()
	print("MAP EXIT DIALOG: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
