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
var _time: Label
var _status: Label
var _stats: Label
var _pause: Button
var _start: Button
var _log_label: RichTextLabel
var _phase_label: Label
var _bag_usage: Label
var _bag_title: Label
var _cards: Array[PartyMemberCard] = []
var _preview_views: Array[InventoryView] = []
var _preview_titles: Array[Label] = []
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
	for index in _preview_views.size():
		_preview_views[index].bind_game(manager, index + 1)
	manager.presentation_events.connect(_on_events)
	manager.battle_restarted.connect(_on_restart)
	manager.battle_started.connect(_on_started)
	manager.member_selected.connect(_on_member_selected)
	_on_restart()

func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 21
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
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	root.add_child(header)
	_label(header, "修仙之路", 36, GOLD)
	var identity := _column(header, 6)
	_label(identity, "演武场 · 初试锋芒", 20, INK)
	_spacer(header)
	_label(header, "法器构筑    /    V0.3", 19, MUTED)
	root.add_child(HSeparator.new())
	var clock_row := HBoxContainer.new()
	root.add_child(clock_row)
	_phase_label = _label(clock_row, "战前准备", 21, JADE)
	_spacer(clock_row)
	_time = _label(clock_row, "00:00.00", 32, GOLD)
	_spacer(clock_row)
	_label(clock_row, "演武木桩 · 无反击", 20, MUTED)
	var arena := HBoxContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", 30)
	root.add_child(arena)
	var left := _column(arena, 16)
	left.custom_minimum_size.x = 820
	var party_row := HBoxContainer.new()
	party_row.add_theme_constant_override("separation", 12)
	left.add_child(party_row)
	for index in manager.party.size():
		var card := PartyMemberCard.new()
		party_row.add_child(card)
		card.configure(index, manager.party[index])
		card.pressed.connect(manager.select_member.bind(index))
		_cards.append(card)
	var bag_heading := HBoxContainer.new()
	left.add_child(bag_heading)
	_bag_title = _label(bag_heading, "", 24, GOLD)
	_spacer(bag_heading)
	_bag_usage = _label(bag_heading, "", 19, MUTED)
	var bag_row := HBoxContainer.new()
	bag_row.add_theme_constant_override("separation", 18)
	left.add_child(bag_row)
	inventory_view = InventoryView.new()
	inventory_view.name = "Backpack"
	bag_row.add_child(inventory_view)
	var previews := _column(bag_row, 12)
	for index in 2:
		var preview_column := _column(previews, 2)
		var title := _label(preview_column, "", 18, INK)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_preview_titles.append(title)
		var preview := InventoryView.new()
		preview.compact = true
		preview.name = "BackpackPreview%d" % index
		preview_column.add_child(preview)
		_preview_views.append(preview)
	var middle := _column(arena, 18)
	middle.custom_minimum_size.x = 203
	_spacer(middle, true)
	var duel := _label(middle, "对 阵", 27, GOLD)
	duel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start = _button(middle, "开始战斗  [空格]", manager.start_battle)
	_start.custom_minimum_size.y = 62
	_start.add_theme_stylebox_override("normal", _box(Color("625134"), GOLD))
	_pause = _button(middle, "暂停  [空格]", manager.toggle_pause)
	_button(middle, "重新布阵", manager.restart)
	_spacer(middle, true)
	var right := _column(arena, 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var enemy_title := _label(right, "敌 方", 21, RED)
	enemy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var portrait_center := CenterContainer.new()
	right.add_child(portrait_center)
	_portrait(portrait_center, "res://assets/images/enemies/dummy.svg", Vector2(300, 293))
	var enemy_name := _label(right, "演武木桩", 30, INK)
	enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp = _label(right, "", 21, RED)
	_hp_bar = _bar(right, RED)
	_status = _label(right, "等待开战", 20, GOLD)
	_stats = _label(right, "", 19, MUTED)
	var log_panel := _panel(right)
	_label(log_panel, "战斗记录", 20, INK)
	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size = Vector2(0, 165)
	_log_label.scroll_following = true
	_log_label.add_theme_font_size_override("normal_font_size", 18)
	_log_label.add_theme_color_override("default_color", MUTED)
	log_panel.add_child(_log_label)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root.add_child(footer)
	_label(footer, "战斗速度", 20, MUTED)
	var captions := ["F1  半速 0.5×", "F2  正常 1×", "F3  2×"]
	for index in SimulationClock.SPEEDS.size():
		var speed: float = SimulationClock.SPEEDS[index]
		var button := _button(footer, captions[index], manager.set_speed.bind(speed))
		button.toggle_mode = true
		_speed_buttons[speed] = button
	_spacer(footer)
	_label(footer, "空格  开战 / 暂停 / 恢复    ·    战斗中锁定背包", 19, MUTED)

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if manager.simulation == null:
		return
	var sim := manager.simulation
	var state := sim.state
	var preparing := state.phase == GameState.Phase.PREPARATION
	var fighting := state.phase == GameState.Phase.BATTLE
	for index in _cards.size():
		_cards[index].refresh(manager.party[index])
		_cards[index].disabled = not manager.can_select_member()
		_cards[index].set_pressed_no_signal(index == manager.selected_member_index)
	var seconds := state.time_usec / 1_000_000.0
	_time.text = "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]
	_start.disabled = not preparing
	_pause.disabled = not fighting
	_pause.text = "继续  [空格]" if sim.clock.paused else "暂停  [空格]"
	_phase_label.text = "战前准备 · 布阵中" if preparing else ("战斗已暂停" if sim.clock.paused else ("战斗进行中" if fighting else "试炼完成"))
	for speed in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(is_equal_approx(speed, sim.clock.speed_multiplier))
	if preparing:
		_status.text = "等待我方完成布阵"
	elif state.is_finished():
		_status.text = "已击破 · 耗时 %.2f 游戏秒" % (state.defeated_at_usec / 1_000_000.0)
	else:
		_status.text = "战斗已暂停" if sim.clock.paused else "法器自动运转中 · %s×" % str(sim.clock.speed_multiplier)
	if state.revision != _last_revision:
		_last_revision = state.revision
		var max_hp := int(manager.registry.get_enemy(state.enemy_id)["max_hp"])
		_hp.text = "气血  %d / %d" % [state.enemy_hp, max_hp]
		_hp_bar.value = 100.0 * state.enemy_hp / max_hp
		_stats.text = "法器发动 %d 次    /    累计伤害 %d" % [state.activation_count, state.damage_total]

func _on_member_selected(index: int) -> void:
	inventory_view.set_member(index)
	var preview_indices := manager.preview_member_indices()
	for slot in preview_indices.size():
		var member_index: int = preview_indices[slot]
		_preview_views[slot].set_member(member_index)
		_preview_titles[slot].text = manager.party[member_index].definition["name"]
	_bag_title.text = "%s · 储物袋" % manager.party[index].definition["name"]
	_bag_usage.text = "4 × 4   ·   已用 %d / 16 格" % manager.inventory.occupied_cells()
	_refresh()

func _on_restart() -> void:
	_last_revision = -1
	_battle_log.reset()
	_log_label.text = "布阵中。"
	_on_member_selected(manager.selected_member_index)

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

func _column(parent: Node, gap: int = 12) -> VBoxContainer:
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
	button.custom_minimum_size = Vector2(105, 50)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("14242a", 0.9), Color("4a5b58"), 16))
	parent.add_child(panel)
	return _column(panel)

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 15
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _box(Color("0c191e"), Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", _box(color, Color.TRANSPARENT, 0))
	parent.add_child(bar)
	return bar

func _box(color: Color, border: Color, padding: int = 12) -> StyleBoxFlat:
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
