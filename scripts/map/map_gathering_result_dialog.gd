extends MapRewardDialog

signal cancelled

func _init() -> void:
	super()
	name = "MapGatheringResultDialog"
	z_index = 44
	heading.text = "获得药材"
	accept_button.get_node("AcceptCaption").text = "收下"
	error_label.position.y = 479

func present_herb(record: Dictionary, model: MapLoadoutState) -> void:
	heading.text = "获得" + str(record.name)
	var mineral: bool = record.get("category") == "mineral"
	super.present(record,"矿石" if mineral else "草木")
	card.loadout = model if model.records.has(record.id) else null
	card.mouse_filter = MOUSE_FILTER_STOP

func _input(event: InputEvent) -> void:
	if not visible: return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		if event.pressed:
			cancelled.emit()
		get_viewport().set_input_as_handled()
