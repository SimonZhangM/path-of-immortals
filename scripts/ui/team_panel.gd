class_name TeamPanel
extends VBoxContainer

const GAP := 18.0
const WIDTH := PartyMemberCard.BASE_SIZE.x * (1.0 + PartyMemberCard.COMPACT_SCALE) + GAP
const BAG_SIDE := 548.0
const SMALL_BAG_SIDE := WIDTH - BAG_SIDE - GAP
const PORTRAIT_HEIGHT := PartyMemberCard.BASE_SIZE.y * PartyMemberCard.COMPACT_SCALE * 2 + 12
var manager: GameManager
var enemy_side: bool = false
var cards: Array[PartyMemberCard] = []
var bags: Array[InventoryView] = []
var members: Array:
	get:
		return manager.enemies if enemy_side else manager.party

func configure(game: GameManager, is_enemy: bool) -> void:
	manager = game
	enemy_side = is_enemy
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", 10)
	manager.formation_changed.connect(rebuild)
	manager.battle_restarted.connect(rebuild)
	rebuild()

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	cards.clear()
	bags.clear()
	var portrait_margin := MarginContainer.new()
	portrait_margin.add_theme_constant_override("margin_top", 6)
	add_child(portrait_margin)
	var portraits := HBoxContainer.new()
	portraits.custom_minimum_size = Vector2(WIDTH, PORTRAIT_HEIGHT)
	portraits.add_theme_constant_override("separation", int(GAP))
	portrait_margin.add_child(portraits)
	var caption_space := Control.new()
	caption_space.custom_minimum_size.y = 26
	caption_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption_space)
	var inventory_row := HBoxContainer.new()
	inventory_row.custom_minimum_size = Vector2(WIDTH, BAG_SIDE)
	inventory_row.add_theme_constant_override("separation", int(GAP))
	add_child(inventory_row)
	var kind: FormationRules.Kind = FormationRules.Kind.FRONT_ONE if enemy_side else manager.formation
	var ranks := FormationRules.rows(members.size(), kind)
	var primary_right: bool = 0 in ranks["front"]
	if enemy_side:
		primary_right = not primary_right
	var portrait_slots := _slots(portraits, PartyMemberCard.BASE_SIZE.x, PartyMemberCard.BASE_SIZE.x * PartyMemberCard.COMPACT_SCALE, primary_right)
	var bag_slots := _slots(inventory_row, BAG_SIDE, SMALL_BAG_SIDE, primary_right)
	for index in members.size():
		var primary := index == 0
		var card := PartyMemberCard.new()
		portrait_slots[0 if primary else 1].add_child(card)
		card.configure(index, members[index])
		card.set_primary(primary)
		cards.append(card)
		if index > 1:
			var spacer := Control.new()
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			bag_slots[1].add_child(spacer)
		var bag := InventoryView.new()
		bag.compact = not primary
		bag.display_side = BAG_SIDE if primary else SMALL_BAG_SIDE
		bag_slots[0 if primary else 1].add_child(bag)
		bag.bind_game(manager, index, enemy_side)
		bags.append(bag)
		var caption := Label.new()
		caption.text = "%s · 储物袋" % members[index].definition["name"] if primary else str(members[index].definition["name"])
		caption.add_theme_font_size_override("font_size", 18)
		caption.anchor_right = 1
		caption.offset_top = -28
		caption.offset_bottom = 0
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bag.add_child(caption)

func _slots(row: HBoxContainer, primary_width: float, secondary_width: float, primary_right: bool) -> Array[VBoxContainer]:
	var primary := VBoxContainer.new()
	primary.custom_minimum_size.x = primary_width
	primary.alignment = BoxContainer.ALIGNMENT_CENTER
	var secondary := VBoxContainer.new()
	secondary.custom_minimum_size.x = secondary_width
	secondary.alignment = BoxContainer.ALIGNMENT_CENTER
	secondary.add_theme_constant_override("separation", 12)
	if members.size() <= 1:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(primary)
		secondary.free()
		return [primary]
	row.add_child(secondary if primary_right else primary)
	row.add_child(primary if primary_right else secondary)
	return [primary, secondary]

func _process(_delta: float) -> void:
	for index in cards.size():
		cards[index].refresh(members[index])
