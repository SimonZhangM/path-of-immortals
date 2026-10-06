extends Control

const INK := Color("ece4cd")
const MUTED := Color("b2bdb6")
const JADE := Color("91c6b0")
const GOLD := Color("dfc28a")
const LAYOUT_SIZE := Vector2(1920, 1080)
const FixedSeparatorValue := preload("res://scripts/ui/fixed_separator_value.gd")
@export var preview_all_status_icons := true
@export_file("*.webp", "*.png") var battle_background_path := "res://assets/backgroundtest.png"
@onready var manager: GameManager = $"../GameManager"
var ally_panel: TeamPanel
var enemy_panel: TeamPanel
var _time: FixedSeparatorValue
var _time_seconds: Label
var _timer_frame: PanelContainer
var _header_separator: Control
var _backdrop: Control
var _battle_emblem: TextureRect
var _emblem_preparing := true
var _emblem_tween: Tween
var _status: Label
var _bag_button: Button
var _battle_button: BattleActionButton
var _battle_icon: Texture2D
var _wait_icon: Texture2D
var _retreat_button: Button
var _settings_button: Button
var _pause_button: Button
var _retreat_dialog: Control
var _result_heading: Label
var _loot_label: Label
var battle_exit_handler: Callable
var _review_button: Button
var _exit_button: Button
var _review_note: Label
var _countdown: RetreatCountdown
var _log_panel: PanelContainer
var storage_panel
var _log_label: RichTextLabel
var _speed_buttons: Dictionary = {}
var _battle_log := BattleLog.new()
var game_audio: GameAudio
var defer_battle_music := false
var board_change_dialog: MapExitDialog
var _pending_board_change: Dictionary = {}

func _ready() -> void:
	set_deferred("oversampling_with_scale", CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fit_native_layout()
	get_viewport().size_changed.connect(_fit_native_layout)
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
	game_audio.configure(manager, defer_battle_music)
	_on_restart()

func _fit_native_layout() -> void:
	# Retain authored proportions; canvas items and fonts render at output resolution.
	var available := get_viewport_rect().size
	var factor := minf(available.x / LAYOUT_SIZE.x, available.y / LAYOUT_SIZE.y)
	size = LAYOUT_SIZE
	scale = Vector2.ONE * factor
	position = ((available - LAYOUT_SIZE * factor) * 0.5).round()

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
	_backdrop = backdrop
	# Temporary background comparison; restore battle_background_path after review.
	backdrop.texture = load("res://assets/test1.webp")
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
	_time = preload("res://scripts/ui/fixed_separator_value.gd").new()
	_time.separator = "."
	_time.gap = 0
	_time.text = "00.00"
	_time.add_theme_font_size_override("font_size", 39)
	_time.add_theme_color_override("font_color", Color("f1dca6"))
	timer_content.add_child(_time)
	_time_seconds = _label(_time, "秒", 20, Color("f1dca6"))
	_time_seconds.name = "TimerSeconds"
	_time_seconds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time.resized.connect(_layout_time_suffix)
	_time.minimum_size_changed.connect(_layout_time_suffix)
	_layout_time_suffix.call_deferred()
	# Integer font size: 39 / 2 rounds to 20.
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
	ally_panel.preview_all_status_icons = preview_all_status_icons
	arena.add_child(ally_panel)
	if manager.startup_error.is_empty():
		ally_panel.configure(manager, false)
	var middle := VBoxContainer.new()
	middle.custom_minimum_size.x = 182
	middle.add_theme_constant_override("separation", 8)
	arena.add_child(middle)
	var duel := _art("res://assets/battle-start.webp")
	_battle_emblem = duel
	duel.name = "BattleEmblem"
	duel.anchor_left = 0.5
	duel.anchor_right = 0.5
	duel.anchor_top = 0.5
	duel.anchor_bottom = 0.5
	duel.offset_left = -108
	duel.offset_right = 108
	duel.offset_top = -128
	duel.offset_bottom = 88
	duel.pivot_offset = Vector2.ONE * 108
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
	_battle_button.caption_reference = "战斗继续"
	_battle_button.icon_reference = _battle_icon
	var bottom_actions := HBoxContainer.new()
	bottom_actions.add_theme_constant_override("separation", 8)
	footer_column.add_child(bottom_actions)
	_bag_button = _action_button(bottom_actions, "res://assets/bt-zhihuan.webp", Vector2(126, 44), func(): manager.set_adjustment(not manager.adjustment_open))
	_retreat_button = _action_button(bottom_actions, "res://assets/bt-chetui.webp", Vector2(126, 44), manager.request_retreat)
	_bag_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_retreat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_panel = TeamPanel.new()
	enemy_panel.preview_all_status_icons = preview_all_status_icons
	arena.add_child(enemy_panel)
	if manager.startup_error.is_empty():
		enemy_panel.configure(manager, true)
	_build_log()
	var divider: Control = preload("res://scripts/ui/battle_footer_divider.gd").new()
	divider.name = "BattleFooterDivider"
	middle.add_child(divider)
	var log_button := _action_button(middle, "res://assets/button-battle-fightlog.webp", Vector2(182, 54) * (44.0 / 54.0), func(): _log_panel.show())
	# Match visible artwork height, since the two source images have different ratios.
	var action_art: Vector2 = _bag_button.artwork.get_size()
	var action_box: Vector2 = _bag_button.custom_minimum_size
	var action_height: float = action_art.y * minf(action_box.x / action_art.x, action_box.y / action_art.y)
	var log_art: Vector2 = log_button.artwork.get_size()
	log_button.custom_minimum_size.x = action_height * log_art.x / log_art.y
	log_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	log_button.tooltip_text = "查看战斗记录"
	log_button.name = "BattleLogButton"
	var footer_padding := Control.new()
	footer_padding.custom_minimum_size.y = 14
	footer_padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(footer_padding)
	if manager.startup_error.is_empty():
		storage_panel = BattleStoragePanel.new() if manager.use_saved_loadout else StoragePanel.new()
		storage_panel.z_index = 10
		storage_panel.target_board = ally_panel.bags[0]
		storage_panel.anchor_left = 1
		storage_panel.anchor_right = 1
		storage_panel.anchor_bottom = 1
		storage_panel.offset_left = -23 - MapInventoryScreen.STORAGE_WIDTH if manager.use_saved_loadout else -849
		storage_panel.offset_right = -23 if manager.use_saved_loadout else -27
		storage_panel.offset_top = 128
		storage_panel.offset_bottom = -42 if manager.use_saved_loadout else -27
		add_child(storage_panel)
		if manager.use_saved_loadout:
			storage_panel.configure_battle(manager)
		else:
			storage_panel.configure(manager)
	_countdown = RetreatCountdown.new()
	_countdown.theme = ui_theme
	add_child(_countdown)
	_build_retreat_dialog()
	board_change_dialog = MapExitDialog.new()
	board_change_dialog.name = "BattleBoardChangeDialog"
	board_change_dialog.message.text = "确定更换阵盘吗？"
	board_change_dialog.confirm_button.get_node("Caption").text = "确认"
	add_child(board_change_dialog)
	board_change_dialog.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	board_change_dialog.confirmed.connect(_confirm_board_change)
	board_change_dialog.cancelled.connect(_close_board_change)
	_bind_board_change_request()
	manager.adjustment_changed.connect(_close_board_change)

func _bind_board_change_request() -> void:
	if ally_panel.bags.is_empty(): return
	var board := ally_panel.bags[0]
	if not board.board_change_requested.is_connected(_open_board_change):
		board.board_change_requested.connect(_open_board_change)

func _open_board_change(data: Dictionary) -> void:
	if board_change_dialog.visible or not ally_panel.bags[0].can_request_board_change(data): return
	_pending_board_change = data.duplicate(true)
	var entry := manager.storage.get_entry(data.storage_id)
	board_change_dialog.present(manager.registry.get_item(entry.item_id).display_name)

func _close_board_change() -> void:
	_pending_board_change.clear()
	if board_change_dialog != null: board_change_dialog.hide()

func _confirm_board_change() -> void:
	if not board_change_dialog.visible: return
	if not ally_panel.bags[0].can_request_board_change(_pending_board_change):
		board_change_dialog.error_label.text = "阵盘状态已变化，请取消后重试。"
		board_change_dialog.confirm_button.disabled = true
		return
	if manager.change_board(_pending_board_change.storage_id):
		_close_board_change()
	else:
		board_change_dialog.error_label.text = manager.board_change_error(_pending_board_change.storage_id)

func _bind_background_focus() -> void:
	for panel in [ally_panel, enemy_panel]:
		if not panel.bags.is_empty():
			panel.bags[0].item_rect_changed.connect(_update_background_focus.call_deferred)
	_update_background_focus.call_deferred()

func _update_background_focus() -> void:
	if ally_panel.bags.is_empty() or enemy_panel.bags.is_empty(): return
	var regions: Array[Rect2] = []
	for panel in [ally_panel, enemy_panel]:
		var bag: Control = panel.bags[0]
		var relative := _backdrop.get_global_transform().affine_inverse() * bag.get_global_transform()
		regions.append(Rect2(relative * Vector2.ZERO, bag.size))
	_backdrop.set_board_regions(regions[0], regions[1])

func _refresh_emblem(preparing: bool) -> void:
	if _emblem_preparing == preparing: return
	_emblem_preparing = preparing
	if _emblem_tween != null: _emblem_tween.kill()
	if preparing:
		_battle_emblem.scale = Vector2.ONE
		_battle_emblem.modulate.a = 1.0
		return
	_emblem_tween = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_emblem_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_emblem_tween.tween_property(_battle_emblem, "scale", Vector2.ONE * 1.6, 3.0)
	_emblem_tween.tween_property(_battle_emblem, "modulate:a", 0.0, 3.0)

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
	_result_heading = _label(column, "战斗失败", 28, GOLD)
	_result_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loot_label = _label(column, "", 18, GOLD)
	_loot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loot_label.hide()
	_review_note = _label(column, "战斗复盘尚未开放", 18, MUTED)
	_review_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_review_note.hide()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	_review_button = _button(actions, "战斗复盘", manager.request_battle_review)
	_exit_button = _button(actions, "返回地图" if battle_exit_handler.is_valid() else "退出战斗", manager.request_battle_exit)
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
	if battle_exit_handler.is_valid():
		var error: String = await battle_exit_handler.call()
		if not error.is_empty():
			_review_note.text = error
			_review_note.show()
			_exit_button.disabled = false
		return
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

func _input(event: InputEvent) -> void:
	if board_change_dialog != null and board_change_dialog.visible:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed: _close_board_change()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey:
			if event.pressed and (event.keycode == KEY_ESCAPE or event.is_action_pressed("map_inventory")):
				_close_board_change()
			get_viewport().set_input_as_handled()
		return
	if manager == null or storage_panel == null or not manager.adjustment_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not storage_panel.get_global_rect().has_point(event.position):
			manager.set_adjustment(false)
			get_viewport().set_input_as_handled()

func _layout_time_suffix() -> void:
	if not is_instance_valid(_time_seconds): return
	var font := _time.get_theme_font("font", "Label")
	var gap := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, 39).x
	var small_font := _time_seconds.get_theme_font("font")
	var baseline := (_time.size.y - font.get_height(39)) * .5 + font.get_ascent(39)
	baseline += CooldownRing.ink_vertical_bounds(font, _time.text, 39).y - CooldownRing.ink_vertical_bounds(small_font,"秒",20).y
	_time_seconds.position = Vector2(_time.text_right() + gap, baseline - small_font.get_ascent(20))
	_time_seconds.size = Vector2(_time_seconds.get_minimum_size().x, small_font.get_height(20))

func _refresh() -> void:
	if manager.simulation == null:
		return
	var sim := manager.simulation
	var state := sim.state
	var preparing := state.phase == GameState.Phase.PREPARATION
	var fighting := state.phase == GameState.Phase.BATTLE
	_refresh_emblem(preparing)
	_time.text = format_battle_time(state.time_usec)
	_layout_time_suffix()
	_bag_button.disabled = not manager.can_adjust()
	_battle_button.disabled = state.is_finished()
	_battle_button.caption = "战斗开始" if preparing else ("战斗结束" if state.is_finished() else ("战斗继续" if sim.clock.paused else "战斗暂停"))
	_battle_button.action_icon = _wait_icon if fighting and not sim.clock.paused else _battle_icon
	for speed in _speed_buttons:
		_speed_buttons[speed].disabled = state.is_finished()
		_speed_buttons[speed].set_pressed_no_signal(not sim.clock.paused and is_equal_approx(speed, sim.clock.speed_multiplier))
	_pause_button.disabled = not fighting
	_pause_button.set_pressed_no_signal(fighting and sim.clock.paused)
	_retreat_button.disabled = not fighting or state.retreat_at_usec >= 0
	_countdown.update_remaining(state.retreat_at_usec - state.time_usec if state.retreat_at_usec >= 0 else 0)
	_retreat_dialog.visible = state.is_finished() and (state.result == "defeat" or battle_exit_handler.is_valid())
	if _retreat_dialog.visible:
		_result_heading.text = {"victory": "战斗胜利", "defeat": "战斗失败", "draw": "平局", "retreat": "战斗失败"}.get(state.result, "战斗结束")
		_loot_label.text = manager.loot_summary
		_loot_label.visible = not manager.loot_summary.is_empty()
	if preparing:
		_status.text = "战前准备"
	elif state.is_finished():
		_status.text = {"victory": "战斗胜利", "defeat": "战斗失败", "draw": "平局 · 无法继续攻击", "retreat": "战斗失败"}[state.result]
	else:
		_status.text = "战斗已暂停" if sim.clock.paused else "战斗进行中"

func _on_restart() -> void:
	_close_board_change()
	_bind_board_change_request()
	_bind_background_focus()
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
	_status.name = "BattleStatus"
	_status.anchor_left = 0.5
	_status.anchor_right = 0.5
	_status.offset_left = -120
	_status.offset_right = 120
	_status.offset_top = -14
	_status.offset_bottom = 10
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var line := ColorRect.new()
	line.name = "HeaderDividerLine"
	line.color = Color("dfc28a", 0.6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.anchor_right = 1.0
	line.offset_top = 17
	line.offset_bottom = 18
	_header_separator.add_child(line)
	for right in [false, true]:
		var motto := _label(_header_separator, "山河万物 · 皆为道场" if right else "逆天而行 · 道在心中", 18, GOLD)
		motto.name = "RightMotto" if right else "LeftMotto"
		motto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		motto.offset_top = -14
		motto.offset_bottom = 10
		var text_width := motto.get_minimum_size().x
		if right:
			motto.anchor_left = 1.0
			motto.anchor_right = 1.0
			motto.offset_left = -text_width
			motto.offset_right = 0
		else:
			# Keep the left motto centered beneath the title.
			motto.offset_left = 170 - text_width * 0.5
			motto.offset_right = 170 + text_width * 0.5
