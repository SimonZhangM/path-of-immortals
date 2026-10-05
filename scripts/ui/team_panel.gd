class_name TeamPanel
extends VBoxContainer

const WIDTH := 821.0
const BAG_SIDE := 548.0
var manager: GameManager
var enemy_side: bool = false
var cards: Array[PartyMemberCard] = []
var companion_cards: Array[CompanionCard] = []
var bags: Array[InventoryView] = []
var combat_status: RichTextLabel
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
	add_child(actor_row)
	var roster: Array = manager.enemy_companions if enemy_side else manager.companions
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
	main_column.add_child(card)
	card.configure(0, members[0])
	card.set_primary(true)
	cards.append(card)
	combat_status = RichTextLabel.new()
	combat_status.name = "CombatStatus"
	combat_status.custom_minimum_size = Vector2(410, 80)
	combat_status.add_theme_font_size_override("normal_font_size", 15)
	combat_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_column.add_child(combat_status)
	var inventory_row := CenterContainer.new()
	add_child(inventory_row)
	var bag := InventoryView.new()
	bag.display_side = BAG_SIDE
	inventory_row.add_child(bag)
	bag.bind_game(manager, 0, enemy_side)
	bags.append(bag)

func _process(_delta: float) -> void:
	for index in cards.size():
		cards[index].refresh(members[index])
	if combat_status != null and not members.is_empty():
		var member: PartyMemberState = members[0]
		var parts: PackedStringArray = []
		parts.append("灵盾 %s / %s" % [EffectSystem.number_text(member.barrier), EffectSystem.number_text(T01CombatRules.barrier_capacity(member))])
		if not member.thunder_shields.is_empty():
			parts.append("雷盾 " + "/".join(member.thunder_shields.map(func(value): return EffectSystem.number_text(value))))
		if not member.sword_screen.is_empty(): parts.append("剑幕 %s" % EffectSystem.number_text(member.sword_screen.value))
		for status: String in member.combat_statuses:
			parts.append("%s %d" % [status, T01CombatRules.layers(member, status)])
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
