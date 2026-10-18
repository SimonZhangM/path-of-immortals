extends SceneTree

var checks := 0
var failures := 0
const POINT := "base.map.qingshizhen.point.n16"
const EVENT := "base.map_event.qingshizhen.shop"
const SHOP_PATH := "res://data/shops/qingshizhen_shop.json"

func _initialize() -> void: run.call_deferred()
func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+text)
func settle() -> void:
	for frame in 8: await process_frame
func click(control: Control) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
	await settle()
func count(state: MapLoadoutState, id: String) -> int:
	var amount := 0
	for entry: Dictionary in state.storage.entries():
		if entry.item_id==id: amount += entry.units.size()
	return amount

func transactions(map: Node) -> void:
	var prepared := MapLoadoutStore.candidate(map.loadout)
	var state: MapLoadoutState = prepared.state
	var shop: MapShop = map.shops[EVENT]
	var id: String = shop.products()[0].item_id
	var price := shop.buy_unit_price(id)
	var snapshot := state.snapshot()
	check(not shop.purchase(state,id,1,"").is_empty(),"zero funds rejected")
	check(state.snapshot()==snapshot,"failed purchase does not modify ownership or wallet")
	state.spirit_stones = 10000
	snapshot = state.snapshot()
	for quantity in [0,-1,1000]:
		check(not shop.purchase(state,id,quantity,"").is_empty(),"invalid quantity refused")
	check(not shop.purchase(state,"base.item.unknown",1,"").is_empty(),"unknown product refused")
	check(not shop.purchase(state,id,2,"res://artifacts/no-shop-directory/save.json").is_empty(),"save failure returned")
	check(state.snapshot()==snapshot,"save failure atomic: neither money nor units published")
	var path := "res://artifacts/shop-purchase-%d.json" % Time.get_ticks_usec()
	var before := count(state,id)
	check(shop.purchase(state,id,3,path).is_empty(),"purchase saves")
	check(state.spirit_stones==10000-price*3 and count(state,id)==before+3,"exact price debit and item credit")
	check(state.purchase_serial==1,"serial advanced")
	var loaded: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	check(MapLoadoutStore.load_into(loaded,path).is_empty(),"restart load")
	check(loaded.spirit_stones==state.spirit_stones and count(loaded,id)==before+3,"money and items survive restart")
	check(shop.purchase(loaded,id,1,path).is_empty(),"second purchase")
	check(loaded.purchase_serial==2 and count(loaded,id)==before+4,"unique repeated purchase units")
	var bad := loaded.snapshot()
	bad.spirit_stones = -1
	check(not loaded.restore(bad).is_empty(),"corrupt wallet rejected")
	bad = loaded.snapshot()
	bad.erase("spirit_stones")
	bad.erase("purchase_serial")
	check(loaded.restore(bad).is_empty() and loaded.spirit_stones==0,"legacy save migration keeps inventory and zero initial funds")
	var raw := shop.definition.duplicate(true)
	raw.products[0].preview_buy_price = -5
	check(not MapShop.new().configure(raw,state).is_empty(),"invalid catalog price refused")
	# The wallet is in the existing durable snapshot, including battle persistence.
	var copy: MapLoadoutState = MapLoadoutStore.candidate(state).state
	check(copy.spirit_stones==state.spirit_stones and copy.purchase_serial==state.purchase_serial,"durable candidate preserves wallet")

func interaction(map: Node) -> void:
	var dialog: MapShopDialog = map.shop_dialog
	check(dialog.page==0 and dialog.previous_button.disabled and not dialog.next_button.disabled,"first of two category pages")
	for key in ["weapon","armor"]:
		await click(dialog.filters[key])
		check(dialog.category==key and dialog._visible_products.size()==(9 if key=="weapon" else 10) and not dialog.next_button.disabled,"category filters "+key)
	for key in ["food","grocery"]:
		await click(dialog.filters[key])
		check(dialog.category==key and dialog._visible_products.is_empty() and dialog.buy_button.disabled,"reserved category empty "+key)
	await click(dialog.filters.armor)
	await click(dialog.slots[1])
	check(dialog.details.get_node("RealItemEffects").get_parsed_text().contains("紧贴"),"iron armor uses actual set-effect description")
	check(dialog.details.size.y>dialog.detail_scroll.size.y,"long details scroll instead of overflowing checkout")
	var scroll := InputEventMouseButton.new()
	scroll.button_index = MOUSE_BUTTON_WHEEL_DOWN
	scroll.pressed = true
	scroll.position = dialog.detail_scroll.get_global_rect().get_center()
	root.push_input(scroll,true)
	scroll = scroll.duplicate()
	scroll.pressed = false
	root.push_input(scroll,true)
	await settle()
	check(dialog.detail_scroll.scroll_vertical>0,"wheel scrolls long effects")
	await click(dialog.filters.weapon)
	await click(dialog.slots[6])
	check(dialog.selected_id=="base.map_item.t01_0049","slot selects real lightning whip")
	check(dialog.details.get_node("RealItemEffects").get_parsed_text().contains("冷却"),"real effect text")
	await click(dialog.plus_button)
	check(dialog.quantity==2,"plus actual click")
	await click(dialog.minus_button)
	check(dialog.quantity==1 and dialog.minus_button.disabled,"minus clamp")
	dialog.change_quantity(10000)
	check(dialog.quantity==999 and dialog.plus_button.disabled,"quantity ceiling")
	dialog.change_quantity(-10000)
	await click(dialog.buy_button)
	check(dialog.message.text.contains("灵石不足"),"insufficient funds visible")
	var next: Dictionary = map.loadout.snapshot()
	next.spirit_stones = 10000
	check(map.loadout.restore(next).is_empty(),"isolated test funding")
	dialog.refresh_checkout()
	var before := count(map.loadout,dialog.selected_id)
	var expected_balance: int = 10000-dialog.shop.buy_unit_price(dialog.selected_id)
	await click(dialog.buy_button)
	check(count(map.loadout,dialog.selected_id)==before+1,"buy native click delivers item")
	check(map.player_status.spirit_stones==expected_balance and dialog.balance_label.text.contains(str(expected_balance)),"header and checkout sync money")
	check(dialog.message.text.contains("已购买"),"success message")
	var motion := InputEventMouseMotion.new()
	motion.position = dialog.buy_button.get_global_rect().get_center()
	root.push_input(motion,true)
	await settle()
	check(dialog.buy_label.get_theme_color("font_color")==Color.BLACK,"buy hover black KaiTi")
	var snapshot: Dictionary = map.loadout.snapshot()
	await click(dialog.leave_button)
	check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused,"leave closes reusable shop")
	check(map.loadout.snapshot()==snapshot and not map.event_state.completed.has(EVENT),"leaving does not spend or complete sign")
	check(map._try_start_event(POINT,"click",true),"reopen stationary shop")
	await settle()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	await settle()
	check(not dialog.visible,"escape closes shop")
	check(map._try_start_event(POINT,"click",true),"reopen after escape")
	await settle()
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	root.push_input(right,true)
	await settle()
	check(not dialog.visible,"right-click closes shop")

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	MapEventState.session_completed.clear()
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	current_scene = map
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town starts: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	check(map.event_registry.by_point.get(POINT)==EVENT,"N16 shop binding")
	var origin: String = map.travel.adjacency[POINT][0].to
	map.travel.current_node_id = origin
	map.travel.map_position = map.travel.node_positions[origin]
	map.travel.mode = "idle"
	check(map.travel.request_destination(POINT),"route to shop")
	map.travel.advance(1000)
	await settle()
	var dialog: MapShopDialog = map.shop_dialog
	check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused,"arrival does not open modal shop")
	check(map._try_start_event(POINT,"click",true),"manual click opens shop")
	await settle()
	check(dialog.visible and map.event_state.phase=="shop" and map.travel.paused,"manual interaction opens modal shop")
	check(map.shops[EVENT].products().size()==19 and dialog.slots.size()==8,"19 general products in eight reusable slots")
	check(not dialog.sell_button.disabled,"sale preview tab available")
	for key in ["weapon","armor"]:
		check(map.shops[EVENT].products(key).size()==(9 if key=="weapon" else 10),"state-source stock per category: "+key)
	for row: Dictionary in map.shops[EVENT].products():
		var item: ItemData = map.loadout.registry.get_item(row.item_id)
		check(not ItemTooltip.effect_text(item).is_empty(),"real effect exists: "+item.display_name)
		check(not ItemTooltip.classification_tags(item).is_empty(),"classification exists: "+item.display_name)
	check(dialog.title_label.text=="青石商铺" and dialog.description_label.text.contains("云游四方"),"reference title and copy")
	check(dialog.picture_frame.get_global_rect().get_center().is_equal_approx(dialog.illustration.get_global_rect().get_center()),"scene and frame concentric")
	print("SCENE FRAME ",dialog.picture_frame.position," / ",dialog.picture_frame.size)
	for file in ["tanchuang-jiaoyi-coin","tanchuang-jiaoyi-jianshao","tanchuang-jiaoyi-qingshizhen-shangpu-boss","tanchuang-jiaoyi-qingshizhen-shangpu","tanchuang-jiaoyi-shangpinbiankuang","tanchuang-jiaoyi-zengjia","tanchuang-tongyong-chuangjingbiankuang"]:
		var settings := ConfigFile.new()
		settings.load("res://assets/%s.webp.import" % file)
		check(settings.get_value("params","mipmaps/generate",false),"mipmap "+file)
	for label: Label in [dialog.title_label,dialog.description_label,dialog.page_label,dialog.price_label,dialog.total_label]:
		check(label.get_visible_line_count()==label.get_line_count(),"text fits "+label.text)
	if DisplayServer.get_name()=="headless":
		transactions(map)
		await interaction(map)
	else:
		dialog.select_slot(6)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/shop-qingshizhen.png")
	map.queue_free()
	await settle()
	print("SHOP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
