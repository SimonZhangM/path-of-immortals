extends SceneTree

var failures: int = 0
var checks: int = 0
var ui: Control
var manager: GameManager
var sound_events: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1920, 1080)
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	manager = scene.get_node("GameManager")
	manager.set_process(false)
	ui = scene.get_node("MainUI")
	ui.game_audio.sound_played.connect(func(kind): sound_events.append(kind))
	await _layout()
	_check(manager.startup_error.is_empty(), "startup succeeds")
	_check(manager.party.size() == 1 and manager.enemies.size() == 1 and manager.companions.size() == 2, "one main each plus two allied companions")
	_check(not ui.storage_panel.visible and not ui._log_panel.visible, "drawers initially hidden")
	_check(not ui._bag_button.disabled and manager.can_edit_inventory(), "prebattle arrays editable without opening storage")
	_check_layout()
	_check(absf(ui._status.get_global_rect().get_center().x - ui.size.x / 2) < 1 and ui._status.global_position.y >= ui._time.get_global_rect().end.y, "status below centered timer")
	_check(ui._bag_button.get_global_rect().end.y > ui.size.y - 35, "adjustment button at middle bottom")
	await _capture("storage_default")
	await _move_all_bags()
	ui._bag_button.pressed.emit()
	await _layout()
	_check(ui.storage_panel.visible and manager.can_edit_inventory(), "button opens shared storage")
	_check(ui.storage_panel.cards.size() == 7, "seven content cards visible")
	await _test_drag_presentation()
	await _test_details_and_boards()
	_key(KEY_ESCAPE)
	await _layout()
	_check(not ui.storage_panel.visible and not manager.adjustment_open and manager.can_edit_inventory(), "escape closes storage but keeps prebattle arrays editable")
	_check(manager.simulation.state.phase == GameState.Phase.PREPARATION and manager.simulation.state.time_usec == 0, "escape preserves preparation and time")
	await _move_all_bags()
	ui._bag_button.pressed.emit()
	await _layout()
	_check(not manager.select_member(1), "companions cannot be selected as inventory targets")
	manager.select_member(0)
	var pill_key := "run.storage.base.pill.huichun.0"
	for index in 3:
		var card: StorageItemCard = ui.storage_panel.cards[pill_key]
		if DisplayServer.get_name() == "headless":
			var point := card.get_global_rect().get_center()
			_mouse_motion(point)
			_right_click(point)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_RIGHT
			event.pressed = true
			card._gui_input(event)
		await _layout()
	var pill_id := manager.party[0].inventory.matching_stack("base.pill.huichun")
	_check(not pill_id.is_empty(), "right click equips main array")
	if not pill_id.is_empty():
		_check(manager.party[0].inventory.get_instance(pill_id)["units"].size() == 3, "right clicks stack medicine")
	_check(manager.storage.get_entry(pill_key)["units"].size() == 7, "storage quantity decreases atomically")
	manager.unequip(0, pill_id)
	ui.storage_panel.set_category("pill")
	await _layout()
	_check(ui.storage_panel.cards.size() == 3, "medicine category filters content")
	await _capture("storage_medicines")
	ui.storage_panel.set_category("all")
	await _layout()
	var sword_id := "run.storage.base.weapon.qingfeng.0"
	var bag: InventoryView = ui.ally_panel.bags[0]
	var sword_card: StorageItemCard = ui.storage_panel.cards[sword_id]
	var data := sword_card.drag_data()
	_check(bag._can_drop_data(bag.cell_center(Vector2i(3, 0)), data), "storage drag accepts legal grid destination")
	if DisplayServer.get_name() == "headless":
		await _native_between(sword_card.get_global_rect().get_center(), bag.get_global_transform() * bag.cell_center(Vector2i(3, 0)), true)
	else:
		bag._drop_data(bag.cell_center(Vector2i(3, 0)), data)
	await _layout()
	_check(not manager.party[0].inventory.get_instance(sword_id).is_empty(), "storage drag inserts weapon")
	_check(manager.storage.get_entry(sword_id).is_empty(), "equipped weapon disappears from storage")
	var returning := bag.drag_data_at(bag.cell_center(Vector2i(3, 0)))
	_check(ui.storage_panel._can_drop_data(Vector2.ZERO, returning), "storage accepts returning array item")
	if DisplayServer.get_name() == "headless":
		await _native_between(bag.get_global_transform() * bag.cell_center(Vector2i(3, 0)), ui.storage_panel.global_position + Vector2(300, 20))
	else:
		ui.storage_panel._drop_data(Vector2.ZERO, returning)
	await _layout()
	_check(not manager.storage.get_entry(sword_id).is_empty(), "dragging back returns weapon")
	await _capture("storage_open")
	_key(KEY_SPACE)
	await _layout()
	_check(manager.simulation.state.phase == GameState.Phase.BATTLE and not manager.adjustment_open and not ui.storage_panel.visible, "space starts and closes adjustment")
	_check(ui._bag_button.disabled and not manager.set_adjustment(true), "running battle locks adjustment")
	_check(not bag._can_drop_data(bag.cell_center(Vector2i(3, 0)), data), "stale drag rejected after start")
	manager._process(1)
	_key(KEY_SPACE)
	await _layout()
	ui._bag_button.pressed.emit()
	await _layout()
	_check(manager.simulation.clock.paused and manager.can_edit_inventory(), "paused battle permits adjustment")
	_key(KEY_ESCAPE)
	await _layout()
	_check(not ui.storage_panel.visible and not manager.can_edit_inventory() and manager.simulation.clock.paused, "escape closes paused storage without resuming battle")
	_check(not manager.move_item(0, GameManager.SWORD_INSTANCE, Vector2i(0, 1)), "paused array remains locked without adjustment panel")
	ui._bag_button.pressed.emit()
	await _layout()
	_check(manager.equip(sword_id, 0, Vector2i(3, 0)), "paused insertion command")
	_check(manager.simulation.cooling_remaining_usec(sword_id) == 3_000_000, "inserted weapon shows three seconds")
	_check(manager.move_item(0, GameManager.SWORD_INSTANCE, Vector2i(0, 1)), "main rearrangement during pause")
	manager._process(10)
	_check(manager.simulation.state.time_usec == 1_000_000, "paused cooldown frozen")
	await _capture("storage_cooldown_3s")
	_key(KEY_SPACE)
	manager._process(2)
	await _layout()
	_check(manager.simulation.cooling_remaining_usec(sword_id) == 1_000_000, "cooldown displays one second after resume")
	await _capture("storage_cooldown_1s")
	_key(KEY_F3)
	manager._process(0.5)
	_check(manager.simulation.cooling_remaining_usec(sword_id) == 0 and manager.simulation.activation_progress(sword_id) == 0, "rotation starts after insertion cooldown at double speed")
	_key(KEY_F1)
	manager._process(3)
	_check(absf(manager.simulation.activation_progress(sword_id) - 0.5) < 0.001, "rotation follows half-speed simulation")
	ui._log_panel.show()
	await _layout()
	_check(ui._log_label.text.contains("野狗"), "battle record retained without a bottom log button")
	await _capture("storage_log")
	ui._log_panel.hide()
	_key(KEY_SPACE)
	await _layout()
	ui._bag_button.pressed.emit()
	await _layout()
	if DisplayServer.get_name() != "headless":
		for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1720, 720)]:
			root.size = dimensions
			await _layout()
			_check_layout()
			_check(ui.storage_panel.get_global_rect().end.x <= ui.size.x and ui.storage_panel.get_global_rect().end.y <= ui.size.y, "storage panel within viewport")
			await _capture("storage_%dx%d" % [dimensions.x, dimensions.y])
	manager.set_adjustment(false)
	var full_companions: Array[CompanionState] = manager.companions.duplicate()
	for count in [0, 1, 2]:
		manager.companions.assign(full_companions.slice(0, count))
		manager.restart()
		await _layout()
		_check_layout()
		_check(ui.ally_panel.companion_cards.size() == count, "optional companion roster reflected without extra boards")
	await _test_activation_feedback()
	await _test_cultivation_and_feedback()
	await _test_companion_presentation()
	await _test_controls_and_retreat()
	ui.game_audio.stop_all()
	await create_timer(0.2).timeout
	root.remove_child(scene)
	scene.free()
	await process_frame
	print("UI RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_companion_presentation() -> void:
	manager.restart()
	await _layout()
	var healer: TraitSlot = ui.ally_panel.companion_cards[0].slots[0]
	var caster: TraitSlot = ui.ally_panel.companion_cards[1].slots[0]
	_check(healer.tooltip_text.contains("每6秒") and caster.tooltip_text.contains("不触发反击"), "trait details expose authored effects")
	var tooltip := healer._make_custom_tooltip(healer.tooltip_text) as PanelContainer
	_check(tooltip.get_child(0).text.contains("恢复5点气血"), "custom trait tooltip explains actual values")
	tooltip.free()
	_check(CooldownRing.tint(manager.registry, "base.element.none") == Color.WHITE and CooldownRing.tint(manager.registry, "base.element.fire") == Color("f07845"), "countdown color follows element with white default")
	manager.start_battle()
	manager._process(0.4)
	_check(is_equal_approx(ui.ally_panel.bags[0].cooldown_progress(GameManager.SWORD_INSTANCE), 0.4 / 3.0), "item circle tracks independent rotation progress")
	_check(manager.simulation.trait_remaining_usec(caster.runtime_key) == 3_600_000, "companion numeric countdown reads remaining seconds")
	await _capture("v10_rotation")
	manager.toggle_pause()
	manager._process(20)
	_check(manager.simulation.trait_remaining_usec(caster.runtime_key) == 3_600_000, "UI support countdown frozen during pause")
	manager.toggle_pause()
	manager._process(3.6)
	_check(caster.pulse > 0 and manager.simulation.trait_remaining_usec(caster.runtime_key) == 4_000_000, "active support flashes and restarts its countdown at activation")
	caster.set_process(false)
	caster.pulse = 0.12
	caster.queue_redraw()
	await _capture("v10_trait_activation")
	caster.set_process(true)

func _test_controls_and_retreat() -> void:
	root.size = Vector2i(1920, 1080)
	manager.restart()
	await _layout()
	var buttons: Array = [ui._pause_button, ui._speed_buttons[0.5], ui._speed_buttons[1.0], ui._speed_buttons[2.0]]
	for index in buttons.size():
		var rect: Rect2 = buttons[index].get_global_rect()
		_check(is_equal_approx(rect.size.x, rect.size.y) and is_equal_approx(rect.size.y, 48), "playback buttons enlarged square")
		_check(buttons[index].get_theme_stylebox("normal").bg_color == Color("2d261f"), "playback button brown background")
		if index > 0:
			_check(rect.position.x > buttons[index - 1].get_global_rect().end.x, "playback order pause half play double")
	_check(is_equal_approx(ui._timer_frame.size.x, 580.0 * 2.0 / 3.0) and ui._retreat_button.global_position.x > ui._bag_button.global_position.x, "enlarged timer and adjustment-retreat row")
	_check(ui._battle_button.caption == "开始战斗" and ui._battle_button.action_icon == ui._battle_icon, "central button initially offers battle start")
	sound_events.clear()
	ui._battle_button.pressed.emit()
	_check(manager.simulation.state.phase == GameState.Phase.BATTLE and ui._battle_button.caption == "战斗暂停" and ui._battle_button.action_icon == ui._wait_icon, "central button starts battle and offers pause")
	_check(sound_events == ["click"] and ui._battle_button.feedback_remaining > 0, "successful central click plays sound and pulses")
	var previous_depth: float = ui._battle_button.press_depth
	for step in 12:
		ui._battle_button._process(0.02)
		_check(ui._battle_button.press_depth <= previous_depth, "released button returns monotonically without a second pulse")
		previous_depth = ui._battle_button.press_depth
	_check(is_zero_approx(previous_depth), "released button settles completely")
	ui._bag_button.pressed.emit()
	_check(not manager.adjustment_open and sound_events == ["click"], "disabled adjustment neither opens nor plays click")
	manager.set_speed(2.0)
	ui._battle_button.pressed.emit()
	_check(manager.simulation.clock.paused and ui._battle_button.caption == "战斗继续" and ui._battle_button.action_icon == ui._battle_icon, "central button pauses and offers continue")
	ui._bag_button.pressed.emit()
	_check(manager.adjustment_open and sound_events.back() == "click" and ui._bag_button.feedback_remaining > 0, "paused adjustment opens with feedback")
	ui._battle_button.pressed.emit()
	_check(not manager.simulation.clock.paused and not manager.adjustment_open and manager.simulation.clock.speed_multiplier == 2.0, "central resume closes storage and preserves speed")
	_key(KEY_SPACE)
	await _layout()
	_check(ui._battle_button.caption == "战斗继续", "space updates central button presentation")
	manager.restart()
	await _layout()
	_check(ui._retreat_button.disabled, "retreat unavailable before battle")
	_check(ui._settings_button.disabled and ui._settings_button.global_position.x > ui._speed_buttons[2.0].get_global_rect().end.x, "future settings placeholder follows speed controls")
	ui._speed_buttons[1.0].pressed.emit()
	_check(manager.simulation.state.phase == GameState.Phase.BATTLE, "play icon starts battle")
	ui._pause_button.pressed.emit()
	ui._pause_button.pressed.emit()
	_check(manager.simulation.clock.paused, "pause icon is idempotent")
	ui._speed_buttons[1.0].pressed.emit()
	_check(not manager.simulation.clock.paused and manager.simulation.clock.speed_multiplier == 1, "play icon resumes normal speed")
	ui._retreat_button.pressed.emit()
	_check(sound_events.back() == "click" and ui._retreat_button.feedback_remaining > 0, "retreat click has audio and visual feedback")
	await _layout()
	_check(ui._countdown.visible and ui._countdown.number.text == "3s" and ui._retreat_button.disabled, "retreat starts central countdown and locks repeat button")
	_check(ui._countdown.get_global_rect().get_center().is_equal_approx(ui.size * 0.5), "retreat countdown centered on whole screen")
	await _capture("v09_retreat_3s")
	manager._process(0.7)
	await _layout()
	_check(ui._countdown.display.scale.x > 1 and ui._countdown.blur.get_shader_parameter("blur_radius") > 0 and ui._countdown.display.modulate.a < 1, "countdown expands blurs and fades")
	await _capture("v09_retreat_blur")
	ui._pause_button.pressed.emit()
	manager._process(10)
	await _layout()
	_check(is_equal_approx(ui._countdown.progress, 0.7), "countdown animation freezes with combat")
	ui._speed_buttons[1.0].pressed.emit()
	manager._process(0.3)
	await _layout()
	_check(ui._countdown.number.text == "2s" and ui._countdown.display.scale == Vector2.ONE, "new second starts crisp")
	ui._speed_buttons[2.0].pressed.emit()
	manager._process(0.5)
	await _layout()
	_check(ui._countdown.number.text == "1s", "double speed countdown")
	ui._speed_buttons[0.5].pressed.emit()
	manager._process(2)
	await _layout()
	_check(manager.simulation.state.result == "retreat" and ui._retreat_dialog.visible and not ui._countdown.visible, "success opens modal and hides countdown")
	_check(ui._log_label.text.contains("已成功撤退") and not manager.can_edit_inventory(), "retreat logged and editing locked")
	ui._review_button.pressed.emit()
	_check(ui._review_note.visible and ui._retreat_dialog.visible, "review placeholder leaves exit accessible")
	await _capture("v09_retreat_success")
	var exits: Array = []
	manager.battle_exit_requested.disconnect(ui._exit_battle)
	manager.battle_exit_requested.connect(func(): exits.append(true), CONNECT_ONE_SHOT)
	ui._exit_button.pressed.emit()
	_check(exits.size() == 1, "exit button sends guarded exit request")
	manager.battle_exit_requested.connect(ui._exit_battle)
	manager.restart()
	manager.enemies[0].hp = 1
	manager.start_battle()
	manager.request_retreat()
	manager._process(3)
	await _layout()
	_check(manager.simulation.state.result == "victory" and not ui._retreat_dialog.visible and not ui._countdown.visible, "victory at deadline prevents retreat dialog")

func _test_cultivation_and_feedback() -> void:
	manager.restart()
	await _layout()
	for index in 3:
		var card: PartyMemberCard = ui.ally_panel.cards[0] if index == 0 else ui.ally_panel.companion_cards[index - 1].portrait_card
		_check(card.portrait_frame.texture.resource_path == ("res://assets/pt01.webp" if index == 0 else "res://assets/pt000.webp"), "main uses rank frame and companions use shared support frame")
		_check(card._title.text.ends_with("（%s）" % ["炼气", "炼气", "筑基"][index]), "title shows authoritative cultivation name")
		_check(card.name_label.text == ["辰宇 · 炼气", "队友 · 青璃", "队友 · 玄川"][index], "portrait nameplate shows configured name and rank")
	var hero_card: PartyMemberCard = ui.ally_panel.cards[0]
	_check(manager.party[0].set_cultivation_rank("base.cultivation.spirit_transformation"), "cultivation state can change without changing attributes")
	await _layout()
	_check(hero_card.portrait_frame.texture.resource_path == "res://assets/pt05.webp" and hero_card.name_label.text == "辰宇 · 化神", "rank change refreshes both frame and nameplate")
	manager.party[0].set_cultivation_rank("base.cultivation.qi_refining")
	await _layout()
	manager.move_item(0, GameManager.SWORD_INSTANCE, Vector2i.ZERO)
	sound_events.clear()
	var bag: InventoryView = ui.ally_panel.bags[0]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = bag.cell_center(Vector2i.ZERO)
	bag._gui_input(click)
	_check(sound_events == ["pick"], "picking array item plays pickup once")
	sound_events.clear()
	manager.move_item(0, GameManager.SWORD_INSTANCE, Vector2i(0, 1))
	_check(sound_events == ["place"], "successful array move plays placement once")
	sound_events.clear()
	manager.move_item(0, GameManager.SWORD_INSTANCE, Vector2i(1, 1))
	_check(sound_events == ["invalid"], "invalid move plays rejection once")
	manager.move_item(0, GameManager.SWORD_INSTANCE, Vector2i.ZERO)
	manager.set_adjustment(true)
	await _layout()
	var card: StorageItemCard = ui.storage_panel.cards.values()[0]
	sound_events.clear()
	if DisplayServer.get_name() == "headless":
		await _native_between(card.get_global_rect().get_center(), Vector2(950, 280))
		_check(sound_events == ["pick", "invalid"], "invalid native drag plays rejection once at release")
	else:
		card._gui_input(click)
		_check(sound_events == ["pick"], "storage pickup uses same sound")
	manager.set_adjustment(false)
	manager.start_battle()
	sound_events.clear()
	manager._process(3)
	var enemy_card: PartyMemberCard = ui.enemy_panel.cards[0]
	_check(enemy_card.hit_effects.size() >= 1, "main weapon displays hit feedback")
	_check(sound_events.count("hit") == manager.simulation.state.activation_counts[0] + manager.simulation.state.activation_counts[1], "each resolved weapon hit plays one sound")
	var hit: HitFeedback = enemy_card.hit_effects[0]
	for panel in [ui.ally_panel, ui.enemy_panel]:
		for member_card in panel.cards:
			for effect in member_card.hit_effects:
				effect.set_process(false)
	_check(hit.damage_label.text == "-10" and hit.damage_label.get_theme_color("font_color") == Color("af3549"), "damage text uses actual hit value and HP color")
	var target := manager.simulation.state.target_for(1)
	for index in manager.party.size():
		if manager.party[index] == target:
			_check(ui.ally_panel.cards[index].hit_effects[0].damage_label.text == "-3", "enemy hit displays armor-reduced damage on actual ally")
	await _capture("v08_hit_start")
	await _layout()
	for first in enemy_card.hit_effects.size():
		for second in range(first + 1, enemy_card.hit_effects.size()):
			_check(not enemy_card.hit_effects[first].damage_label.get_global_rect().intersects(enemy_card.hit_effects[second].damage_label.get_global_rect()), "simultaneous damage labels do not overlap")
	var start_position := hit.damage_label.position
	hit._process(0.4)
	_check(hit.damage_label.position.y > start_position.y and hit.damage_label.modulate.a < 1, "damage text descends while fading")
	await _capture("v08_hit_fading")
	_check(manager.simulation.state.time_usec == 3_000_000, "hit animation does not advance simulation")
	hit._process(0.5)
	_check(hit.is_queued_for_deletion(), "hit feedback cleans itself up")
	for kind in GameAudio.STREAMS:
		_check(ui.game_audio.players[kind].stream.get_length() > 0, "sound resource decodes: " + kind)
	_check(ui.game_audio.players["click"].stream.get_length() > 0, "synthesized click has playable audio")

func _test_activation_feedback() -> void:
	root.size = Vector2i(1920, 1080)
	manager.restart()
	manager.select_member(0)
	manager.equip_random("run.storage.base.pill.yunling.0")
	manager.party[0].spirit = 50
	await _layout()
	var bag: InventoryView = ui.ally_panel.bags[0]
	var pill_id := manager.party[0].inventory.matching_stack("base.pill.yunling")
	for board in ui.ally_panel.bags + ui.enemy_panel.bags:
		board.set_process(false)
	manager.start_battle()
	manager._process(3)
	_check(bag._pulses.has(GameManager.SWORD_INSTANCE) and bag._pulses.has(pill_id), "weapon and medicine activations trigger visual feedback")
	_check(ui.enemy_panel.bags[0]._pulses.has(GameManager.CLAW_INSTANCE), "enemy activation uses same feedback")
	for board in ui.ally_panel.bags + ui.enemy_panel.bags:
		board._process(InventoryView.PULSE_DURATION * 0.35)
	await _capture("v07_activation_peak")
	await _layout()
	var overlay: TextureRect = bag._pulses[GameManager.SWORD_INSTANCE]["overlay"]
	var peak_width := overlay.size.x
	_check(overlay.modulate.a > 0 and overlay.modulate.a < 0.3, "faint white overlay visible during pulse")
	for board in ui.ally_panel.bags + ui.enemy_panel.bags:
		board._process(InventoryView.PULSE_DURATION * 0.4)
	await _capture("v07_activation_recoil")
	await _layout()
	_check(overlay.size.x < peak_width and overlay.modulate.a > 0, "image contracts while white flash remains synchronized")
	for board in ui.ally_panel.bags + ui.enemy_panel.bags:
		board._process(InventoryView.PULSE_DURATION * 0.26)
	_check(bag._pulses.is_empty() and manager.simulation.state.time_usec == 3_000_000, "pulse ends without advancing simulation")
	manager._process(3)
	_check(manager.party[0].inventory.get_instance(pill_id).is_empty() and bag._pulses.has(pill_id), "last bottle keeps transient feedback after authoritative consumption")
	bag._process(InventoryView.PULSE_DURATION * 0.35)
	await _capture("v07_last_bottle_flash")
	bag._process(InventoryView.PULSE_DURATION)
	_check(bag._pulses.is_empty(), "consumed bottle ghost is removed after pulse")

func _test_details_and_boards() -> void:
	_check(ui.enemy_panel.bags[0].board_texture.resource_path == "res://assets/bag-bg-2.webp", "dog uses roots board skin")
	var cards: Array = ui.storage_panel.cards.values()
	_check(ui.storage_panel._grid.columns == 5, "storage uses five columns")
	_check(is_equal_approx(cards[0].global_position.y, cards[4].global_position.y) and cards[5].global_position.y > cards[0].global_position.y, "five cards actually fit the first row")
	for card in cards:
		_check(card.icon.get_global_rect().get_center().distance_to(card.get_global_rect().get_center()) < 1, "item image exactly centered in card")
		_check(absf(card.quantity.get_global_rect().end.y - card.icon.get_global_rect().end.y) < 1, "quantity aligned to image bottom")
	for example in [[0, "00.00"], [12_340_000, "12.34"], [59_999_999, "59.99"], [60_000_000, "01:00.00"], [72_340_000, "01:12.34"]]:
		_check(ui.format_battle_time(example[0]) == example[1], "timer precision and minute rollover")
	for index in 1:
		var bag: InventoryView = ui.ally_panel.bags[index]
		_check(bag.board_texture.resource_path == "res://assets/bag-bg-%d.webp" % (index + 1), "correct skin bound by character")
		_check(bag.board_texture.get_size() == bag.board_layout.source_size, "mapping reference matches source image dimensions")
		var key := bag._get_tooltip(bag.cell_center(Vector2i(1, 1)))
		var tooltip := bag._make_custom_tooltip(key) as ItemTooltip
		_check(tooltip.description.contains("防御 +1"), "array hover uses actual armor definition")
		tooltip.free()
	var armor: StorageItemCard = ui.storage_panel.cards["run.storage.base.armor.qinglin.0"]
	var tooltip := armor._make_custom_tooltip(armor.item.id) as ItemTooltip
	_check(tooltip.description.contains("反击 1") and tooltip.description.contains("无视防御"), "counter tooltip explains trigger and true damage")
	ui.add_child(tooltip)
	tooltip.position = Vector2(650, 570)
	await _layout()
	_check(tooltip.get_global_rect().end.x <= ui.size.x and tooltip.get_global_rect().end.y <= ui.size.y, "detailed item panel fits viewport")
	await _capture("v06_counter_tooltip")
	ui.remove_child(tooltip)
	tooltip.free()
	var entry_card: StorageItemCard = ui.storage_panel.cards["run.storage.base.armor.xuantie.0"]
	var entry_tip := entry_card._make_custom_tooltip(entry_card.item.id) as ItemTooltip
	_check(entry_tip.description.contains("防御 +2") and entry_tip.description.contains("增加 2 防御"), "entry tooltip separates base and entry bonus")
	entry_tip.free()
	if DisplayServer.get_name() == "headless":
		_mouse_motion(armor.get_global_rect().get_center())
		await create_timer(0.9).timeout
		var native_tip := _find_tooltip(root)
		_check(native_tip != null, "native mouse hover opens custom tooltip")
		if native_tip != null:
			_check(native_tip.description.contains("反击"), "native tooltip is the hovered item")
			_check(native_tip.get_parent().get_theme_stylebox("panel") is StyleBoxEmpty, "native tooltip wrapper has no outer panel")
		_mouse_motion(Vector2(20, 20))
		await _layout()

func _find_tooltip(node: Node) -> ItemTooltip:
	if node is ItemTooltip:
		return node
	for child in node.get_children(true):
		var found := _find_tooltip(child)
		if found != null:
			return found
	return null

func _right_click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		Input.parse_input_event(event)

func _test_drag_presentation() -> void:
	var bag: InventoryView = ui.ally_panel.bags[0]
	var card: StorageItemCard = ui.storage_panel.cards["run.storage.base.weapon.qingfeng.0"]
	var data := card.drag_data()
	var holder := card._make_drag_preview()
	ui.add_child(holder)
	var preview := holder.get_child(0) as ItemDragPreview
	holder.position = ui.get_global_transform().affine_inverse() * card.get_global_rect().get_center()
	_check(holder.z_index > ui.storage_panel.z_index, "dragged item is drawn above storage panel")
	await _capture("storage_drag_pickup")
	var footprint := bag.board_layout.footprint_rect(Vector2i(3, 0), card.item.grid_size, bag.size)
	var point := footprint.get_center() + Vector2(3, 2)
	_check(bag._can_drop_data(point, data) and bag._hover_cell == Vector2i(3, 0), "storage hover selects nearest footprint by item center")
	_check(preview.size.is_equal_approx(footprint.size), "drag preview uses actual target board footprint size")
	_check(preview.entry["units"].size() == 1, "storage preview carries one unit rather than entire storage stock")
	holder.position = ui.get_global_transform().affine_inverse() * (bag.get_global_transform() * point)
	await _capture("array_drag_valid")
	point = bag.board_layout.footprint_rect(Vector2i(1, 1), card.item.grid_size, bag.size).get_center()
	_check(not bag._can_drop_data(point, data) and not bag._hover_valid, "occupied nearest cells show rejection rather than jumping elsewhere")
	holder.position = ui.get_global_transform().affine_inverse() * (bag.get_global_transform() * point)
	await _capture("array_drag_blocked")
	_check(ui.storage_panel.z_index > ui.enemy_panel.cards[0].stat_icons["hp"].z_index, "storage layer covers elevated enemy resource icons")
	holder.free()
	bag.reset_interaction()

func _native_between(start: Vector2, finish: Vector2, immediate_preview: bool = false) -> void:
	_mouse_motion(start)
	_mouse_button(start, true)
	await process_frame
	if immediate_preview:
		await process_frame
		_check_drag_preview_center(root, start)
	_mouse_motion(start + Vector2(32, 0), true)
	await process_frame
	_check_drag_preview_center(root, start + Vector2(32, 0))
	_mouse_motion(finish, true)
	await process_frame
	_mouse_button(finish, false)
	await _layout()

func _move_all_bags() -> void:
	for index in manager.party.size():
		var bag: InventoryView = ui.ally_panel.bags[index]
		for move in [[Vector2i.ZERO, Vector2i(3, 2), GameManager.sword_instance(index)], [Vector2i(1, 1), Vector2i(0, 2), GameManager.armor_instance(index)]]:
			if DisplayServer.get_name() == "headless":
				await _native_drag(bag, move[0], move[1])
			else:
				var data := bag.drag_data_at(bag.cell_center(move[0]))
				var item := manager.registry.get_item(bag.inventory.get_instance(move[2])["item_id"])
				bag._drop_data(bag.board_layout.footprint_rect(move[1], item.grid_size, bag.size).get_center(), data)
			_check(manager.party[index].inventory.get_instance(move[2])["cell"] == move[1], "own equipment moves directly in bag %d" % index)
		var invalid := bag.drag_data_at(bag.cell_center(Vector2i(0, 2)))
		_check(not bag._can_drop_data(bag.cell_center(Vector2i(3, 3)), invalid), "invalid footprint rejected in each bag")
		manager.move_item(index, GameManager.armor_instance(index), Vector2i(1, 1))
		manager.move_item(index, GameManager.sword_instance(index), Vector2i.ZERO)
		bag.reset_interaction()
	_check(ui.enemy_panel.bags[0].drag_data_at(ui.enemy_panel.bags[0].cell_center(Vector2i(1, 1))).is_empty(), "enemy inventory always read-only")

func _check_layout() -> void:
	var emblem: TextureRect = ui.get_node("BattleEmblem")
	_check(emblem.size.is_equal_approx(Vector2(240, 240)) and (emblem.position + emblem.size * 0.5).is_equal_approx(ui.size * 0.5 + Vector2(0, -20)), "battle emblem stays centered above screen midpoint")
	_check(absf(ui._time.get_global_rect().get_center().x - ui.size.x / 2) < 1, "timer centered on viewport")
	_check(ui.enemy_panel.get_global_rect().end.x <= ui.size.x + 1, "both teams fit width")
	_check(ui.enemy_panel.bags[0].get_global_rect().end.y <= ui.size.y + 1, "bags fit viewport height")
	for panel in [ui.ally_panel, ui.enemy_panel]:
		for card in panel.cards:
			var portrait_rect: Rect2 = card._portrait_slot.get_global_rect() if card._portrait_slot != null else card.portrait.get_global_rect()
			_check(not card._title.visible and absf(card.resources.get_global_rect().get_center().y - portrait_rect.get_center().y) < 1, "resource group vertically centered and title hidden")
			_check(card.stat_icons.size() == 3, "resource names replaced with three icons")
		_check(panel.cards.size() == 1 and panel.bags.size() == 1, "exactly one main and array per side")
		var board: Rect2 = panel.bags[0].get_global_rect()
		_check(absf(board.get_center().x - panel.get_global_rect().get_center().x) < 1, "single array centered")
		if panel.companion_cards.is_empty():
			_check(absf(panel.cards[0].get_global_rect().get_center().x - panel.get_global_rect().get_center().x) < 1, "solo main portrait remains centered")
		else:
			_check(panel.companion_cards[0].get_global_rect().end.x < panel.cards[0].global_position.x, "companions on left of main")
			if panel.companion_cards.size() == 2:
				_check(panel.companion_cards[1].global_position.y > panel.companion_cards[0].get_global_rect().end.y and is_equal_approx(panel.companion_cards[0].global_position.x, panel.companion_cards[1].global_position.x), "companions form a vertical column")
		for companion in panel.companion_cards:
			_check(companion.portrait_card.resources == null and companion.slots.size() == 2, "support portrait has two trait slots and no resource bars")
			_check(companion.get_global_rect().end.x <= panel.get_global_rect().end.x and companion.get_global_rect().end.y <= board.position.y, "support fits above array")
	_check(ui._speed_buttons[2.0].get_global_rect().end.x <= ui.size.x and ui._pause_button.global_position.x > ui.size.x * 0.75, "playback buttons moved to right side")
	var item := manager.registry.get_item("base.pill.huichun")
	var footprint: Rect2 = ui.ally_panel.bags[0].board_layout.footprint_rect(Vector2i(3, 3), Vector2i.ONE, ui.ally_panel.bags[0].size).grow(-4)
	var ring := InventoryView.rotation_ring_center(footprint, item)
	_check(ring.x + 23 < footprint.end.x - 28, "medicine countdown stays clear of quantity badge")

func _layout() -> void:
	for frame in 4:
		await process_frame
	ui._refresh()

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _layout()
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://artifacts/%s.png" % name) == OK, "render " + name)

func _key(code: Key, echo_event: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.echo = echo_event
	root.push_input(event, true)
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.keycode = code
	root.push_input(release, true)

func _native_drag(bag: InventoryView, from: Vector2i, to: Vector2i) -> void:
	var start := bag.get_global_transform() * bag.cell_center(from)
	var item := manager.registry.get_item(bag.inventory.get_instance(bag.inventory.item_at(from))["item_id"])
	var finish := bag.get_global_transform() * bag.board_layout.footprint_rect(to, item.grid_size, bag.size).get_center()
	_mouse_motion(start)
	_mouse_button(start, true)
	await process_frame
	_mouse_motion(start + Vector2(32, 0), true)
	await process_frame
	_check_drag_preview_center(root, start + Vector2(32, 0))
	_mouse_motion(finish, true)
	await process_frame
	_mouse_button(finish, false)
	await process_frame

func _check_drag_preview_center(node: Node, pointer: Vector2) -> bool:
	if node.name == "CenteredItemDragPreview":
		var preview := node.get_child(0) as ItemDragPreview
		_check(preview.get_global_rect().get_center().distance_to(pointer) < 1, "native dragged image centered on mouse")
		return true
	for child in node.get_children(true):
		if _check_drag_preview_center(child, pointer):
			return true
	if node == root:
		_check(false, "native drag preview exists")
	return false

func _mouse_motion(point: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(32, 0)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)

func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
