class_name MapTechniqueChoiceDialog
extends MapExitDialog

signal technique_chosen(item_id: String)
signal books_chosen(ids: Array)
signal closed
var selected_id := ""
var selected_ids: Array[String] = []
var selection_limit := 1
var multiple := false
var cards: Array[MapInventoryItemCard] = []
var scroll: ScrollContainer
var grid: GridContainer
var empty_label: Label

func _init() -> void:
	super()
	name="MapTechniqueChoiceDialog"
	z_index=55
	use_map_exit_art()
	heading.text="功法选择"
	message.hide()
	error_label.hide()
	confirm_button.position.y+=14
	cancel_button.position.y+=14
	scroll=ScrollContainer.new()
	scroll.position=Vector2(29,123)
	scroll.size=Vector2(482,126)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	canvas.add_child(scroll)
	var center:=CenterContainer.new()
	center.size_flags_horizontal=SIZE_EXPAND_FILL
	center.size_flags_vertical=SIZE_EXPAND_FILL
	scroll.add_child(center)
	grid=GridContainer.new()
	grid.columns=5
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",10)
	center.add_child(grid)
	empty_label=_label("当前没有功法可选",Rect2(30,151,480,65),23,Color("ded6bb"))
	confirmed.connect(func():
		if multiple:
			books_chosen.emit(selected_ids)
		else:
			if selected_id.is_empty(): return
			technique_chosen.emit(selected_id)
		close()
	)
	cancelled.connect(close)

# Future caller supplies standard item-card records; no legacy test books are
# silently exposed as learnable cultivation techniques.
func present_techniques(records: Array[Dictionary], current: String) -> void:
	ItemTooltipHost.for_control(self).dismiss()
	selected_id=current if records.any(func(record): return record.id==current) else ""
	for card in cards: card.free()
	cards.clear()
	for record in records:
		var card:=MapInventoryItemCard.new()
		card.configure(record,"功法",true)
		card.equipment_actions_enabled=false
		card.set_card_width(84)
		grid.add_child(card)
		card.set_selected(record.id==selected_id)
		card.mouse_entered.connect(func(): card.modulate=Color(1.12,1.12,1.12,1))
		card.mouse_exited.connect(func():
			if multiple: _update_multiple()
			else: card.modulate=Color.WHITE
		)
		card.gui_input.connect(func(input: InputEvent):
			if input is InputEventMouseButton and input.pressed and input.button_index==MOUSE_BUTTON_LEFT: select_technique(record.id)
		)
		cards.append(card)
	empty_label.visible=cards.is_empty()
	scroll.scroll_vertical=0
	present("功法选择")
	confirm_button.disabled=selected_id.is_empty()
	confirm_button.modulate=Color(0.5,0.5,0.5,1) if confirm_button.disabled else Color.WHITE

func present_multiple(records: Array[Dictionary], current: Array[String], limit: int) -> void:
	multiple=true
	selection_limit=limit
	present_techniques(records,current[0] if not current.is_empty() else "")
	selected_ids=current.duplicate()
	heading.text="功法选择（最多%d本）" % limit
	_update_multiple()

func _update_multiple() -> void:
	for card in cards:
		card.set_selected(card.entry.id in selected_ids)
		card.modulate=Color(0.5,0.5,0.5) if not str(card.entry.get("practice_error","")).is_empty() else Color.WHITE
	confirm_button.disabled=false
	confirm_button.modulate=Color.WHITE

func select_technique(id: String) -> void:
	if multiple:
		var found := cards.filter(func(card): return card.entry.id==id)
		if found.is_empty(): return
		if not str(found[0].entry.get("practice_error","")).is_empty():
			error_label.text=found[0].entry.practice_error
			error_label.show()
			return
		error_label.hide()
		if id in selected_ids: selected_ids.erase(id)
		elif selected_ids.size()<selection_limit: selected_ids.append(id)
		_update_multiple()
		return
	if not cards.any(func(card): return card.entry.id==id): return
	selected_id=id
	for card in cards: card.set_selected(card.entry.id==id)
	confirm_button.disabled=false
	confirm_button.modulate=Color.WHITE

func close() -> void:
	if not visible: return
	if is_inside_tree(): ItemTooltipHost.for_control(self).dismiss()
	hide()
	closed.emit()
