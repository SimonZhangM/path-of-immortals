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
var _header_separator: Control
var _status: Label
var _bag_button: Button
var _battle_button: BattleActionButton
var _battle_icon: Texture2D
var _wait_icon: Texture2D
var _retreat_button: Button
var _settings_button: Button
var _pause_button: Button
var _retreat_dialog: Control
var _review_button: Button
var _exit_button: Button
var _review_note: Label
var _countdown: RetreatCountdown
var _log_panel: PanelContainer
var storage_panel: StoragePanel
var _log_label: RichTextLabel
var _speed_buttons: Dictionary = {}
var _battle_log := BattleLog.new()
var game_audio: GameAudio

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
	manager.battle_review_requested.connect(func(): _review_note.show())
	manager.battle_exit_requested.connect(_exit_battle)
	game_audio = GameAudio.new()
	add_child(game_audio)
	game_audio.configure(manager)
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
	margin.add_theme_constant_override("margin_top", 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var header := Control.new()
	header.custom_minimum_size.y = 106
	root.add_child(header)
	var title_backdrop := _art("res://assets/title-bg.webp")
	title_backdrop.name = "TitleBackdrop"
	title_backdrop.position = Vector2(-81, -116.0 / 6.0)
	title_backdrop.size = Vector2(520, 116.0 * 4.0 / 3.0)
	header.add_child(title_backdrop)
	var identity := _art("res://assets/title.webp")
	identity.name = "GameTitle"
	identity.size = Vector2(268, 88)
	identity.position = Vector2(36, 12)
	header.add_child(identity)
	_timer_frame = PanelContainer.new()
	_timer_frame.anchor_left = 0.5
	_timer_frame.anchor_right = 0.5
	_timer_frame.offset_left = -580.0 / 3.0
	_timer_frame.offset_right = 580.0 / 3.0
	_timer_frame.offset_top = 116.0 / 6.0
	_timer_frame.offset_bottom = 116.0 * 5.0 / 6.0
	_timer_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	header.add_child(_timer_frame)
	var timer_art := _art("res://assets/battle-time.webp")
	timer_art.name = "TimerBackground"
	_timer_frame.add_child(timer_art)
	var timer_content := MarginContainer.new()
	timer_content.add_theme_constant_override("margin_left", 32)
	timer_content.add_theme_constant_override("margin_right", 32)
	_timer_frame.add_child(timer_content)
	_time = _label(timer_content, "00.00", 39, Color("f1dca6"))
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var speeds := HBoxContainer.new()
	speeds.anchor_left = 1
	speeds.anchor_right = 1
	speeds.offset_left = -272
	speeds.offset_right = 0
	speeds.offset_top = 34
	speeds.add_theme_constant_override("separation", 8)
	header.add_child(speeds)
	_pause_button = _playback_button(speeds, "pause", "暂停", manager.pause_battle)
	_speed_buttons[0.5] = _playback_button(speeds, "half", "半速", manager.set_speed.bind(0.5))
	_speed_buttons[1.0] = _playback_button(speeds, "play", "正常播放", manager.play_normal)
	_speed_buttons[2.0] = _playback_button(speeds, "double", "2倍速", manager.set_speed.bind(2.0))
	_settings_button = _playback_button(speeds, "settings", "系统设置（暂未开放）", func(): pass)
	_settings_button.toggle_mode = false
	_settings_button.disabled = true
	_build_header_divider(root)
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
	var duel := _art("res://assets/battle-start.webp")
	duel.name = "BattleEmblem"
	duel.anchor_left = 0.5
	duel.anchor_right = 0.5
	duel.anchor_top = 0.5
	duel.anchor_bottom = 0.5
	duel.offset_left = -120
	duel.offset_right = 120
	duel.offset_top = -140
	duel.offset_bottom = 100
	add_child(duel)
	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stretch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(stretch)
	var footer := Control.new()
	footer.custom_minimum_size.y = 120
	middle.add_child(footer)
	var footer_column := VBoxContainer.new()
	footer_column.anchor_left = 0.5
	footer_column.anchor_right = 0.5
	footer_column.offset_left = -130
	footer_column.offset_right = 130
	footer_column.add_theme_constant_override("separation", 8)
	footer.add_child(footer_column)
	_battle_icon = BattleActionButton.trimmed_art("res://assets/icon-battle.webp")
	_wait_icon = BattleActionButton.trimmed_art("res://assets/icon-wait.webp")
	_battle_button = _action_button(footer_column, "res://assets/bt-button.webp", Vector2(260, 68), _toggle_battle)
	var bottom_actions := HBoxContainer.new()
	bottom_actions.add_theme_constant_override("separation", 8)
	footer_column.add_child(bottom_actions)
	_bag_button = _action_button(bottom_actions, "res://assets/bt-zhihuan.webp", Vector2(126, 44), func(): manager.set_adjustment(not manager.adjustment_open))
	_retreat_button = _action_button(bottom_actions, "res://assets/bt-chetui.webp", Vector2(126, 44), manager.request_retreat)
	_bag_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_retreat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_panel = TeamPanel.new()
	arena.add_child(enemy_panel)
	if manager.startup_error.is_empty():
		enemy_panel.configure(manager, true)
	_build_log()
	if manager.startup_error.is_empty():
		storage_panel = StoragePanel.new()
		storage_panel.z_index = 10
		storage_panel.target_board = ally_panel.bags[0]
		storage_panel.anchor_left = 1
		storage_panel.anchor_right = 1
		storage_panel.anchor_bottom = 1
		storage_panel.offset_left = -849
		storage_panel.offset_right = -27
		storage_panel.offset_top = 128
		storage_panel.offset_bottom = -27
		add_child(storage_panel)
		storage_panel.configure(manager)
	_countdown = RetreatCountdown.new()
	_countdown.theme = ui_theme
	add_child(_countdown)
	_build_retreat_dialog()

func _action_button(parent: Node, path: String, minimum: Vector2, action: Callable) -> BattleActionButton:
	var button := BattleActionButton.new()
	button.configure(path, minimum)
	parent.add_child(button)
	button.pressed.connect(func():
		if button.disabled:
			return
		if game_audio != null:
			game_audio.play("click")
		action.call()
		_refresh()
	)
	return button

func _toggle_battle() -> void:
	if manager.simulation == null:
		return
	if manager.simulation.state.phase == GameState.Phase.PREPARATION:
		manager.start_battle()
	else:
		manager.toggle_pause()

func _playback_button(parent: Node, symbol: String, caption: String, action: Callable) -> Button:
	var button := PlaybackButton.new()
	button.symbol = symbol
	button.text = "0.5x" if symbol == "half" else ""
	button.tooltip_text = caption
	button.custom_minimum_size = Vector2(48, 48)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := _box(Color("2d261f"), Color("d7b477") if state in ["hover", "pressed", "hover_pressed"] else Color("796043"))
		box.set_corner_radius_all(5)
		box.set_content_margin_all(0)
		box.set_border_width_all(2 if state in ["pressed", "hover_pressed"] else 1)
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_retreat_dialog() -> void:
	_retreat_dialog = Control.new()
	_retreat_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_retreat_dialog.z_index = 40
	add_child(_retreat_dialog)
	var shade := ColorRect.new()
	shade.color = Color("16120f", 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_retreat_dialog.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_retreat_dialog.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 230)
	var box := _box(Color("2d261f"), GOLD)
	box.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	_label(column, "已成功撤退", 28, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_review_note = _label(column, "战斗复盘尚未开放", 18, MUTED)
	_review_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_review_note.hide()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	_review_button = _button(actions, "战斗复盘", manager.request_battle_review)
	_exit_button = _button(actions, "退出战斗", manager.request_battle_exit)
	_review_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_retreat_dialog.hide()

func _exit_battle() -> void:
	if _exit_button.disabled:
		return
	_exit_button.disabled = true
	# Flush same-frame play requests before stopping all polyphonic voices.
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout
	game_audio.stop_all()
	# Let the audio mixer release active streams before closing the application.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

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
	_battle_button.disabled = state.is_finished()
	_battle_button.caption = "开始战斗" if preparing else ("战斗结束" if state.is_finished() else ("战斗继续" if sim.clock.paused else "战斗暂停"))
	_battle_button.action_icon = _wait_icon if fighting and not sim.clock.paused else _battle_icon
	for speed in _speed_buttons:
		_speed_buttons[speed].disabled = state.is_finished()
		_speed_buttons[speed].set_pressed_no_signal(not sim.clock.paused and is_equal_approx(speed, sim.clock.speed_multiplier))
	_pause_button.disabled = not fighting
	_pause_button.set_pressed_no_signal(fighting and sim.clock.paused)
	_retreat_button.disabled = not fighting or state.retreat_at_usec >= 0
	_countdown.update_remaining(state.retreat_at_usec - state.time_usec if state.retreat_at_usec >= 0 else 0)
	_retreat_dialog.visible = state.result == "retreat"
	if preparing:
		_status.text = "战前准备"
	elif state.is_finished():
		_status.text = {"victory": "战斗胜利", "defeat": "战斗失败", "draw": "平局 · 无法继续攻击", "retreat": "已成功撤退"}[state.result]
	else:
		_status.text = "战斗已暂停" if sim.clock.paused else "战斗进行中"

func _on_restart() -> void:
	if storage_panel != null and not ally_panel.bags.is_empty():
		storage_panel.target_board = ally_panel.bags[0]
	_battle_log.reset()
	_review_note.hide()
	_log_label.text = "布阵中。"
	_refresh()

static func format_battle_time(time_usec: int) -> String:
	var centiseconds := time_usec / 10_000
	var seconds := centiseconds / 100
	var suffix := "%02d.%02d" % [seconds % 60, centiseconds % 100]
	return "%02d:%s" % [seconds / 60, suffix] if seconds >= 60 else suffix

func _art(path: String) -> TextureRect:
	var source: Texture2D = load(path)
	# Ignore source padding without changing the user's image file or stretching its art.
	var trimmed := AtlasTexture.new()
	trimmed.atlas = source
	trimmed.region = source.get_image().get_used_rect()
	var view := TextureRect.new()
	view.texture = trimmed
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

func _on_started() -> void:
	_log_label.text = _battle_log.consume([], manager.registry)
	_refresh()

func _on_events(events: Array[Dictionary]) -> void:
	_log_label.text = _battle_log.consume(events, manager.registry)
	for event in events:
		if event["kind"] != "damage":
			continue
		var target_panel := enemy_panel if event["side"] == 0 else ally_panel
		for index in target_panel.members.size():
			if target_panel.members[index].id == event["target_id"]:
				target_panel.cards[index].show_hit(event["value"])
				game_audio.play("hit")
				break

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

func _build_header_divider(parent: Node) -> void:
	_header_separator = Control.new()
	_header_separator.custom_minimum_size.y = 26
	parent.add_child(_header_separator)
	_status = _label(_header_separator, "", 17, GOLD)
	_status.anchor_left = 0.5
	_status.anchor_right = 0.5
	_status.offset_left = -120
	_status.offset_right = 120
	_status.offset_bottom = 26
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for right in [false, true]:
		var half := HBoxContainer.new()
		half.anchor_left = 0.5 if right else 0.0
		half.anchor_right = 1.0 if right else 0.5
		half.offset_left = 136 if right else 0
		half.offset_right = 0 if right else -136
		half.offset_bottom = 26
		half.add_theme_constant_override("separation", 14)
		_header_separator.add_child(half)
		var line := HSeparator.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxLine.new()
		style.color = Color("dfc28a", 0.6)
		style.thickness = 1
		line.add_theme_stylebox_override("separator", style)
		if right:
			half.add_child(line)
		else:
			var leading := HSeparator.new()
			leading.custom_minimum_size.x = 0
			leading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			leading.add_theme_stylebox_override("separator", style)
			half.add_child(leading)
		var motto := _label(half, "山河万物 · 皆为道场" if right else "逆天而行 · 道在心中", 18, GOLD)
		motto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if not right:
			# Title center is 36 + 268/2 = 170 in the same margin coordinate space.
			var leading := half.get_child(0) as HSeparator
			leading.custom_minimum_size.x = 170 - motto.get_minimum_size().x / 2 - 14
			half.add_child(line)
