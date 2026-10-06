class_name TeamPanel
extends VBoxContainer

const WIDTH := 822.0
const BAG_SIDE := 548.0
const ACTOR_Y_OFFSET := -3.75 # 5 physical pixels at the native 2560x1440 scale.
const PLAYER_BOARD_VISIBLE_SIZE := Vector2(650, 630)
const PLAYER_BOARD_CENTER_Y_OFFSET := -40.0
var manager: GameManager
var enemy_side: bool = false
var cards: Array[PartyMemberCard] = []
var companion_cards: Array[CompanionCard] = []
var bags: Array[InventoryView] = []
var combat_status: RichTextLabel
var status_icons: BattleStatusIcons
var preview_all_status_icons := true
var members: Array:
	get:
		return manager.enemies if enemy_side else manager.party

func configure(game: GameManager, is_enemy: bool) -> void:
	manager = game
	enemy_side = is_enemy
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", 8)
	manager.battle_restarted.connect(rebuild)
	rebuild()

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	cards.clear()
	bags.clear()
	companion_cards.clear()
	var actor_row := HBoxContainer.new()
	actor_row.custom_minimum_size.y = 340
	actor_row.alignment = BoxContainer.ALIGNMENT_CENTER
	actor_row.add_theme_constant_override("separation", 18)
	var roster: Array = manager.enemy_companions if enemy_side else manager.companions
	var actor_margin := MarginContainer.new()
	# Solo status group and board share this panel's horizontal center.
	add_child(actor_margin)
	actor_margin.add_child(actor_row)
	if not roster.is_empty():
		var supports := VBoxContainer.new()
		supports.alignment = BoxContainer.ALIGNMENT_CENTER
		supports.add_theme_constant_override("separation", 18)
		actor_row.add_child(supports)
		for index in roster.size():
			var companion := CompanionCard.new()
			supports.add_child(companion)
			companion.configure(manager, roster[index], 1 if enemy_side else 0, index)
			companion_cards.append(companion)
	var main_column := VBoxContainer.new()
	main_column.custom_minimum_size.x = PartyMemberCard.BASE_SIZE.x
	main_column.alignment = BoxContainer.ALIGNMENT_CENTER
	main_column.add_theme_constant_override("separation", 4)
	actor_row.add_child(main_column)
	var card := PartyMemberCard.new()
	if enemy_side:
		# Lower the enemy portrait and plaque to the map-frame player baseline;
		# keep both sides' resource bars at their existing equal height.
		card.portrait_vertical_offset = 236.0 * (0.076470588 + 0.847058824) - 7.0 - 200.0
	var actor_slot := Control.new()
	actor_slot.custom_minimum_size = PartyMemberCard.BASE_SIZE
	main_column.add_child(actor_slot)
	actor_slot.add_child(card)
	card.position.y = ACTOR_Y_OFFSET
	var frame := {} if enemy_side else {
		"portrait_frame": "res://assets/player-level-1.webp",
		"portrait_frame_region": [16, 45, 510, 510],
		# Same 96px portrait / 113 1/3px ring proportions as the map header.
		"portrait_window": [0.076470588, 0.076470588, 0.847058824, 0.847058824]
	}
	card.configure(0, members[0], frame)
	card.set_primary(true)
	cards.append(card)
	status_icons = BattleStatusIcons.new()
	status_icons.manager = manager
	status_icons.show_all_for_testing = preview_all_status_icons
	# Reserve height only: a wider icon row must not widen the resource bars.
	var status_slot := Control.new()
	status_slot.name = "StatusIconsOverflow"
	status_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.resources.add_child(status_slot)
	status_slot.add_child(status_icons)
	status_icons.minimum_size_changed.connect(_layout_status_icons)
	status_icons.visibility_changed.connect(_layout_status_icons)
	status_icons.configure()
	status_icons.refresh(members[0])
	_layout_status_icons()
	combat_status = RichTextLabel.new()
	combat_status.name = "CombatStatus"
	combat_status.custom_minimum_size = Vector2(0, 80)
	combat_status.add_theme_font_size_override("normal_font_size", 15)
	combat_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.resources.add_child(combat_status)
	var status_space := Control.new()
	status_space.custom_minimum_size.y = 80
	status_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_column.add_child(status_space)
	var inventory_row: Control = CenterContainer.new() if enemy_side else Control.new()
	inventory_row.name = "BattleBoardStage"
	inventory_row.custom_minimum_size.y = BAG_SIDE if enemy_side else BAG_SIDE * 1.04
	add_child(inventory_row)
	var bag := InventoryView.new()
	bag.display_side = BAG_SIDE if enemy_side else 1.0
	inventory_row.add_child(bag)
	bag.bind_game(manager, 0, enemy_side)
	bags.append(bag)
	if not enemy_side:
		bag.input_art_bounds_only = true
		bag.custom_minimum_size = Vector2.ZERO
		inventory_row.resized.connect(_layout_player_board.bind(inventory_row, bag))
		bag.board_layout_changed.connect(_layout_player_board.bind(inventory_row, bag))
		_layout_player_board.call_deferred(inventory_row, bag)

func _layout_player_board(stage: Control, bag: InventoryView) -> void:
	if not is_instance_valid(bag) or bag.board_texture == null: return
	# Fit real visible artwork, not transparent source-canvas padding. Keep the
	# shared BoardLayout mapping for art, occupied cells, items and cooldowns.
	var visible := Rect2(MapItemArtwork.TextureMetrics.inspect(bag.board_texture).visible_rect)
	var target := Vector2(minf(PLAYER_BOARD_VISIBLE_SIZE.x, stage.size.x), PLAYER_BOARD_VISIBLE_SIZE.y)
	var factor := minf(target.x / visible.size.x, target.y / visible.size.y)
	var side := factor * maxf(bag.board_layout.source_size.x, bag.board_layout.source_size.y) / bag.board_layout.display_scale
	bag.size = Vector2.ONE * side
	var center := Vector2(stage.size.x * 0.5, stage.size.y * 0.5 + PLAYER_BOARD_CENTER_Y_OFFSET)
	bag.position = center - bag.board_layout.source_to_view(visible.get_center(), bag.size)

func _layout_status_icons() -> void:
	var slot := status_icons.get_parent() as Control
	slot.visible = status_icons.visible
	var extent := status_icons.get_combined_minimum_size()
	status_icons.size = extent
	slot.custom_minimum_size.y = extent.y

func _process(_delta: float) -> void:
	for index in cards.size():
		cards[index].refresh(members[index])
	if combat_status != null and not members.is_empty():
		var member: PartyMemberState = members[0]
		status_icons.refresh(member)
		var parts: PackedStringArray = []
		if not member.thunder_shields.is_empty():
			parts.append("雷盾 " + "/".join(member.thunder_shields.map(func(value): return EffectSystem.number_text(value))))
		if not member.sword_screen.is_empty(): parts.append("剑幕 %s" % EffectSystem.number_text(member.sword_screen.value))
		var now: int = manager.simulation.state.time_usec
		if member.frozen_until > now: parts.append("冻结 %.1fs" % ((member.frozen_until - now) / 1000000.0))
		if member.paralyzed_until > now: parts.append("麻痹 %.1fs" % ((member.paralyzed_until - now) / 1000000.0))
		if manager.simulation.timeline != null:
			for control: Dictionary in manager.simulation.timeline.controls.values():
				if control.member == member and control.kind != "freeze" and control.until > now:
					parts.append("%s %.1fs" % [CombatTimeline.CONTROL_NAMES[control.kind],(control.until-now)/1000000.0])
		for effect_id: String in member.temporary_effects:
			if effect_id == "weakness": continue
			if member.temporary_effects[effect_id].until > now:
				var item := manager.registry.get_item(effect_id)
				parts.append("%s %.1fs" % [item.display_name if item != null else {"toxin_immunity":"毒蚀免疫","wind_accuracy":"乘风留影"}.get(effect_id,effect_id), (member.temporary_effects[effect_id].until - now) / 1000000.0])
		combat_status.text = " · ".join(parts)
		combat_status.visible = not parts.is_empty()
