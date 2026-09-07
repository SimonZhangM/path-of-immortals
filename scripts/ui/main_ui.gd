extends Control

const INK := Color("ece4cd")
const MUTED := Color("b2bdb6")
const JADE := Color("91c6b0")
const GOLD := Color("dfc28a")
@onready var manager: GameManager = $"../GameManager"
var ally_panel: TeamPanel
var enemy_panel: TeamPanel
var _time: Label
var _timer_frame: PanelContainer
var _header_separator: HSeparator
var _status: Label
var _bag_button: Button
var _log_button: Button
var _log_panel: PanelContainer
var storage_panel: StoragePanel
var _log_label: RichTextLabel
var _speed_buttons: Dictionary = {}
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
	manager.battle_started.connect(_on_started)
	_on_restart()

func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 18
	ui_theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Noto Sans SC", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_color", "Button", INK)
	ui_theme.set_color("font_shadow_color", "Label", Color("000000", 0.85))
	ui_theme.set_constant("shadow_offset_x", "Label", 1)
	ui_theme.set_constant("shadow_offset_y", "Label", 1)
	ui_theme.set_stylebox("normal", "Button", _box(Color("182a2a", 0.88), Color("62706a")))
	ui_theme.set_stylebox("hover", "Button", _box(Color("37504b"), GOLD))
	ui_theme.set_stylebox("pressed", "Button", _box(Color("466054"), GOLD))
	ui_theme.set_stylebox("disabled", "Button", _box(Color("1b282d"), Color("374447")))
	theme = ui_theme
	var backdrop: Control = load("res://scripts/ui/battle_backdrop.gd").new()
	backdrop.name = "BattleBackground"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 27)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var header := Control.new()
	header.custom_minimum_size.y = 78
	root.add_child(header)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 0)
	header.add_child(identity)
	_label(identity, "修仙之路", 36, GOLD)
	_timer_frame = PanelContainer.new()
	_timer_frame.anchor_left = 0.5
	_timer_frame.anchor_right = 0.5
	_timer_frame.offset_left = -140
	_timer_frame.offset_right = 140
	_timer_frame.offset_bottom = 50
	var timer_box := _box(Color("292119", 0.97), Color("826039"))
	timer_box.set_corner_radius_all(12)
	timer_box.content_margin_top = 2
	timer_box.content_margin_bottom = 2
	timer_box.content_margin_left = 22
	timer_box.content_margin_right = 22
	_timer_frame.add_theme_stylebox_override("panel", timer_box)
	header.add_child(_timer_frame)
	var timer_row := HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 14)
	_timer_frame.add_child(timer_row)
	_timer_accent(timer_row)
	_time = _label(timer_row, "00.00", 30, Color("f1dca6"))
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_accent(timer_row)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status = _label(header, "", 17, GOLD)
	_status.anchor_left = 0.5
	_status.anchor_right = 0.5
	_status.offset_left = -200
	_status.offset_right = 200
	_status.offset_top = 53
	_status.offset_bottom = 78
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var speeds := HBoxContainer.new()
	speeds.anchor_left = 0.5
	speeds.anchor_right = 1.0
	speeds.offset_left = 160
	speeds.offset_top = 11
	speeds.add_theme_constant_override("separation", 12)
	header.add_child(speeds)
	_label(speeds, "战斗速度", 20, MUTED)
	var captions := ["F1  半速 0.5×", "F2  正常 1×", "F3  2×"]
	for index in SimulationClock.SPEEDS.size():
		var speed: float = SimulationClock.SPEEDS[index]
		var button := _button(speeds, captions[index], manager.set_speed.bind(speed))
		button.toggle_mode = true
		_speed_buttons[speed] = button
	_header_separator = HSeparator.new()
	root.add_child(_header_separator)
	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 20)
	root.add_child(arena)
	ally_panel = TeamPanel.new()
	arena.add_child(ally_panel)
	if manager.startup_error.is_empty():
		ally_panel.configure(manager, false)
	var middle := VBoxContainer.new()
	middle.custom_minimum_size.x = 182
	middle.add_theme_constant_override("separation", 14)
	arena.add_child(middle)
	var spacing := Control.new()
	spacing.custom_minimum_size.y = 125
	middle.add_child(spacing)
	var duel := _label(middle, "对 阵", 27, GOLD)
	duel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stretch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(stretch)
	_bag_button = _button(middle, "背包调整", func(): manager.set_adjustment(not manager.adjustment_open))
	_log_button = _button(middle, "战斗记录", func(): _log_panel.visible = not _log_panel.visible)
	enemy_panel = TeamPanel.new()
	arena.add_child(enemy_panel)
	if manager.startup_error.is_empty():
		enemy_panel.configure(manager, true)
	_build_log()
	if manager.startup_error.is_empty():
		storage_panel = StoragePanel.new()
		storage_panel.anchor_left = 1
		storage_panel.anchor_right = 1
		storage_panel.anchor_bottom = 1
		storage_panel.offset_left = -849
		storage_panel.offset_right = -27
		storage_panel.offset_top = 128
		storage_panel.offset_bottom = -27
		add_child(storage_panel)
		storage_panel.configure(manager)

func _build_log() -> void:
	_log_panel = PanelContainer.new()
	_log_panel.z_index = 20
	_log_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_log_panel.offset_left = -365
	_log_panel.offset_right = 365
	_log_panel.offset_top = -330
	_log_panel.offset_bottom = 330
	_log_panel.add_theme_stylebox_override("panel", _box(Color("101b21", 0.98), GOLD))
	add_child(_log_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_log_panel.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	_label(row, "战斗记录", 24, GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row, "关闭 ×", func(): _log_panel.hide())
	_log_label = RichTextLabel.new()
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_font_size_override("normal_font_size", 18)
	_log_label.scroll_following = true
	_log_label.add_theme_color_override("default_color", MUTED)
	column.add_child(_log_label)
	_log_panel.hide()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if manager.simulation == null:
		return
	var sim := manager.simulation
	var state := sim.state
	var preparing := state.phase == GameState.Phase.PREPARATION
	var fighting := state.phase == GameState.Phase.BATTLE
	_time.text = format_battle_time(state.time_usec)
	_bag_button.disabled = not manager.can_adjust()
	_bag_button.text = "关闭背包" if manager.adjustment_open else "背包调整"
	for speed in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(is_equal_approx(speed, sim.clock.speed_multiplier))
	if preparing:
		_status.text = "战前准备 · 空格开始"
	elif state.is_finished():
		_status.text = {"victory": "战斗胜利", "defeat": "战斗失败", "draw": "平局 · 无法继续攻击"}[state.result]
	else:
		_status.text = "战斗已暂停" if sim.clock.paused else "战斗进行中"

func _on_restart() -> void:
	_battle_log.reset()
	_log_label.text = "布阵中。"
	_refresh()

static func format_battle_time(time_usec: int) -> String:
	var centiseconds := time_usec / 10_000
	var seconds := centiseconds / 100
	var suffix := "%02d.%02d" % [seconds % 60, centiseconds % 100]
	return "%02d:%s" % [seconds / 60, suffix] if seconds >= 60 else suffix

func _timer_accent(parent: Node) -> void:
	var accent := HSeparator.new()
	accent.custom_minimum_size.x = 26
	accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := StyleBoxLine.new()
	line.color = Color("c29a58", 0.6)
	line.thickness = 1
	accent.add_theme_stylebox_override("separator", line)
	parent.add_child(accent)

func _on_started() -> void:
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
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _box(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
