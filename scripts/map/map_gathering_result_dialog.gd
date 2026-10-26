extends MapRewardDialog

signal cancelled
var quantity_label: Label

class HerbCard extends MapInventoryItemCard:
	func _gui_input(_event: InputEvent) -> void: accept_event()

func _init() -> void:
	super()
	name = "MapGatheringResultDialog"
	z_index = 44
	heading.text = "获得药材"
	accept_button.get_node("AcceptCaption").text = "收下"
	quantity_label = _label("",Rect2(100,147,340,25),21,Color("fbf4bf"))
	quantity_label.hide()
	error_label.position.y = 479

func present_herb(record: Dictionary, model: MapLoadoutState) -> void:
	heading.text = "获得" + str(record.name)
	var mineral: bool = record.get("category") == "mineral"
	quantity_label.text = "数量：%d%s" % [int(record.quantity), "块" if mineral else "株"]
	quantity_label.show()
	if card != null:
		canvas.remove_child(card)
		card.queue_free()
	card = HerbCard.new()
	card.configure(record,"矿石" if mineral else "草木")
	card.loadout = model if model.records.has(record.id) else null
	card.mouse_filter = MOUSE_FILTER_STOP
	card.set_card_width(152)
	card.size = card.custom_minimum_size
	card.position = Vector2((DESIGN_SIZE.x-card.size.x)*0.5,181)
	canvas.add_child(card)
	card._layout()
	accept_button.get_node("AcceptCaption").text = "收下"
	accept_button.disabled = false
	error_label.text = ""
	show()
	_layout()

func _input(event: InputEvent) -> void:
	if not visible: return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		if event.pressed:
			cancelled.emit()
		get_viewport().set_input_as_handled()
