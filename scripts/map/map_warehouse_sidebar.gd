extends VBoxContainer
## Warehouse presentation only: selection/amount in, transfer and undo commands out.
signal undo_requested(operation_id: int)

const Transfer := preload("res://scripts/map/map_warehouse_transfer.gd")
const Metrics := preload("res://scripts/map/map_texture_metrics.gd")
const GOLD := Color("dec995")
const MUTED := Color("a7b8c5")
const PANEL_FILL := Color("071924f2")
const PANEL_BORDER := Color("2b424f")
var selection_key := ""
var quantity := 1
var maximum := 0
var selected_art: Control
var item_name: Label
var category: Label
var quality: Label
var minus_button: TextureButton
var plus_button: TextureButton
var amount: LineEdit
var owned: Label
var direction: TextureRect
var alert_icon: TextureRect
var status: Label
var capacity_text: Label
var hint: Label
var history_rows: VBoxContainer

func _init() -> void:
	name = "WarehouseOperationsSidebar"
	# Keep this compact sidebar independent of the inventory's serif fallback.
	theme = Theme.new()
	theme.default_font = ItemTooltip.summary_body_font()
	add_theme_constant_override("separation",12)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var title := _art(self,"UI-title-cangku-cangchucaozuo",Vector2(164,44))
	title.name = "WarehouseOperationsTitle"
	var chosen := _section("当前选中")
	var selection_center := CenterContainer.new()
	selection_center.name = "SelectedItemCenter"
	chosen.add_child(selection_center)
	var selected_row := HBoxContainer.new()
	selected_row.name = "SelectedItemGroup"
	selected_row.add_theme_constant_override("separation",8)
	selection_center.add_child(selected_row)
	selected_art = Control.new()
	selected_art.custom_minimum_size = Vector2(58,92)
	selected_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	selected_row.add_child(selected_art)
	var details := VBoxContainer.new()
	details.name = "SelectedItemDetails"
	# Lock the row to the original four-character title geometry; short names
	# no longer recenter the image, and long names ellipsize within the same column.
	details.custom_minimum_size.x = ceilf(ItemTooltip.summary_title_font().get_string_size("雷纹法袍",HORIZONTAL_ALIGNMENT_LEFT,-1,17).x)
	details.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_theme_constant_override("separation",8)
	selected_row.add_child(details)
	item_name = _label(details,"未选中",17)
	ItemTooltip.style_item_title(item_name,17)
	item_name.custom_minimum_size.x = details.custom_minimum_size.x
	item_name.clip_text = true
	category = _pill(details)
	quality = _pill(details)
	var count_section := _section("转移数量")
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation",6)
	count_section.add_child(count_row)
	minus_button = _quantity_button(count_row,"tanchuang-jiaoyi-jianshao")
	amount = LineEdit.new()
	amount.name = "TransferQuantity"
	amount.text = "1"
	amount.alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.expand_to_text_length = false
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.custom_minimum_size = Vector2(44,36)
	amount.add_theme_font_size_override("font_size",18)
	amount.add_theme_stylebox_override("normal",_box(Color("0b1923"),Color("344c53"),5,2))
	amount.add_theme_stylebox_override("focus",_box(Color("0b1923"),GOLD,5,2))
	count_row.add_child(amount)
	plus_button = _quantity_button(count_row,"tanchuang-jiaoyi-zengjia")
	minus_button.pressed.connect(func(): set_quantity(quantity-1))
	plus_button.pressed.connect(func(): set_quantity(quantity+1))
	amount.text_changed.connect(_edit_amount)
	amount.focus_exited.connect(commit_amount)
	amount.text_submitted.connect(func(_text: String): commit_amount())
	owned = _label(count_section,"当前拥有：0",16,MUTED)
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var preview_section := _section("转移预览")
	var preview := HBoxContainer.new()
	preview.alignment = BoxContainer.ALIGNMENT_CENTER
	preview.add_theme_constant_override("separation",6)
	preview_section.add_child(preview)
	var warehouse := VBoxContainer.new()
	preview.add_child(warehouse)
	_framed_icon(warehouse,"UI-title-cangku-cebian1")
	var warehouse_caption := _label(warehouse,"仓库",15)
	warehouse_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warehouse_caption.custom_minimum_size.x = 50
	direction = _art(preview,"UI-title-cangku-jiantou1",Vector2(25,43))
	direction.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var bag := VBoxContainer.new()
	preview.add_child(bag)
	_framed_icon(bag,"UI-title-cangku-cebian2")
	var bag_caption := _label(bag,"储物袋",15)
	bag_caption.name = "PreviewBagCaption"
	bag_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag_caption.custom_minimum_size.x = 50
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation",5)
	preview_section.add_child(status_row)
	alert_icon = _art(status_row,"tanchuang-baoxiang-alaet",Vector2(19,22))
	status = _label(status_row,"请选择物品",16,GOLD)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capacity_text = _label(preview_section,"",14,MUTED)
	hint = _label(preview_section,"选中后预览转移方向",13,MUTED)
	# Equal-height centered text rows avoid extra space hidden inside the last label.
	var text_row_height := maxf(22,ceilf(ItemTooltip.summary_body_font().get_height(16)))
	status_row.custom_minimum_size.y = text_row_height
	capacity_text.custom_minimum_size.y = text_row_height
	hint.custom_minimum_size.y = text_row_height
	var recent := _section("最近操作")
	history_rows = VBoxContainer.new()
	history_rows.add_theme_constant_override("separation",7)
	recent.add_child(history_rows)
	_label(history_rows,"无历史记录",16,MUTED)
	_label(recent,"仅保留本次仓储记录",12,MUTED)

func present(state: MapLoadoutState, id: String, item_id: String, withdraw: bool, category_names: Dictionary, rows: Array[Dictionary]) -> void:
	var key := ("out:" if withdraw else "in:") + item_id
	var changed := key != selection_key
	selection_key = key
	var info := Transfer.preview(state,id,item_id,withdraw)
	maximum = int(info.available)
	if changed: quantity = 1
	set_quantity(quantity)
	amount.editable = maximum > 0 and not info.blocked
	minus_button.disabled = quantity <= 1 or info.blocked
	plus_button.disabled = quantity >= maximum or info.blocked
	_paint_quantity_buttons()
	owned.text = "当前拥有：%d" % maximum
	if changed:
		for child in selected_art.get_children():
			selected_art.remove_child(child)
			child.queue_free()
		var record: Dictionary = state.records.get(item_id,{})
		item_name.text = ItemTooltip.summary_name(record.get("name","未选中"),record.get("category",""))
		item_name.tooltip_text = record.get("name","未选中")
		category.text = category_names.get(record.get("category",""),"—")
		quality.text = record.get("quality","—")
		if not record.is_empty():
			var thumb := _thumbnail(selected_art,record,58,76)
			thumb.position.y = 8
	direction.texture = _texture("UI-title-cangku-jiantou1" if withdraw else "UI-title-cangku-jiantou2")
	direction.modulate.a = 0.3 if item_id.is_empty() else 1.0
	var target := "储物袋" if withdraw else "仓库"
	var sufficient: bool = info.sufficient
	alert_icon.texture = _texture("tanchuang-baoxiang-alaet" if sufficient else "UI-title-cangku-alert")
	alert_icon.visible = not item_id.is_empty()
	status.text = target + ("空间充足" if sufficient else "空间不足") if not item_id.is_empty() else "请选择物品"
	status.add_theme_color_override("font_color",GOLD if sufficient else Color("f18d67"))
	capacity_text.text = "转移后：%d/%d" % [info.projected,info.capacity] if not item_id.is_empty() else ""
	hint.text = "同类合并占一个位置" if sufficient else ("请先存入物品腾出空间" if withdraw else "仓库暂允许超额存放")
	if withdraw and not info.blocked and info.projected > info.capacity:
		status.text = "可合并同类"
		hint.text = "未新增种类，仍处于超额"
	if item_id.is_empty(): hint.text = "选中后预览转移方向"
	if info.blocked: hint.text = "储物袋已满，无法新增种类" if withdraw else "使用中的阵盘不能存入"
	_present_history(state,rows)

func set_quantity(value: int) -> void:
	quantity = clampi(value,1,maxi(1,maximum))
	amount.text = str(quantity)
	minus_button.disabled = maximum <= 0 or quantity <= 1
	plus_button.disabled = maximum <= 0 or quantity >= maximum
	_paint_quantity_buttons()

func _quantity_button(parent: Node, asset: String) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _texture(asset)
	button.texture_disabled = button.texture_normal
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(30,34)
	button.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.focus_mode = FOCUS_NONE
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	parent.add_child(button)
	return button

func _paint_quantity_buttons() -> void:
	for button: TextureButton in [minus_button,plus_button]:
		button.modulate = Color(0.45,0.45,0.45,1) if button.disabled else Color.WHITE

func _edit_amount(text: String) -> void:
	# Allow a temporary empty field while editing; commands always commit/clamp.
	if text.is_empty(): return
	if not text.is_valid_int():
		amount.text = str(quantity)
		return
	set_quantity(text.to_int())
	amount.caret_column = amount.text.length()

func commit_amount() -> void:
	set_quantity(amount.text.to_int() if amount.text.is_valid_int() else quantity)

func _present_history(state: MapLoadoutState, rows: Array[Dictionary]) -> void:
	for child in history_rows.get_children():
		history_rows.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		_label(history_rows,"无历史记录",16,MUTED)
		return
	for receipt: Dictionary in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",4)
		history_rows.add_child(row)
		if not receipt.all_items: _thumbnail(row,state.records[receipt.item_id],25)
		var target := "储物袋" if receipt.withdraw else "仓库"
		var caption := "全物品转入" + target if receipt.all_items else ("仓库 》储物袋" if receipt.withdraw else "储物袋 》仓库")
		var description := _label(row,caption,13,MUTED)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.y = 40
		row.tooltip_text = ("全物品" if receipt.all_items else String(state.records[receipt.item_id].name)) + "（%d件）转入%s" % [receipt.units.size(),target]
		var undo := _button(row,"撤销",37)
		undo.name = "Undo_%d" % receipt.operation_id
		undo.add_theme_font_size_override("font_size",13)
		undo.add_theme_stylebox_override("normal",_box(Color("243640"),Color("53616c"),5,2))
		undo.add_theme_stylebox_override("hover",_box(Color("324b59"),Color("8ea2af"),5,2))
		undo.add_theme_stylebox_override("pressed",_box(Color("162934"),Color("748b9b"),5,2))
		undo.add_theme_stylebox_override("disabled",_box(Color("25313b"),Color("354550"),5,2))
		undo.add_theme_color_override("font_color",Color("c5d1dc"))
		undo.add_theme_color_override("font_disabled_color",Color("73858f"))
		undo.disabled = not receipt.error.is_empty()
		undo.tooltip_text = receipt.error
		undo.pressed.connect(func(): undo_requested.emit(int(receipt.operation_id)))

func _section(caption: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation",6)
	add_child(group)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",6)
	group.add_child(heading)
	_art(heading,"UI-title-cangku-jiantou",Vector2(13,25))
	var heading_text := _label(heading,caption,18,Color("d7e1e8"))
	heading_text.add_theme_font_override("font",ItemTooltip.summary_title_font())
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_box(PANEL_FILL,PANEL_BORDER,10,8))
	group.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",12)
	panel.add_child(content)
	return content

func _thumbnail(parent: Node, record: Dictionary, edge: float, height: float = -1) -> PanelContainer:
	return MapItemThumbnail.create(parent,record,edge,height)

func _pill(parent: Node) -> Label:
	var label := ItemTooltip.chip("—",ItemTooltip.CLASSIFICATION_COLOR)
	label.add_theme_font_override("font",ItemTooltip.summary_body_font())
	label.add_theme_font_size_override("font_size",13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _framed_icon(parent: Node, asset: String) -> void:
	var frame := PanelContainer.new()
	frame.name = "PreviewIconFrame"
	frame.custom_minimum_size = Vector2(43,43)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel",_box(Color("10212b"),Color("9a814c"),5,5))
	parent.add_child(frame)
	_art(frame,asset,Vector2(31,31))

func _label(parent: Node, text: String, font_size: int, color: Color = Color("d4dbd8")) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, width: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(width,34)
	button.add_theme_font_size_override("font_size",20)
	button.add_theme_color_override("font_color",Color("e8d99f"))
	button.add_theme_color_override("font_hover_color",Color("fff0bd"))
	button.add_theme_color_override("font_pressed_color",GOLD)
	button.add_theme_color_override("font_disabled_color",Color("958c6d"))
	button.add_theme_stylebox_override("normal",_box(Color("16303a"),Color("9a814c"),5,2))
	button.add_theme_stylebox_override("hover",_box(Color("28505a"),GOLD,5,2))
	button.add_theme_stylebox_override("pressed",_box(Color("10242a"),GOLD,5,2))
	button.add_theme_stylebox_override("disabled",_box(Color("10252f"),Color("655c3f"),5,2))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	return button

static func _box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style

static func _texture(asset: String) -> Texture2D:
	var source: Texture2D = load("res://assets/%s.webp" % asset)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Metrics.inspect(source).visible_rect
	return atlas

func _art(parent: Node, asset: String, bounds: Vector2) -> TextureRect:
	var art := TextureRect.new()
	art.texture = _texture(asset)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.custom_minimum_size = bounds
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art
