extends Control

const INK := Color("e5ecea")
const MUTED := Color("9cadaa")
const JADE := Color("7fd6b0")
const GOLD := Color("edc78b")

@onready var manager: GameManager = $"../GameManager"
var _hp: Label
var _hp_bar: ProgressBar
var _cooldown: Label
var _cooldown_bar: ProgressBar
var _time: Label
var _status: Label
var _stats: Label
var _pause: Button
var _log_label: RichTextLabel
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
	manager.presentation_events.connect(_on_events)
	manager.battle_restarted.connect(_on_restart)
	_on_restart()

func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 26
	# Use installed CJK fonts without redistributing proprietary font files.
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Noto Sans SC", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_color", "Button", INK)
	ui_theme.set_stylebox("normal", "Button", _box(Color("223933"), Color("426156")))
	ui_theme.set_stylebox("hover", "Button", _box(Color("304e43"), JADE))
	ui_theme.set_stylebox("pressed", "Button", _box(Color("355e4d"), JADE))
	ui_theme.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, GOLD))
	theme = ui_theme
	var background := ColorRect.new()
	background.color = Color("101c1a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 40)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 22)
	scroll.add_child(root)
	_label(root, "修仙之路", 48, INK)
	_label(root, "初入仙途  /  法器试炼", 25, JADE)
	_label(root, "一柄玄火剑，一座木桩。观其轮转，试其锋芒。", 25, MUTED)
	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 14)
	toolbar.add_theme_constant_override("v_separation", 10)
	root.add_child(toolbar)
	_time = _label(toolbar, "", 28, GOLD)
	_time.custom_minimum_size.x = 350
	for speed in SimulationClock.SPEEDS:
		var button := _button(toolbar, "%d×" % speed, manager.set_speed.bind(speed))
		button.toggle_mode = true
		_speed_buttons[speed] = button
	_pause = _button(toolbar, "暂停", manager.toggle_pause)
	_button(toolbar, "重新开始", manager.restart)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 24)
	root.add_child(cards)
	var item_card := _panel(cards)
	var enemy_card := _panel(cards)
	var item := manager.registry.get_item(GameManager.ITEM_ID)
	var enemy := manager.registry.get_enemy(GameManager.ENEMY_ID)
	_label(item_card, "法 器", 23, JADE)
	_label(item_card, item.display_name if item != null else "法器未加载", 34, INK)
	if item != null:
		var damage := 0
		for effect in item.effects:
			damage += int(effect["value"])
		_label(item_card, "每 %.1f 游戏秒发动 · 造成 %d 点伤害" % [item.cooldown_usec / 1_000_000.0, damage], 25, MUTED)
	_cooldown_bar = _bar(item_card, GOLD)
	_cooldown = _label(item_card, "", 25, GOLD)
	_label(enemy_card, "试炼目标", 23, JADE)
	_label(enemy_card, str(enemy.get("name", "敌人未加载")), 34, INK)
	_hp = _label(enemy_card, "", 28, INK)
	_hp_bar = _bar(enemy_card, JADE)
	_status = _label(enemy_card, "", 25, JADE)
	_stats = _label(root, "", 26, MUTED)
	var log_panel := _panel(root)
	_label(log_panel, "战斗记录", 28, INK)
	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size.y = 200
	_log_label.scroll_following = true
	_log_label.add_theme_font_size_override("normal_font_size", 24)
	_log_label.add_theme_color_override("default_color", MUTED)
	log_panel.add_child(_log_label)
	_label(root, "V0.1 · 基础试炼    |    倍速改变游戏时间；暂停与重新开始随时可用。", 22, MUTED)

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if manager.simulation == null:
		return
	var sim := manager.simulation
	var state := sim.state
	var item := manager.registry.get_item(state.item_id)
	_time.text = "游戏时间  %06.2f 秒" % (state.time_usec / 1_000_000.0)
	_pause.text = "继续" if sim.clock.paused else "暂停"
	for speed in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(speed == sim.clock.speed_multiplier)
	if state.is_finished():
		_cooldown.text = "本轮试炼结束"
		_cooldown_bar.value = 0
		_status.text = "已击破 · 耗时 %.2f 游戏秒" % (state.defeated_at_usec / 1_000_000.0)
	else:
		var remaining := maxi(0, state.next_activation_usec - state.time_usec)
		_cooldown.text = "下次发动  %.2f 秒" % (remaining / 1_000_000.0)
		_cooldown_bar.value = 100.0 * (1.0 - float(remaining) / item.cooldown_usec)
		_status.text = "试炼已暂停" if sim.clock.paused else "试炼进行中 · %d×" % sim.clock.speed_multiplier
	if state.revision != _last_revision:
		_last_revision = state.revision
		var max_hp := int(manager.registry.get_enemy(state.enemy_id)["max_hp"])
		_hp.text = "气血  %d / %d" % [state.enemy_hp, max_hp]
		_hp_bar.value = 100.0 * state.enemy_hp / max_hp
		_stats.text = "法器发动  %d 次       累计伤害  %d" % [state.activation_count, state.damage_total]

func _on_restart() -> void:
	_last_revision = -1
	_battle_log.reset()
	_log_label.text = _battle_log.consume([], manager.registry)
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

func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.disabled = not manager.startup_error.is_empty()
	button.custom_minimum_size = Vector2(100, 54)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("192b26"), Color("32483f"), 24))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	return column

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 18
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _box(Color("0c1915"), Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", _box(color, Color.TRANSPARENT, 0))
	parent.add_child(bar)
	return bar

func _box(color: Color, border: Color, padding: int = 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box
