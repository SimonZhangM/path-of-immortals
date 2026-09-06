extends Control

const INK := Color("ece4cd")
const MUTED := Color("b2bdb6")
const JADE := Color("91c6b0")
const GOLD := Color("dfc28a")
@onready var manager: GameManager = $"../GameManager"
var ally_panel: TeamPanel
var enemy_panel: TeamPanel
var _time: Label
var _header_separator: HSeparator
var _status: Label
var _pause: Button
var _start: Button
var _formation: Button
var _log_label: RichTextLabel
var _phase_label: Label
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
	header.custom_minimum_size.y = 72
	root.add_child(header)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 0)
	header.add_child(identity)
	_label(identity, "修仙之路", 36, GOLD)
	_phase_label = _label(identity, "战前准备", 18, JADE)
	_time = _label(header, "00:00.00", 32, GOLD)
	_time.anchor_left = 0.5
	_time.anchor_right = 0.5
	_time.anchor_bottom = 1.0
	_time.offset_left = -85
	_time.offset_right = 85
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var speeds := HBoxContainer.new()
	speeds.anchor_left = 0.5
	speeds.anchor_right = 1.0
	speeds.offset_left = 110
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
	_formation = _button(middle, "", _toggle_formation)
	_start = _button(middle, "开始战斗 [空格]", manager.start_battle)
	_pause = _button(middle, "暂停 [空格]", manager.toggle_pause)
	_button(middle, "重新布阵", manager.restart)
	_status = _label(middle, "", 17, GOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(middle, "战斗记录", 18, INK)
	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size = Vector2(182, 290)
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.add_theme_stylebox_override("normal", _box(Color("14242a", 0.9), Color("4a5b58")))
	_log_label.add_theme_font_size_override("normal_font_size", 14)
	_log_label.scroll_following = true
	_log_label.add_theme_color_override("default_color", MUTED)
	middle.add_child(_log_label)
	enemy_panel = TeamPanel.new()
	arena.add_child(enemy_panel)
	if manager.startup_error.is_empty():
		enemy_panel.configure(manager, true)

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
	_pause.text = "继续 [空格]" if sim.clock.paused else "暂停 [空格]"
	_formation.text = FormationRules.label(manager.party.size(), manager.formation) + (" · 切换" if manager.party.size() == 3 else "")
	_formation.disabled = not preparing or manager.party.size() != 3
	_phase_label.text = "战前准备 · 可整理背包" if preparing else ("战斗已暂停 · 背包锁定" if sim.clock.paused and fighting else ("战斗进行中" if fighting else "战斗结束"))
	for speed in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(is_equal_approx(speed, sim.clock.speed_multiplier))
	if preparing:
		_status.text = "准备就绪后开战"
	elif state.is_finished():
		_status.text = "%s\n%.2f 游戏秒" % [{"victory": "战斗胜利", "defeat": "战斗失败", "draw": "平局 · 无法继续攻击"}[state.result], seconds]
	else:
		_status.text = "战斗已暂停" if sim.clock.paused else "战斗进行中"

func _toggle_formation() -> void:
	manager.set_formation(FormationRules.Kind.FRONT_TWO if manager.formation == FormationRules.Kind.FRONT_ONE else FormationRules.Kind.FRONT_ONE)

func _on_restart() -> void:
	_battle_log.reset()
	_log_label.text = "布阵中。"
	_refresh()

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
