class_name MapInnDialog
extends MapClinicDialog

signal lodging_requested(room_id: String)
signal food_purchase_requested(item_id: String, quantity: int)

# Reuse the common scene frame and dialogue canvas.
var food_tab: Button
var lodging_tab: Button
var food_content: Control
var lodging_content: MapInnLodgingView
var food_shop: MapShop
var food_view: MapInnFoodView

func _init() -> void:
	super()
	name = "MapInnDialog"
	treatment_tab.hide()
	food_tab = _button("吃食",Rect2(828,233,185,49),28)
	lodging_tab = _button("住宿",Rect2(1025,233,192,49),28)
	food_tab.pressed.connect(func(): set_mode("food"))
	lodging_tab.pressed.connect(func(): set_mode("lodging"))
	food_content = _content_area("FoodContent")
	food_view = MapInnFoodView.new()
	add_child(food_view)
	food_view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	food_view.purchase_requested.connect(func(item_id: String, quantity: int): food_purchase_requested.emit(item_id,quantity))
	lodging_content = MapInnLodgingView.new()
	_place(lodging_content,Rect2(624,309,806,503))
	lodging_content.confirmed.connect(func(room_id: String): lodging_requested.emit(room_id))
	leave_button.add_theme_color_override("font_hover_color",Color("fffbea"))
	leave_button.add_theme_color_override("font_pressed_color",Color("e5c985"))

func present(event: Dictionary, loadout: MapLoadoutState = null, status: MapPlayerStatus = null) -> void:
	if loadout!=null and event.has("food_catalog"):
		food_shop = MapShop.new()
		var error := food_shop.load_catalog(event.food_catalog,loadout)
		if error.is_empty(): food_view.present_menu(event,food_shop,loadout)
		else: push_error(error)
	lodging_content.configure(event.get("lodging",{}),loadout)
	super.present(event,loadout,status)

func set_mode(value: String) -> void:
	if value not in ["conversation","food","lodging"]: return
	_continue_pointer_down = false
	mode = value
	treatment_tab.hide()
	treatment_content.hide()
	conversation_content.visible = mode=="conversation"
	conversation_options.visible = mode=="conversation"
	dialogue_note.visible = mode=="conversation"
	food_content.visible = mode=="food"
	food_view.visible = mode=="food" and food_shop!=null
	lodging_content.visible = mode=="lodging"
	if mode=="lodging": lodging_content.refresh()
	_refresh_continue_hint()
	_style_tab(conversation_tab,mode=="conversation")
	_style_tab(food_tab,mode=="food")
	_style_tab(lodging_tab,mode=="lodging")
	var key := "background" if mode=="conversation" else mode+"_background"
	var path: String = _presentation.get(key,"")
	if not path.is_empty():
		var atlas := AtlasTexture.new()
		atlas.atlas = load(path)
		atlas.region = FRAME
		backing.texture = atlas
