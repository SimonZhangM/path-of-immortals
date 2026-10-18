extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: "+label)

func settle() -> void:
	for i in 6: await process_frame

func count(state: MapLoadoutState, id: String) -> int:
	var amount := 0
	for entry: Dictionary in state.storage.entries():
		if entry.item_id==id: amount += entry.units.size()
	return amount

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1920,1080)
	var manager := GameManager.new()
	manager.use_saved_loadout=false
	manager.cultivation_preview=true
	manager.preview_spell_id="base.spell.wind_01"
	manager.preview_branch="疾羽"
	root.add_child(manager)
	manager.set_process(false)
	check(manager.startup_error.is_empty(),"real GameManager starts revised wind spell")
	if not manager.startup_error.is_empty(): quit(1); return
	var registry := manager.registry
	# Command path: a locked branch consumes no selection and cannot block stage5.
	var book := "base.cultivation_book.wood_02"
	for stage in range(1,5): check(manager.record_cultivation_achievement(book,stage),"command reaches stage"+str(stage))
	var before := manager.party[0].knowledge.snapshot()
	check(not manager.choose_cultivation_branch(book,4,"启式") and manager.party[0].knowledge.snapshot()==before,"command rejects unavailable branch without side effect")
	check(manager.party[0].knowledge.record_achievement(registry.library,book,5,5),"future qualified rank can continue with stage4 pending")
	var spirit := manager.party[0].spirit
	manager.start_battle()
	manager._process(9)
	check(manager.simulation.configuration_error.is_empty(),"revised spell settles in real entry")
	check(manager.simulation.state.item_runtime["preview.spell"].activation_count==3,"three casts in nine seconds")
	check(is_equal_approx(spirit-manager.party[0].spirit,12.0),"three actual casts pay twelve spirit")
	var shop_registry := ContentRegistry.new()
	check(shop_registry.load_base_content(),"isolated shop registry")
	var made := MapLoadoutStore.create_state(shop_registry,shop_registry.get_board(manager.party[0].definition.board_layout))
	check(made.error.is_empty(),"isolated inventory fixture: "+made.error)
	if not made.error.is_empty(): quit(1); return
	var state: MapLoadoutState = made.state
	state.spirit_stones=10000
	var shop := MapShop.new()
	check(shop.load_catalog("res://data/shops/qingshizhen_shop.json",state).is_empty(),"expanded shop passes catalog validation")
	check(shop.products("weapon").size()==9 and shop.products("armor").size()==10,"all state sources reachable across two pages")
	for id: String in ["base.map_item.t01_0062","base.map_item.t01_0056","base.map_item.t01_0052","base.map_item.t01_0039"]:
		check(shop.products().any(func(row): return row.item_id==id),"source listed "+id)
		var quote := shop.buy_unit_price(id)
		var money := state.spirit_stones
		var units := count(state,id)
		check(quote>0 and shop.purchase(state,id,1,"").is_empty(),"source actually purchasable "+id)
		check(state.spirit_stones==money-quote and count(state,id)==units+1,"purchase debits approved price and grants exactly one source")
	var meanings := ItemTooltip.status_keyword_meanings()
	check(meanings["缠绕"].contains("不造成定身") and meanings["破甲"].contains("不是通用扣甲"),"shared status meanings disambiguate effects")
	# Rendering only lays out real tooltips; no mouse or interaction replay.
	if DisplayServer.get_name()!="headless":
		await preview(registry)
	manager.queue_free()
	await settle()
	print("CULTIVATION REVISION ENTRY CHECKS %d; FAILURES %d" % [checks,failures])
	quit(1 if failures else 0)

func preview(registry: ContentRegistry) -> void:
	var background := ColorRect.new()
	background.color=Color("111827")
	background.size=Vector2(1920,1080)
	root.add_child(background)
	var left := ItemTooltip.new()
	left.configure(registry.get_item("base.cultivation_book.wind_02"))
	root.add_child(left)
	left.position=Vector2(50,40)
	var right := ItemTooltip.new()
	right.configure(registry.get_item("base.cultivation_book.wood_04"))
	root.add_child(right)
	right.position=Vector2(1030,40)
	await settle()
	check(left.size.y<1000 and right.size.y<1000,"book labels and pending choices fit viewport")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/cultivation-revision-books.png")
	left.queue_free();right.queue_free()
	await settle()
	var meanings := ItemTooltip.status_keyword_meanings()
	var status := ItemTooltip.new()
	status.configure_description("缠绕："+meanings["缠绕"]+"\n破甲："+meanings["破甲"])
	root.add_child(status)
	status.position=Vector2(50,40)
	var passive := ItemTooltip.new()
	passive.configure(registry.get_item("base.cultivation_book.water_03"))
	root.add_child(passive)
	passive.position=Vector2(1030,40)
	await settle()
	check(status.size.y<1000 and passive.size.y<1000,"status definitions and persistent book fit viewport")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/cultivation-revision-status.png")
	status.queue_free();passive.queue_free();background.queue_free()
