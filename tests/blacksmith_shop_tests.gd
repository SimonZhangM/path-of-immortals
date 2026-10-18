extends "res://tests/map_shop_tests.gd"

const FORGE_EVENT := "base.map_event.qingshizhen.blacksmith"
const FORGE_POINT := "base.map.qingshizhen.point.n23"
const ORE := "base.material.cutiekuang"
const HIDE := "base.material.cslz_hide"
const NEEDLE := "base.map_item.t01_0111"

func open_forge(map: Node) -> void:
	map.travel.current_node_id = FORGE_POINT
	map.travel.map_position = map.travel.node_positions[FORGE_POINT]
	map.travel.mode = "idle"
	map.travel.node_arrived.emit(FORGE_POINT)
	await settle()
	check(not map.event_state.is_active() and not map.shop_dialog.visible and not map.travel.paused,"N23 arrival does not open blacksmith")
	check(map._try_start_event(FORGE_POINT,"click",true),"click opens blacksmith at N23")
	await settle()
	check(map.event_state.active_id==FORGE_EVENT and map.shop_dialog.visible and map.travel.paused,"manual blacksmith interaction pauses travel")

func verify_crafting(dialog: MapShopDialog) -> void:
	check(dialog.crafting and dialog.crafting_panel.visible and dialog.crafting_panel.get_child_count()==0,"craft page is selectable with empty reserved content")
	check(dialog.selected_id.is_empty() and dialog._visible_products.is_empty(),"craft page clears trade selection")
	check(dialog.trade_controls.all(func(control): return not control.visible),"craft page hides products, details, quantity and checkout")
	check(dialog.filters.values().all(func(button): return not button.visible),"craft page has no trade filters")
	check(dialog.buy_button.disabled and not dialog.leave_button.disabled,"no craft checkout; leave remains usable")

func exercise(map: Node) -> void:
	var dialog: MapShopDialog = map.shop_dialog
	var shop: MapShop = map.shops[FORGE_EVENT]
	check(dialog.category=="ore" and dialog._visible_products.size()==2,"both existing ores stocked")
	await click(dialog.sell_button)
	check(dialog.selling and dialog.selected_id==ORE,"sell mode lists carried ore")
	var before: Dictionary = map.loadout.snapshot()
	var amount := count(map.loadout,ORE)
	var wallet: int = map.loadout.spirit_stones
	await click(dialog.plus_button)
	check(dialog.quantity==2,"sale quantity increment")
	await click(dialog.buy_button)
	check(count(map.loadout,ORE)==amount-2 and map.loadout.spirit_stones==wallet+2*shop.pricing.sell_unit_price(ORE),"ore sale commits exact units and money")
	check(dialog.message.text.contains("已出售"),"sale result shown")
	await click(dialog.filters.material)
	check(dialog.selected_id==HIDE,"beast materials mapped to material tab")
	await click(dialog.buy_button)
	check(count(map.loadout,HIDE)==0,"beast material can be sold")
	await click(dialog.buy_tab)
	await click(dialog.filters.throwable)
	check(dialog._visible_products.size()==2 and dialog.selected_id==NEEDLE,"existing throwing stock available")
	amount = count(map.loadout,NEEDLE)
	wallet = map.loadout.spirit_stones
	await click(dialog.plus_button)
	await click(dialog.buy_button)
	check(count(map.loadout,NEEDLE)==amount+2 and map.loadout.spirit_stones==wallet-2*shop.buy_unit_price(NEEDLE),"throwing weapon purchase commits at shared price")
	var reloaded: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	check(MapLoadoutStore.load_into(reloaded,map.inventory_save_path).is_empty() and reloaded.snapshot()==map.loadout.snapshot(),"blacksmith transactions survive disk reload")
	check(map.loadout.calendar==before.calendar,"trading does not spend days")
	for mode in [dialog.buy_tab,dialog.sell_button]:
		await click(dialog.craft_tab)
		verify_crafting(dialog)
		var snapshot: Dictionary = map.loadout.snapshot()
		dialog.buy_button.pressed.emit()
		dialog.purchase_requested.emit(NEEDLE,1)
		dialog.sale_requested.emit(ORE,1)
		shop.pricing.changed.emit()
		map.loadout.changed.emit()
		check(map.loadout.snapshot()==snapshot,"crafting cannot emit a live trade or mutate inventory/time")
		verify_crafting(dialog)
		await click(mode)
		check(not dialog.crafting and not dialog.crafting_panel.visible and dialog.filters.throwable.visible,"return from crafting restores trading")
		check(dialog.selling==(mode==dialog.sell_button),"selected trade mode restored")
	await click(dialog.filters.equipment_recipe)
	check(dialog._visible_products.is_empty() and dialog.buy_button.disabled,"unimplemented recipes remain empty")
	await click(dialog.craft_tab)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = dialog.craft_tab.get_global_rect().get_center()
	root.push_input(right,true)
	await settle()
	check(not dialog.visible and not map.event_state.is_active() and not map.travel.paused,"right click exits craft page")
	check(map._try_start_event(FORGE_POINT,"click",true),"blacksmith can reopen while staying at N23")
	await settle()
	check(not dialog.crafting and not dialog.selling and dialog.category=="ore","reopening resets to buy page")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	await settle()
	check(not dialog.visible and not map.event_state.completed.has(FORGE_EVENT),"escape closes without consuming blacksmith event")
	map.travel.current_node_id = POINT
	map.travel.mode = "idle"
	check(map._try_start_event(POINT,"click",true),"normal shop still opens")
	await settle()
	check(not dialog.craft_tab.visible and dialog.leave_button.text=="离开商铺","normal shop stays two modes")
	check(dialog.balance_row.get_rect()==Rect2(Vector2(1224,260)-dialog.FRAME.position,Vector2(192,28)),"normal shop uses shared lower wallet row")
	check(dialog._visible_products.size()==8 and dialog.category=="weapon","normal stock restored")
	dialog.set_crafting()
	check(not dialog.crafting,"normal shop cannot enter craft mode")
	await click(dialog.leave_button)
	check(not dialog.visible and not map.event_state.is_active(),"leave button works after switching shops")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2560,1440)
	var map = load("res://scenes/maps/qingshizhen.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"town and both shops load: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	var fixture: Dictionary = map.loadout.snapshot()
	fixture.spirit_stones = 1000
	for index in 3: fixture.owned_units["forge.ore.%d" % index] = ORE
	fixture.owned_units["forge.hide"] = HIDE
	check(map.loadout.restore(fixture).is_empty(),"isolated mineral/material fixture")
	if DisplayServer.get_name()=="headless": map.inventory_save_path = "res://artifacts/blacksmith-%d.json" % Time.get_ticks_usec()
	await open_forge(map)
	var dialog: MapShopDialog = map.shop_dialog
	check(dialog.title_label.text=="铁匠铺" and dialog.leave_button.text=="离开铁匠铺","blacksmith captions")
	check("|".join(dialog.filters.values().map(func(b):return b.text))=="矿石|材料|暗器|器方","four approved trade categories")
	check(dialog.craft_tab.visible and dialog.craft_tab.text=="打造","third mode enabled by catalog")
	check(not dialog.craft_tab.get_global_rect().intersects(dialog.balance_label.get_global_rect()),"wallet avoids third tab")
	check(dialog.backing.texture.atlas.resource_path.ends_with("tiejiangpu.webp") and dialog.illustration.texture.resource_path.ends_with("tiejiangpu-boss.webp"),"uses both dedicated artworks")
	for texture: Texture2D in [dialog.backing.texture.atlas,dialog.illustration.texture]: check(texture.get_image().has_mipmaps(),"new artwork mipmaps enabled")
	var shop: MapShop = map.shops[FORGE_EVENT]
	var invalid := shop.definition.duplicate(true)
	invalid.crafting_tab = "yes"
	check(not MapShop.new().configure(invalid,map.loadout).is_empty(),"invalid craft flag rejected")
	if DisplayServer.get_name()=="headless":
		await exercise(map)
	else:
		var before: Dictionary = map.loadout.snapshot()
		dialog.set_category("throwable")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/blacksmith-buy.png")
		dialog.set_selling(true)
		dialog.set_category("material")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/blacksmith-sell.png")
		dialog.set_crafting()
		verify_crafting(dialog)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/blacksmith-craft-empty.png")
		check(map.loadout.snapshot()==before,"static preview does not transact")
	map.queue_free()
	await settle()
	# The last native click may still be queued in the audio mixer at headless speed.
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("BLACKSMITH SHOP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
