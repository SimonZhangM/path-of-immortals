extends SceneTree

const Reward = preload("res://scripts/ui/battle_reward_dialog.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for i in 6: await process_frame

func wheel(point: Vector2, button: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.factor = 1.0
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await settle()

func capture(dialog: Control, label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var rect: Rect2 = dialog.backing.get_global_rect().grow(6)
	root.get_texture().get_image().get_region(Rect2i(rect)).save_png("res://artifacts/battle-reward-scroll-" + label + ".png")

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	root.content_scale_size = Vector2i.ZERO
	var dialog := Reward.new()
	root.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var baseline := MapRewardDialog.new()
	root.add_child(baseline)
	baseline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var record := {"id": "base.material.huifu_tooth", "name": "蝠齿", "quality": "下品", "quantity": 1, "icon": "res://assets/item-enemy-huiyifu-fuchi.webp"}
	var records: Array[Dictionary] = []
	for i in 6:
		var entry := record.duplicate(true)
		entry.quantity = i + 1
		records.append(entry)
	for dimensions in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = dimensions
		await settle()
		check(is_equal_approx(dialog.heading.position.y, baseline.heading.position.y), "battle uses shared heading offset without doubling")
		for count in [0, 1, 2, 3, 6]:
			dialog.present_loot(records.slice(0, count), {})
			await settle()
			check(dialog.grid.get_child_count() == count, "all reward records displayed")
			check(dialog.scroll.scroll_vertical == 0, "reopening starts at top")
			check(dialog.scroll.get_v_scroll_bar().visible == (count > 2), "scrollbar only above two items")
			check(not dialog.scroll.get_h_scroll_bar().visible, "no horizontal scroll")
			check(dialog.scroll.get_global_rect().end.y < dialog.accept_button.get_global_rect().position.y, "items remain above fixed buttons")
			if count == 0:
				check(dialog.empty_label.visible, "empty rewards supported")
				continue
			var first = dialog.grid.get_child(0)
			check(is_equal_approx(first.square.size.x, 152.0), "artwork size retained")
			check(is_equal_approx(first.name_label.position.y - first.square.get_rect().end.y, 17.0), "name gap increases by 10")
			if count == 1: await capture(dialog, "%d-one" % dimensions.x)
			if count <= 2: continue
			check(dialog.grid.columns == 2, "two columns")
			check(dialog.grid.get_child(2).position.y > first.position.y, "third item on next row")
			var title_rect: Rect2 = dialog.heading.get_global_rect()
			var button_rect: Rect2 = dialog.accept_button.get_global_rect()
			await wheel(first.square.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
			check(dialog.scroll.scroll_vertical > 0, "wheel over artwork scrolls down")
			for i in 40:
				if dialog.scroll.scroll_vertical >= int(dialog.scroll.get_v_scroll_bar().max_value - dialog.scroll.get_v_scroll_bar().page): break
				await wheel(dialog.scroll.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
			var last = dialog.grid.get_child(count - 1)
			check(dialog.scroll.get_global_rect().encloses(last.name_label.get_global_rect()), "last item name reachable")
			check(dialog.heading.get_global_rect() == title_rect and dialog.accept_button.get_global_rect() == button_rect, "title and buttons fixed during scroll")
			if count == 6: await capture(dialog, "%d-six-bottom" % dimensions.x)
			await wheel(dialog.scroll.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
			check(dialog.scroll.scroll_vertical < int(dialog.scroll.get_v_scroll_bar().max_value - dialog.scroll.get_v_scroll_bar().page), "wheel scrolls back up")
	dialog.queue_free()
	baseline.queue_free()
	await settle()
	print("BATTLE REWARD SCROLL: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
