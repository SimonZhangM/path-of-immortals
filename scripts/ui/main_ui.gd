extends Control

const INK := Color("ece4cd")
const MUTED := Color("9caba7")
const JADE := Color("91c6b0")
const GOLD := Color("dfc28a")
const RED := Color("cd8470")

@onready var manager: GameManager = $"../GameManager"
var inventory_view: InventoryView
var _hp: Label
var _hp_bar: ProgressBar
var _player_hp: Label
var _cooldown: Label
var _cooldown_bar: ProgressBar
var _time: Label
var _status: Label
var _stats: Label
var _pause: Button
var _start: Button
var _log_label: RichTextLabel
var _layout_hint: Label
var _selection: Label
var _phase_label: Label
var _bag_usage: Label
var _speed_buttons: Dictionary = {}
var _last_revision: int = -1
var _battle_log := BattleLog.new()

func _ready() -> void:
	_build_ui()
	if not manager.startup_error.is_empty():
		_status.text = "内容加载失败"
		_log_label.text = manager.startup_error
		set_process(false)
		return
	inventory_view.bind_game(manager)
	inventory_view.selection_changed.connect(_show_item)
	inventory_view.feedback.connect(func(message: String): _layout_hint.text = message)
	manager.presentation_events.connect(_on_events)
	manager.battle_restarted.connect(_on_restart)
	manager.battle_started.connect(_on_started)
	_on_restart()

func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 28
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Noto Sans SC", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_color", "Button", INK)
	ui_theme.set_stylebox("normal", "Button", _box(Color("243738"), Color("62706a")))
	ui_theme.set_stylebox("hover", "Button", _box(Color("37504b"), GOLD))
	ui_theme.set_stylebox("pressed", "Button", _box(Color("466054"), GOLD))
	ui_theme.set_stylebox("disabled", "Button", _box(Color("1b282d"), Color("374447")))
	theme = ui_theme
	var backdrop: Control = load("res://scripts/ui/battle_backdrop.gd").new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 36)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	margin.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 32)
	root.add_child(header)
	_label(header, "修仙之路", 48, GOLD)
	var identity := _column(header, 8)
	_label(identity, "无名修士   /   炼气初期", 27, INK)
	_label(identity, "演武场 · 初试锋芒", 23, MUTED)
	_spacer(header)
	_label(header, "法器构筑    /    V0.2", 25, MUTED)
	root.add_child(HSeparator.new())
	var clock_row := HBoxContainer.new()
	root.add_child(clock_row)
	_phase_label = _label(clock_row, "战前准备", 28, JADE)
	_spacer(clock_row)
	_time = _label(clock_row, "00:00.00", 42, GOLD)
	_spacer(clock_row)
	_label(clock_row, "演武木桩 · 无反击", 27, MUTED)
	var arena := HBoxContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", 40)
	root.add_child(arena)
	var left := _column(arena, 22)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var player_header := HBoxContainer.new()
	player_header.add_theme_constant_override("separation", 32)
	left.add_child(player_header)
	_portrait(player_header, "res://assets/images/characters/cultivator.svg", Vector2(230, 250))
	var player_info := _column(player_header)
	player_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(player_info, "我方修士", 38, INK)
	_label(player_info, "炼气初期", 28, GOLD)
	_player_hp = _label(player_info, "气血  100 / 100", 26, JADE)
	_bar(player_info, JADE).value = 100
	_label(player_info, "法器自动战斗", 24, MUTED)
	var bag_heading := HBoxContainer.new()
	left.add_child(bag_heading)
	_label(bag_heading, "储物袋", 34, GOLD)
	_spacer(bag_heading)
	_bag_usage = _label(bag_heading, "", 25, MUTED)
	var bag_row := HBoxContainer.new()
	bag_row.add_theme_constant_override("separation", 24)
	left.add_child(bag_row)
	inventory_view = InventoryView.new()
	inventory_view.name = "Backpack"
	bag_row.add_child(inventory_view)
	var description := _column(bag_row, 20)
	description.custom_minimum_size.x = 290
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(description, "装备详情", 27, JADE)
	_selection = _label(description, "", 25, INK)
	_selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection.custom_minimum_size.y = 260
	_label(description, "法器轮转", 26, GOLD)
	_cooldown = _label(description, "待开战", 25, MUTED)
	_cooldown_bar = _bar(description, GOLD)
	var rules := _label(description, "拖动装备调整位置\n绿色：可以放置\n红色：无法放置\n\n也可点选装备后\n点击空格放置", 23, MUTED)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_layout_hint = _label(left, "拖动玄火剑和铁甲，安排你的背包。", 25, JADE)
	var middle := _column(arena, 24)
	middle.custom_minimum_size.x = 270
	_spacer(middle, true)
	var duel := _label(middle, "对 阵", 36, GOLD)
	duel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start = _button(middle, "开始战斗", manager.start_battle)
	_start.custom_minimum_size.y = 82
	_start.add_theme_stylebox_override("normal", _box(Color("625134"), GOLD))
	_pause = _button(middle, "暂停  [空格]", manager.toggle_pause)
	_button(middle, "重新布阵", manager.restart)
	_spacer(middle, true)
	var right := _column(arena, 22)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var enemy_title := _label(right, "敌 方", 28, RED)
	enemy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var portrait_center := CenterContainer.new()
	right.add_child(portrait_center)
	_portrait(portrait_center, "res://assets/images/enemies/dummy.svg", Vector2(400, 390))
	var enemy_name := _label(right, "演武木桩", 40, INK)
	enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp = _label(right, "", 28, RED)
	_hp_bar = _bar(right, RED)
	_status = _label(right, "等待开战", 27, GOLD)
	_stats = _label(right, "", 25, MUTED)
	var log_panel := _panel(right)
	_label(log_panel, "战斗记录", 27, INK)
	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size = Vector2(0, 220)
	_log_label.scroll_following = true
	_log_label.add_theme_font_size_override("normal_font_size", 24)
	_log_label.add_theme_color_override("default_color", MUTED)
	log_panel.add_child(_log_label)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 18)
	root.add_child(footer)
	_label(footer, "战斗速度", 26, MUTED)
	var captions := ["F1  半速 0.5×", "F2  正常 1×", "F3  2×"]
	for index in SimulationClock.SPEEDS.size():
		var speed: float = SimulationClock.SPEEDS[index]
		var button := _button(footer, captions[index], manager.set_speed.bind(speed))
		button.toggle_mode = true
		_speed_buttons[speed] = button
	_spacer(footer)
	_label(footer, "空格  暂停 / 恢复    ·    战斗中锁定背包", 25, MUTED)

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if manager.simulation == null:
		return
	var sim := manager.simulation
	var state := sim.state
	var preparing := state.phase == GameState.Phase.PREPARATION
	var fighting := state.phase == GameState.Phase.BATTLE
	var seconds := state.time_usec / 1_000_000.0
	_time.text = "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]
	_start.disabled = not preparing
	_pause.disabled = not fighting
	_pause.text = "继续  [空格]" if sim.clock.paused else "暂停  [空格]"
	_phase_label.text = "战前准备 · 布阵中" if preparing else ("战斗已暂停" if sim.clock.paused else ("战斗进行中" if fighting else "试炼完成"))
	for speed in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(is_equal_approx(speed, sim.clock.speed_multiplier))
	if preparing:
		_cooldown.text = "开战后开始轮转"
		_cooldown_bar.value = 0
		_status.text = "等待我方完成布阵"
	elif state.is_finished():
		_cooldown.text = "本轮试炼结束"
		_cooldown_bar.value = 0
		_status.text = "已击破 · 耗时 %.2f 游戏秒" % (state.defeated_at_usec / 1_000_000.0)
	else:
		var item := manager.registry.get_item(state.item_id)
		var remaining := maxi(0, state.next_activation_usec - state.time_usec)
		_cooldown.text = "下次发动  %.2f 秒" % (remaining / 1_000_000.0)
		_cooldown_bar.value = 100.0 * (1.0 - float(remaining) / item.cooldown_usec)
		_status.text = "战斗已暂停" if sim.clock.paused else "法器自动运转中 · %s×" % str(sim.clock.speed_multiplier)
	if state.revision != _last_revision:
		_last_revision = state.revision
		var max_hp := int(manager.registry.get_enemy(state.enemy_id)["max_hp"])
		_hp.text = "气血  %d / %d" % [state.enemy_hp, max_hp]
		_hp_bar.value = 100.0 * state.enemy_hp / max_hp
		_player_hp.text = "气血  %d / %d" % [state.player_hp, state.player_max_hp]
		_stats.text = "玄火剑发动 %d 次    /    累计伤害 %d" % [state.activation_count, state.damage_total]

func _show_item(item_id: String) -> void:
	var item := manager.registry.get_item(item_id)
	_selection.text = "%s\n\n占用 %d × %d 格\n固定方向" % [item.display_name, item.grid_size.x, item.grid_size.y]
	if item.effects.is_empty():
		_selection.text += "\n\n铁制护甲\n无主动效果"
	else:
		_selection.text += "\n\n每 %.1f 游戏秒\n造成 %d 点伤害" % [item.cooldown_usec / 1_000_000.0, int(item.effects[0]["value"])]

func _on_restart() -> void:
	_last_revision = -1
	_battle_log.reset()
	_log_label.text = "布阵中。调整装备后，点击「开始战斗」。"
	_layout_hint.text = "拖动玄火剑和铁甲，安排你的背包。"
	_bag_usage.text = "4 × 4   ·   已用 %d / 16 格" % manager.inventory.occupied_cells()
	_show_item(GameManager.ITEM_ID)
	_refresh()

func _on_started() -> void:
	_log_label.text = _battle_log.consume([], manager.registry)
	_layout_hint.text = "背包已锁定 · 重新布阵后可以调整装备"
	_refresh()

func _on_events(events: Array[Dictionary]) -> void:
	_log_label.text = _battle_log.consume(events, manager.registry)

func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _column(parent: Node, gap: int = 16) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column

func _spacer(parent: Node, vertical: bool = false) -> void:
	var spacer := Control.new()
	if vertical:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)

func _portrait(parent: Node, path: String, dimensions: Vector2) -> void:
	var portrait := TextureRect.new()
	portrait.texture = load(path)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = dimensions
	parent.add_child(portrait)

func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not manager.startup_error.is_empty()
	button.custom_minimum_size = Vector2(140, 66)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("14242a", 0.9), Color("4a5b58"), 22))
	parent.add_child(panel)
	return _column(panel)

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 20
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _box(Color("0c191e"), Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", _box(color, Color.TRANSPARENT, 0))
	parent.add_child(bar)
	return bar

func _box(color: Color, border: Color, padding: int = 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box
