extends SceneTree

const Bonuses := preload("res://scripts/map/map_buff_bonuses.gd")
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

func _capture(file: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/" + file + ".png")

func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children(true):
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null

func _run() -> void:
	_check(Bonuses.valid({}) and Bonuses.valid({"shield": 1.5}), "optional and fractional bonuses accepted")
	for bad in [{"other": 1}, {"armor": -1}, {"flame": "3"}, {"shield": INF}, []]:
		_check(not Bonuses.valid(bad), "malformed bonuses rejected")
	var totals := Bonuses.sum_sources({"buff_bonuses": {"shield": 2}}, {"shield": 3.5}, [{"buff_bonuses": {"shield": 4, "flame": 3}, "armor_capacity": 12, "armor_gain": 99}])
	_check(totals.shield == 9.5 and totals.flame == 3 and totals.armor == 12, "three additive sources; armor capacity not timed refill")
	_check(totals.thunder == 0 and totals.size() == 9, "all nine keys present including zero")
	root.size = Vector2i(1920, 1080)
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	root.add_child(map)
	_check(map.startup_error.is_empty(), "map starts with isolated inventory")
	map.set_inventory_open(true)
	await _settle()
	var panel: MapInventoryScreen = map.inventory_screen
	_check(panel.sidebar.size.y == 910 and panel.sidebar.size.x == 208, "expanded content preserves panel geometry")
	var motto := _find_named(panel.sidebar, "SidebarMotto")
	_check(motto.get_child(0) is Label and motto.get_child(1) is HSeparator, "motto now above its separator")
	var rows := _find_named(panel.sidebar, "BoardResourceBonuses")
	_check(rows.get_child_count() == 14 and rows.get_child(6) is HSeparator, "three resources, cultivation, armor/shield, separator, seven buffs")
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/map_buffs.json"))
	for buff: Dictionary in definitions:
		var icon = _find_named(panel.sidebar, "BuffIcon_" + buff.id)
		var label_group = _find_named(panel.sidebar, "AttributeLabel_" + buff.id)
		_check(icon != null and label_group.meaning == buff.description, "exact supplied tooltip copy for " + buff.id)
		_check(icon.texture.get_image().has_mipmaps(), "mipmapped icon for " + buff.id)
		_check(panel.buff_bonus_values[buff.id].text == "+0", "unconfigured bonus is zero for " + buff.id)
		var tip: ItemTooltip = label_group._make_custom_tooltip(label_group.tooltip_text)
		_check(tip.description == buff.description and tip.find_child("ItemPortrait", true, false) == null and tip.find_child("KeywordPanel", true, false) == null, "description-only tooltip for " + buff.id)
		var line: RichTextLabel = tip.find_child("EffectDescriptionLine0", true, false)
		_check(line.get_theme_font_size("normal_font_size") == 23 and line.get_theme_font("normal_font").font_names[0] == "KaiTi", "shared item-body typography")
		tip.free()
	for key in ["hp", "stamina", "spirit", "cultivation"] + Bonuses.KEYS:
		var label_group: Control = _find_named(panel.sidebar, "AttributeLabel_" + key)
		_check(label_group.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "hand cursor for " + key)
		_check(label_group.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE and label_group.get_child(1).mouse_filter == Control.MOUSE_FILTER_IGNORE, "icon and caption share one hover owner")
		_check(label_group.global_position.x == panel.sidebar.global_position.x + 27, "icon/name column shifts5px")
		var value: Label = panel.cultivation_bonus_value if key == "cultivation" else (panel.board_bonus_values[key] if panel.board_bonus_values.has(key) else panel.buff_bonus_values[key])
		_check(value.global_position.x == panel.sidebar.global_position.x + 132, "value column shifts left10px from original position")
		if key in ["hp", "stamina", "spirit"]:
			_check(not label_group.tooltip_text.is_empty(), "resource explanation present")
	var last: Label = panel.buff_bonus_values.thunder
	_check(last.get_global_rect().end.y <= panel.sidebar.get_global_rect().end.y - 22, "last buff stays inside padded sidebar")
	await _capture("inventory_buffs_all")
	# Test real loadout mutations without exercising unrelated drag mechanics.
	var armor: Dictionary = panel.loadout.storage.entries().filter(func(e): return e.item_id.ends_with("coarse_cloth_armor"))[0]
	_check(panel.loadout.place(panel.loadout.drag_data("storage", armor.instance_id), Vector2i.ZERO), "equip armor")
	_check(panel.buff_bonus_values.armor.text == "+" + EffectSystem.number_text(panel.loadout.records[armor.item_id].armor_capacity), "armor capacity updates immediately")
	_check(panel.loadout.take_back(panel.loadout.drag_data("board", armor.instance_id)), "remove armor")
	_check(panel.buff_bonus_values.armor.text == "+0", "removing armor removes capacity")
	var rank_id: String = map.player_status.cultivation_rank_id
	panel.loadout.registry._cultivation[rank_id]["buff_bonuses"] = {"shield": 2}
	panel.loadout.board.buff_bonuses = {"shield": 3.5}
	var jade: Dictionary = panel.loadout.storage.entries().filter(func(e): return e.item_id.ends_with("warm_jade"))[0]
	panel.loadout.records[jade.item_id]["buff_bonuses"] = {"shield": 4}
	map.player_status.changed.emit()
	_check(panel.buff_bonus_values.shield.text == "+5.5", "storage item contributes nothing; rank and board do")
	_check(panel.loadout.place(panel.loadout.drag_data("storage", jade.instance_id), Vector2i.ZERO), "equip bonus item")
	_check(panel.buff_bonus_values.shield.text == "+9.5", "rank board and equipped item aggregate without rounding")
	_check(panel.loadout.take_back(panel.loadout.drag_data("board", jade.instance_id)), "remove bonus item")
	_check(panel.buff_bonus_values.shield.text == "+5.5", "unequipped item excluded again")
	panel.loadout.registry._cultivation[rank_id].erase("buff_bonuses")
	panel.loadout.board.buff_bonuses.clear()
	map.player_status.changed.emit()
	# Only the newly requested icon hover is tested, without item/formation hover suites.
	var target: Control = _find_named(panel.sidebar, "AttributeLabel_counter")
	await _settle()
	var motion := InputEventMouseMotion.new()
	motion.position = target.get_global_rect().get_center()
	if DisplayServer.get_name() == "headless":
		for sample in [["hp", 0], ["stamina", 1], ["spirit", 1], ["counter", 0], ["counter", 1]]:
			var hover_group: Control = _find_named(panel.sidebar, "AttributeLabel_" + sample[0])
			motion = InputEventMouseMotion.new()
			motion.position = hover_group.get_child(sample[1]).get_global_rect().get_center()
			root.push_input(motion, true)
			await create_timer(0.7).timeout
			_check(root.gui_get_hovered_control() == hover_group, "icon/name share hover target for " + sample[0])
			var shown = _find_named(root, "BuffTooltip")
			_check(shown != null and shown.description == hover_group.tooltip_text, "correct tooltip opens for " + sample[0])
			motion = InputEventMouseMotion.new()
			motion.position = Vector2(950, 100)
			root.push_input(motion, true)
			await _settle()
			_check(_find_named(root, "BuffTooltip") == null, "tooltip closes after leaving icon/name")
	else:
		# Rendering is independent of the user's physical mouse position.
		var preview: ItemTooltip = target._make_custom_tooltip(target.tooltip_text)
		root.add_child(preview)
		preview.z_index = 100
		preview.position = Vector2(250, 730)
		await _settle()
		_check(preview.size.x == 540 and preview.size.y < 180, "compact body-only tooltip geometry")
		await _capture("inventory_buff_hover")
		preview.queue_free()
	map.queue_free()
	await _settle()
	ItemTooltip._body_font = null
	ItemTooltip._term_font = null
	print("BUFF SIDEBAR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
