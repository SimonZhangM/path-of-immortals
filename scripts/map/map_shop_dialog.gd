class_name MapShopDialog
extends Control

signal cancelled
signal purchase_requested(item_id: String, quantity: int)
signal sale_requested(item_id: String, quantity: int)

const FRAME := Rect2(32,32,1474,840)
const GOLD := Color("f3d58c")
const METRICS = preload("res://scripts/map/map_texture_metrics.gd")
# Source-canvas slots retain the original eight positions. Future products reuse these
# positions by page, never add a ninth slot or individual item-specific geometry.
const SLOT_SIZE := Vector2(118,166)
const SLOT_ORIGIN := Vector2(634,375)
const SLOT_STEP := Vector2(136,180)
const TRADE_BUTTON_RECT := Rect2(1206,722,200,58)
var canvas: Control
var backing: TextureRect
var illustration: TextureRect
var picture_frame: TextureRect
var title_label: Label
var description_label: Label
var leave_button: Button
var sell_button: Button
var buy_tab: Button
var craft_tab: Button
var crafting_panel: Control
var trade_controls: Array[CanvasItem] = []
var filters: Dictionary = {}
var slots: Array[Button] = []
var slot_frames: Array[TextureRect] = []
var slot_contents: Array[Control] = []
var details: VBoxContainer
var detail_scroll: ScrollContainer
var previous_button: Button
var next_button: Button
var page_label: Label
var minus_button: TextureButton
var plus_button: TextureButton
var buy_button: TextureButton
var buy_label: Label
var quantity_label: Label
var price_label: Label
var total_label: Label
var balance_label: Label
var message: Label
var empty_label: Label
var shop: MapShop
var state: MapLoadoutState
var category := ""
var page := 0
var selected_id := ""
var quantity := 1
var busy := false
var selling := false
var crafting := false
var _visible_products: Array = []
var _kai := SystemFont.new()
var _song := SystemFont.new()
var _hei := SystemFont.new()

func _init() -> void:
	name = "MapShopDialog"
	z_index = 42
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	oversampling_with_scale = OVERSAMPLING_WITH_SCALE_ENABLED
	hide()
	_kai.font_names = PackedStringArray(["KaiTi","楷体","STKaiti","serif"])
	_song.font_names = PackedStringArray(["SimSun","宋体","Noto Serif CJK SC","serif"])
	_hei.font_names = PackedStringArray(["SimHei","黑体","Microsoft YaHei","sans-serif"])
	var shade := ColorRect.new()
	shade.color = Color(0.01,0.02,0.03,0.65)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	backing = _image(canvas,FRAME, null)
	title_label = _label(canvas,"",Rect2(704,107,465,70),52)
	title_label.add_theme_font_override("font",_hei)
	title_label.add_theme_color_override("font_color",MapGatheringDialog.INK)
	description_label = _label(canvas,"",Rect2(624,181,792,40),23)
	leave_button = _button("离开商铺",Rect2(1218,107,171,57),27)
	leave_button.add_theme_font_override("font",_hei)
	leave_button.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
	for state_name in ["font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		leave_button.add_theme_color_override(state_name,leave_button.get_theme_color("font_color"))
	leave_button.pressed.connect(func(): if not busy: cancelled.emit())
	# Match the reduced mode frames in the updated source artwork.
	buy_tab = _button("购买",Rect2(624,233,192,49),28)
	_style_tab(buy_tab,true)
	buy_tab.pressed.connect(func(): set_selling(false))
	sell_button = _button("出售",Rect2(828,233,185,49),28)
	_style_tab(sell_button,false)
	sell_button.pressed.connect(func(): set_selling(true))
	craft_tab = _button("打造",Rect2(1025,233,191,49),28)
	_style_tab(craft_tab,false)
	craft_tab.pressed.connect(set_crafting)
	craft_tab.hide()
	var trade_start := canvas.get_child_count()
	for index in MapShop.PAGE_SIZE:
		var origin := SLOT_ORIGIN + Vector2(index%4,index/4)*SLOT_STEP
		var frame := _image(canvas,Rect2(origin,SLOT_SIZE),load("res://assets/tanchuang-jiaoyi-shangpinbiankuang.webp"))
		frame.hide()
		slot_frames.append(frame)
		var holder := Control.new()
		holder.mouse_filter = MOUSE_FILTER_IGNORE
		_place(holder,Rect2(origin,SLOT_SIZE))
		slot_contents.append(holder)
		var button := _button("",Rect2(origin,SLOT_SIZE),20)
		button.name = "ProductSlot%d" % index
		button.add_theme_stylebox_override("hover",_selection_box(false))
		button.pressed.connect(func(): select_slot(index))
		slots.append(button)
	empty_label = _label(canvas,"暂无商品",Rect2(634,490,526,50),24,true)
	empty_label.hide()
	previous_button = _button("",Rect2(814,752,31,31),20)
	next_button = _button("",Rect2(948,752,31,31),20)
	previous_button.pressed.connect(func(): change_page(-1))
	next_button.pressed.connect(func(): change_page(1))
	page_label = _label(canvas,"1 / 1",Rect2(851,747,91,40),24,true)
	detail_scroll = ScrollContainer.new()
	detail_scroll.name = "ShopDetailScroll"
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_place(detail_scroll,Rect2(1199,320,216,286))
	details = VBoxContainer.new()
	details.size_flags_horizontal = SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",10)
	detail_scroll.add_child(details)
	for row in [["单价",624],["数量",655],["总价",685]]:
		_label(canvas,row[0],Rect2(1210,row[1],42,29),21).add_theme_color_override("font_color",GOLD)
	price_label = _price_row(Rect2(1258,624,145,29))
	total_label = _price_row(Rect2(1258,685,145,29))
	# Keep the midpoint fixed while reducing the clear 92px gap by 20%.
	minus_button = _texture_button("res://assets/tanchuang-jiaoyi-jianshao.webp",Rect2(1269.2,656,28,28))
	plus_button = _texture_button("res://assets/tanchuang-jiaoyi-zengjia.webp",Rect2(1370.8,656,28,28))
	for button: TextureButton in [minus_button,plus_button]:
		_add_quantity_hover(button)
	for y in [657.0,683.0]:
		var line := Line2D.new()
		line.name = "QuantityRail%d" % int(y)
		line.width = 1.0
		line.default_color = Color("a68e5b")
		line.points = PackedVector2Array([Vector2(1297.2,y)-FRAME.position,Vector2(1370.8,y)-FRAME.position])
		canvas.add_child(line)
	minus_button.pressed.connect(func(): change_quantity(-1))
	plus_button.pressed.connect(func(): change_quantity(1))
	quantity_label = _label(canvas,"1",Rect2(1289,655,90,29),23,true)
	buy_button = _texture_button("res://assets/tanchuang-baoxiang-dakai1.webp",TRADE_BUTTON_RECT)
	buy_button.texture_hover = _trimmed("res://assets/tanchuang-baoxiang-dakai2.webp")
	buy_button.texture_pressed = buy_button.texture_hover
	_match_purchase_art()
	buy_label = _label(canvas,"购买",TRADE_BUTTON_RECT,30,true)
	buy_label.add_theme_color_override("font_color",Color.WHITE)
	buy_button.mouse_entered.connect(_refresh_buy_color)
	buy_button.mouse_exited.connect(_refresh_buy_color)
	buy_button.pressed.connect(func():
		if busy or crafting or buy_button.disabled or selected_id.is_empty(): return
		if selling: sale_requested.emit(selected_id,quantity)
		else: purchase_requested.emit(selected_id,quantity)
	)
	for child: CanvasItem in canvas.get_children().slice(trade_start): trade_controls.append(child)
	balance_label = _label(canvas,"",Rect2(1044,240,372,37),19)
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message = _label(canvas,"",Rect2(623,797,794,23),17,true)
	message.add_theme_color_override("font_color",Color("ebd6a9"))
	trade_controls.append(message)
	# Empty reserved content area; future crafting UI attaches here.
	crafting_panel = Control.new()
	crafting_panel.name = "CraftingContent"
	crafting_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_place(crafting_panel,Rect2(623,300,804,492))
	crafting_panel.hide()
	resized.connect(_layout)

func _place(control: Control, rect: Rect2) -> void:
	canvas.add_child(control)
	control.position = rect.position-FRAME.position
	control.size = rect.size

func _image(parent: Node, rect: Rect2, texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(image)
	image.position = rect.position-(FRAME.position if parent==canvas else Vector2.ZERO)
	image.size = rect.size
	return image

func _label(parent: Node, text: String, rect: Rect2, font_size: int, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font",_kai)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("f8ecc8"))
	parent.add_child(label)
	if not parent is Container:
		label.position = rect.position-(FRAME.position if parent==canvas else Vector2.ZERO)
		label.size = rect.size
	return label

func _button(text: String, rect: Rect2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = FOCUS_NONE
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_override("font",_kai)
	button.add_theme_font_size_override("font_size",font_size)
	button.add_theme_color_override("font_color",Color("f8ecc8"))
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	for kind in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(kind,StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover",_selection_box())
	_place(button,rect)
	return button

func _selection_box(fill := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = fill
	box.bg_color = Color(0.9,0.72,0.32,0.12)
	box.border_color = GOLD
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	return box

func _style_tab(button: Button, selected: bool) -> void:
	button.add_theme_font_override("font",_hei)
	button.add_theme_color_override("font_color",Color("fff4c9") if selected else Color("e5dcc5"))
	button.add_theme_color_override("font_hover_color",Color("fffbea"))
	var style := _selection_box()
	style.bg_color = Color(0.92,0.73,0.35,0.28)
	style.border_color = Color("ffe4a1")
	style.set_border_width_all(2)
	style.shadow_color = Color(1.0,0.78,0.35,0.17)
	style.shadow_size = 5
	button.add_theme_stylebox_override("normal",style if selected else StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover",style)

# Scale only the image about its own center; surrounding labels keep their slots.
func _scale_art(control: Control, area_ratio: float) -> void:
	control.scale = Vector2.ONE*sqrt(area_ratio)
	var center := func(): control.pivot_offset = control.size*0.5
	control.resized.connect(center)
	center.call_deferred()

func _thumbnail(parent: Node, record: Dictionary, edge: float) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2.ONE*edge
	slot.size = slot.custom_minimum_size
	slot.size_flags_vertical = SIZE_SHRINK_CENTER
	slot.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(slot)
	var art := MapItemThumbnail.create(slot,record,edge,-1,0.85)
	_scale_art(art,0.9)
	return slot

func _coin(parent: Node, path: String, minimum: Vector2) -> void:
	var slot := Control.new()
	slot.custom_minimum_size = minimum
	slot.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(slot)
	var coin := _image(slot,Rect2(),_trimmed(path))
	coin.name = "ShopCoin"
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_scale_art(coin,0.8)

func _trimmed(path: String) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = METRICS.inspect(atlas.atlas).visible_rect
	return atlas

func _match_purchase_art() -> void:
	# Preserve the current hover draw rectangle, then map the idle opaque body
	# to that same rectangle. Source canvas/glow bounds are not body bounds.
	var reference := buy_button.texture_hover as AtlasTexture
	var idle := buy_button.texture_normal as AtlasTexture
	var reference_body := METRICS.solid_rect(reference.atlas)
	var idle_body := METRICS.solid_rect(idle.atlas)
	var ratio := idle_body.size/reference_body.size
	idle.region = Rect2(idle_body.position-(reference_body.position-reference.region.position)*ratio,reference.region.size*ratio)
	var factor := minf(buy_button.size.x/reference.get_width(),buy_button.size.y/reference.get_height())
	var draw_size := reference.get_size()*factor
	buy_button.position += (buy_button.size-draw_size)*0.5
	buy_button.size = draw_size
	buy_button.stretch_mode = TextureButton.STRETCH_SCALE

func _texture_button(path: String, rect: Rect2) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _trimmed(path)
	button.texture_disabled = button.texture_normal
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = FOCUS_NONE
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_place(button,rect)
	return button

func _add_quantity_hover(button: TextureButton) -> void:
	var highlight := Panel.new()
	highlight.name = "QuantityHover"
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.add_theme_stylebox_override("panel",_selection_box())
	button.add_child(highlight)
	highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	highlight.hide()
	button.mouse_entered.connect(func(): highlight.visible = not button.disabled)
	button.mouse_exited.connect(highlight.hide)

func _price_row(rect: Rect2) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",5)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	_place(row,rect)
	_coin(row,"res://assets/tanchuang-jiaoyi-coin.webp",Vector2(21,23))
	return _label(row,"",Rect2(),22)

func present(event: Dictionary, catalog: MapShop, loadout: MapLoadoutState) -> void:
	if shop!=null and shop.pricing.changed.is_connected(_refresh_page): shop.pricing.changed.disconnect(_refresh_page)
	if state!=null and state.changed.is_connected(_on_inventory_changed): state.changed.disconnect(_on_inventory_changed)
	shop = catalog
	state = loadout
	shop.pricing.changed.connect(_refresh_page)
	state.changed.connect(_on_inventory_changed)
	var atlas := AtlasTexture.new()
	atlas.atlas = load(event.presentation.background)
	atlas.region = FRAME
	backing.texture = atlas
	if is_instance_valid(illustration): illustration.free()
	if is_instance_valid(picture_frame): picture_frame.free()
	var frame_texture := _trimmed(event.presentation.frame)
	var rect := Rect2(Vector2(349,451)-frame_texture.get_size()*0.5,frame_texture.get_size())
	illustration = _image(canvas,rect.grow(-5),load(event.presentation.illustration))
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	illustration.clip_contents = true
	picture_frame = _image(canvas,rect,frame_texture)
	title_label.text = shop.definition.title
	# Logo is baked into the original artwork. Move only the title; compensate
	# the blackface font's visible glyph center by one source pixel.
	title_label.position.y = float(event.presentation.get("title_center_y",133.0))+1.0-title_label.size.y*0.5-FRAME.position.y
	description_label.text = shop.definition.description
	leave_button.text = shop.definition.get("leave_label","离开商铺")
	craft_tab.visible = shop.definition.get("crafting_tab",false)
	craft_tab.text = shop.definition.get("crafting_label","打造")
	var balance_rect := Rect2(1224,240,192,37) if craft_tab.visible else Rect2(1044,240,372,37)
	balance_label.position = balance_rect.position-FRAME.position
	balance_label.size = balance_rect.size
	message.text = ""
	for filter: Button in filters.values(): filter.free()
	filters.clear()
	var categories := shop.categories()
	for index in categories.size():
		var key: String = categories[index].id
		var filter := _button(categories[index].label,Rect2(625+index*136,310,136,52),24)
		_style_tab(filter,false)
		filter.pressed.connect(func(): set_category(key))
		filters[key] = filter
	category = categories[0].id
	page = 0
	selected_id = ""
	selling = false
	crafting = false
	_refresh_trade_art()
	set_busy(false)
	show()
	_refresh_page()
	_layout()

func set_selling(value: bool) -> void:
	if busy or (not crafting and selling==value): return
	crafting = false
	selling = value
	page = 0
	selected_id = ""
	quantity = 1
	message.text = ""
	_refresh_trade_art()
	_refresh_page()

func set_crafting() -> void:
	if busy or crafting or not shop.definition.get("crafting_tab",false): return
	crafting = true
	selling = false
	page = 0
	selected_id = ""
	quantity = 1
	message.text = ""
	_refresh_trade_art()
	_refresh_page()

func _refresh_trade_art() -> void:
	var prefix := "res://assets/tanchuang-huifu-cangku" if selling else "res://assets/tanchuang-baoxiang-dakai"
	buy_button.texture_normal = _trimmed(prefix+"1.webp")
	buy_button.texture_hover = _trimmed(prefix+"2.webp")
	buy_button.texture_pressed = buy_button.texture_hover
	buy_button.texture_disabled = buy_button.texture_normal
	# Reset the slot before calibrating each pair, so mode switches never shrink it.
	buy_button.position = TRADE_BUTTON_RECT.position-FRAME.position
	buy_button.size = TRADE_BUTTON_RECT.size
	_match_purchase_art()
	buy_label.text = "出售" if selling else "购买"
	buy_button.tooltip_text = ""
	_style_tab(buy_tab,not selling and not crafting)
	_style_tab(sell_button,selling)
	_style_tab(craft_tab,crafting)

func _on_inventory_changed() -> void:
	if not visible: return
	if selling or crafting: _refresh_page(not busy)
	else: refresh_checkout()

func _products() -> Array:
	if crafting: return []
	return shop.sale_items(state,category) if selling else shop.products(category)

func _unit_price(item_id: String) -> int:
	return shop.pricing.sell_unit_price(item_id) if selling else shop.buy_unit_price(item_id)

func _quantity_limit() -> int:
	if not selling: return MapShop.MAX_QUANTITY
	return mini(MapShop.MAX_QUANTITY,_available_quantity())

func _available_quantity() -> int:
	for row: Dictionary in _visible_products:
		if row.item_id==selected_id: return int(row.quantity)
	return 0

func set_category(value: String) -> void:
	if busy or crafting or not filters.has(value): return
	category = value
	page = 0
	_refresh_page()

func change_page(delta: int) -> void:
	if busy or crafting: return
	page = clampi(page+delta,0,maxi(0,ceili(_products().size()/float(MapShop.PAGE_SIZE))-1))
	_refresh_page()

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _refresh_page(auto_select := true) -> void:
	crafting_panel.visible = crafting
	for control: CanvasItem in trade_controls: control.visible = not crafting
	for filter: Button in filters.values(): filter.visible = not crafting
	if crafting:
		_visible_products = []
		selected_id = ""
		_clear(details)
		refresh_checkout()
		return
	var products := _products()
	page = clampi(page,0,maxi(0,ceili(products.size()/float(MapShop.PAGE_SIZE))-1))
	_visible_products = products.slice(page*8,page*8+8)
	empty_label.text = "暂无可出售物品" if selling else "暂无商品"
	empty_label.visible = products.is_empty()
	for key: String in filters:
		_style_tab(filters[key],key==category)
	for index in 8:
		_clear(slot_contents[index])
		slots[index].visible = index < _visible_products.size()
		slot_frames[index].visible = slots[index].visible
		slot_contents[index].visible = slots[index].visible
		if index>=_visible_products.size(): continue
		var row: Dictionary = _visible_products[index]
		var record: Dictionary = state.records[row.item_id]
		var thumbnail := _thumbnail(slot_contents[index],record,98)
		thumbnail.position = Vector2(10,8)
		if selling and int(row.quantity)>1:
			var amount := HBoxContainer.new()
			amount.name = "AvailableQuantity"
			amount.position = Vector2(4,80)
			amount.size = Vector2(101,27) # Right edge moves 3 source pixels left.
			amount.alignment = BoxContainer.ALIGNMENT_END
			amount.add_theme_constant_override("separation",0)
			amount.mouse_filter = MOUSE_FILTER_IGNORE
			slot_contents[index].add_child(amount)
			var mark := _label(amount,"×",Rect2(),17)
			var number := _label(amount,str(int(row.quantity)),Rect2(),19)
			for label: Label in [mark,number]:
				label.add_theme_color_override("font_color",Color.WHITE)
				label.add_theme_color_override("font_outline_color",Color.BLACK)
				label.add_theme_constant_override("outline_size",2)
		var item_name := _label(slot_contents[index],record.name,Rect2(3,109,112,26),20,true)
		item_name.add_theme_font_override("font",_song)
		item_name.add_theme_color_override("font_color",Color.WHITE)
		var price_row := HBoxContainer.new()
		price_row.position = Vector2(4,137)
		price_row.size = Vector2(110,25)
		price_row.alignment = BoxContainer.ALIGNMENT_CENTER
		price_row.mouse_filter = MOUSE_FILTER_IGNORE
		slot_contents[index].add_child(price_row)
		_coin(price_row,"res://assets/player-status-coin.webp",Vector2(18,21))
		var price := _unit_price(row.item_id)
		_label(price_row,str(price) if price>=0 else "待定",Rect2(),21)
	page_label.text = "%d / %d" % [page+1,maxi(1,ceili(products.size()/8.0))]
	previous_button.disabled = page==0
	next_button.disabled = (page+1)*8>=products.size()
	if not _visible_products.any(func(row): return row.item_id==selected_id):
		selected_id = ""
		quantity = 1
		if auto_select and not _visible_products.is_empty(): selected_id = _visible_products[0].item_id
	_refresh_selection()

func select_slot(index: int) -> void:
	if busy or crafting or index<0 or index>=_visible_products.size(): return
	selected_id = _visible_products[index].item_id
	quantity = 1
	message.text = ""
	_refresh_selection()

func _refresh_selection() -> void:
	for index in _visible_products.size():
		slots[index].add_theme_stylebox_override("normal",_selection_box(false) if _visible_products[index].item_id==selected_id else StyleBoxEmpty.new())
	_clear(details)
	if selected_id.is_empty():
		refresh_checkout()
		return
	var record: Dictionary = state.records[selected_id]
	var item := state.registry.get_item(selected_id)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",9)
	details.add_child(heading)
	_thumbnail(heading,record,64)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.add_child(text)
	var label := _label(text,record.name,Rect2(),22)
	ItemTooltip.style_item_title(label,22)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation",4)
	tags.add_theme_constant_override("v_separation",4)
	text.add_child(tags)
	var categories := ItemTooltip.classification_tags(item)
	categories.push_front(record.quality)
	for tag: String in categories:
		var chip := ItemTooltip.chip(tag,ItemTooltip.CLASSIFICATION_COLOR)
		chip.add_theme_font_override("font",ItemTooltip.summary_body_font())
		chip.add_theme_font_size_override("font_size",13)
		tags.add_child(chip)
	if selling:
		var available := _label(details,"可售数量：%d" % _available_quantity(),Rect2(),18)
		available.name = "AvailableQuantity"
		available.add_theme_color_override("font_color",GOLD)
	var flavor: String = item.combat.get("flavor_description","")
	if not flavor.is_empty():
		var prose := _label(details,"“%s”" % flavor,Rect2(),16)
		prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prose.add_theme_color_override("font_color",ItemTooltip.CLASSIFICATION_COLOR)
	details.add_child(HSeparator.new())
	_label(details,"效果说明",Rect2(),19).add_theme_color_override("font_color",GOLD)
	var effects := RichTextLabel.new()
	effects.name = "RealItemEffects"
	effects.bbcode_enabled = true
	effects.fit_content = true
	effects.scroll_active = false
	effects.add_theme_font_override("normal_font",ItemTooltip.summary_body_font())
	effects.add_theme_font_override("bold_font",ItemTooltip.summary_title_font())
	effects.add_theme_font_size_override("normal_font_size",17)
	effects.add_theme_font_size_override("bold_font_size",17)
	effects.add_theme_color_override("default_color",Color("d8dee7"))
	effects.text = ItemTooltip._colored(ItemTooltip.effect_text(item),ItemTooltip.highlighted_keywords(),17)
	details.add_child(effects)
	detail_scroll.scroll_vertical = 0
	refresh_checkout()

func change_quantity(delta: int) -> void:
	if busy or crafting: return
	quantity = clampi(quantity+delta,1,maxi(1,_quantity_limit()))
	message.text = ""
	refresh_checkout()

func refresh_checkout() -> void:
	if state==null or shop==null: return
	var limit := _quantity_limit()
	quantity = clampi(quantity,1,maxi(1,limit))
	var price := _unit_price(selected_id)
	price_label.text = str(price) if price>=0 else ("待定" if not selected_id.is_empty() else "—")
	total_label.text = str(price*quantity) if price>=0 else "—"
	quantity_label.text = str(quantity)
	balance_label.text = "持有灵石：%d" % state.spirit_stones
	minus_button.disabled = busy or selected_id.is_empty() or quantity<=1
	plus_button.disabled = busy or selected_id.is_empty() or quantity>=limit
	for button: TextureButton in [minus_button,plus_button]:
		button.get_node("QuantityHover").visible = not button.disabled and button.is_hovered()
	buy_button.disabled = busy or crafting or selected_id.is_empty() or price<0 or limit<=0
	buy_button.tooltip_text = "价格待定，暂不能交易。" if price<0 and not selected_id.is_empty() else ""
	total_label.add_theme_color_override("font_color",Color("f1a598") if not selling and price*quantity>state.spirit_stones else GOLD)
	_refresh_buy_color()

func set_busy(value: bool) -> void:
	busy = value
	leave_button.disabled = value
	buy_tab.disabled = value
	sell_button.disabled = value
	craft_tab.disabled = value
	refresh_checkout()

func _refresh_buy_color() -> void:
	var hovered := buy_button.is_hovered() and not buy_button.disabled
	buy_button.texture_disabled = buy_button.texture_normal
	buy_label.add_theme_color_override("font_color",Color.BLACK if hovered else Color.WHITE)

func _layout() -> void:
	var factor := minf(size.x/1920.0,size.y/1080.0)*0.9
	canvas.size = FRAME.size
	canvas.scale = Vector2.ONE*factor
	canvas.position = ((size-FRAME.size*factor)*0.5).round()

func _gui_input(_event: InputEvent) -> void:
	accept_event()
