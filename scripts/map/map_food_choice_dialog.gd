class_name MapFoodChoiceDialog
extends MapExitDialog

signal food_chosen(item_id: String)
var selected_id := ""
var cards: Array[MapInventoryItemCard] = []
var scroll: ScrollContainer
var center: CenterContainer
var grid: GridContainer
var empty_label: Label

func _init() -> void:
	super()
	name = "MapFoodChoiceDialog"
	z_index = 55
	use_map_exit_art()
	heading.text = "菜品选择"
	message.hide()
	error_label.hide()
	confirm_button.position.y += 14
	cancel_button.position.y += 14
	scroll = ScrollContainer.new()
	scroll.name = "FoodCardScroll"
	scroll.position = Vector2(29,123)
	scroll.size = Vector2(482,126)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	canvas.add_child(scroll)
	center = CenterContainer.new()
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	center.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.add_child(center)
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",10)
	center.add_child(grid)
	empty_label = _label("储物袋内暂无菜品",Rect2(30,151,480,65),23,Color("ded6bb"))
	confirmed.connect(func():
		ItemTooltipHost.for_control(self).dismiss()
		hide()
		food_chosen.emit(selected_id)
	)
	cancelled.connect(close)

func present_food(state: MapLoadoutState, current: String) -> void:
	ItemTooltipHost.for_control(self).dismiss()
	selected_id = current
	for card in cards: card.free()
	cards.clear()
	for record: Dictionary in state.storage_records():
		if record.category!="food": continue
		var card := MapInventoryItemCard.new()
		card.configure(record,"食物",true)
		card.bind_loadout(state,null)
		card.equipment_actions_enabled = false
		card.set_card_width(84)
		grid.add_child(card)
		card.set_selected(record.id==selected_id)
		card.mouse_entered.connect(func(): card.modulate=Color(1.12,1.12,1.12,1))
		card.mouse_exited.connect(func(): card.modulate=Color.WHITE)
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: select_food(record.id)
		)
		cards.append(card)
	if MapFood.carried_unit(state,selected_id).is_empty(): selected_id=""
	empty_label.visible = cards.is_empty()
	scroll.scroll_vertical = 0
	present("菜品选择")

func select_food(id: String) -> void:
	selected_id = id
	for card in cards: card.set_selected(card.entry.id==id)

func close() -> void:
	if is_inside_tree(): ItemTooltipHost.for_control(self).dismiss()
	hide()
