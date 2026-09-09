class_name TeamPanel
extends VBoxContainer

const WIDTH := 821.0
const BAG_SIDE := 548.0
var manager: GameManager
var enemy_side: bool = false
var cards: Array[PartyMemberCard] = []
var companion_cards: Array[CompanionCard] = []
var bags: Array[InventoryView] = []
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
