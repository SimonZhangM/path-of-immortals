extends "res://tests/map_shop_tests.gd"

const NPC := "base.npc.yesongnian"
const PREFIX := "base.dialogue.yesongnian."
const HERBALIST := "base.map_event.qingshizhen.herbalist"
const HERB_POINT := "base.map.qingshizhen.point.n14"
const RESCUE := "base.story.qingshihewan.rescue_completed"
const KNOWN := "base.story.yesongnian.knows_rescue"
const WATER := "base.story.qingshihewan.water_observed"
const FAILURE_PATH := "res://artifacts/no-yesongnian-directory/save.json"

func finish(n: Dictionary, lib: NpcDialogueLibrary, day := 0) -> void:
	var guard := 0
	while DialogueJournal.view(n,lib,{}).can_continue and guard<40:
		DialogueJournal.advance(n,lib,day)
		guard += 1
	check(guard<40,"finite dialogue")

func read_stage(n: Dictionary, lib: NpcDialogueLibrary, topic: String, day := 0) -> void:
	check(DialogueJournal.select(n,lib,topic,day,{}).is_empty(),"topic selectable: "+topic)
	finish(n,lib,day)

func new_story(lib: NpcDialogueLibrary) -> Dictionary:
	var n := DialogueJournal.initial()
	check(DialogueJournal.visit(n,lib,0).is_empty(),"first welcome starts")
	finish(n,lib)
	return n

func model_checks(map: Node, lib: NpcDialogueLibrary) -> void:
	var n := new_story(lib)
	check(lib.segments.size()==21 and lib.definition.greetings.entries.size()==9,"full supplied content loaded")
	check(DialogueJournal.view(n,lib,{}).topics.map(func(t): return t.label)==["药铺近况","请教药理","闲聊"],"initial topic labels")
	DialogueJournal.select(n,lib,"shop",0,{})
	DialogueJournal.advance(n,lib,0)
	DialogueJournal.select(n,lib,"medicine",0,{})
	DialogueJournal.select(n,lib,"shop",0,{})
	check(n.npcs[NPC].seen[PREFIX+"shop.01"]==2 and n.npcs[NPC].seen[PREFIX+"medicine.01"]==1,"independent interrupted cursors")
	for stage in 3: read_stage(n,lib,"shop")
	check(n.clues.get("base.clue.qingshihewan.herb_changes")=="河湾药材变化","shop completion grants only authored clue")
	check(DialogueJournal.next_segment(n,lib,"shop",{}).is_empty(),"no observations or medical knowledge assumed")
	var history := n.duplicate(true)
	read_stage(n,lib,"shop")
	check(n==history,"completed topic is history only")
	n.flags[WATER] = true
	check(DialogueJournal.next_segment(n,lib,"shop",{})==PREFIX+"shop.water","water evidence unlocks followup")
	read_stage(n,lib,"shop")
	var su := NpcDialogueLibrary.new()
	check(su.load_file("res://data/dialogues/suqinghe.json").is_empty(),"clinic library valid")
	var elder: Dictionary = n.npcs[NPC].duplicate(true)
	DialogueJournal.visit(n,su,0)
	finish(n,su)
	read_stage(n,su,"medical")
	check(DialogueJournal.next_segment(n,lib,"shop",{}).is_empty(),"recovery alone without drug-batch explanation cannot unlock merge")
	read_stage(n,su,"medical")
	check(n.npcs[NPC]==elder,"clinic reading preserves elder journal")
	check(DialogueJournal.next_segment(n,lib,"shop",{})==PREFIX+"shop.merge","hearing recovery and batch investigation unlocks relay before all clinic topics end")
	DialogueJournal.select(n,lib,"shop",0,{})
	var view := DialogueJournal.view(n,lib,{})
	check(view.rows[-1].speaker=="player" and "清禾姐也在查" in view.rows[-1].text,"player supplies information before elder responds")
	finish(n,lib)
	for stage in 3: read_stage(n,lib,"medicine")
	check(not n.flags.get(KNOWN,false),"hypothetical rescue never makes elder know")
	check(lib.segment_for(n.npcs[NPC],PREFIX+"medicine.02").lines.any(func(l): return "那若是在山里" in l.text),"before-rescue branch preserved")
	n.flags[RESCUE] = true
	DialogueGreetings.arrive(n,lib,{})
	check(n.npcs[NPC].greeting.active.begins_with(PREFIX+"greeting.daily."),"rescue completion alone cannot trigger informed greeting")
	read_stage(n,lib,"medicine")
	check(n.flags.get(KNOWN,false),"completed report records elder knowledge")
	DialogueGreetings.arrive(n,lib,{})
	check(n.npcs[NPC].greeting.active==PREFIX+"greeting.rescue","known rescue greeting now eligible")
	DialogueGreetings.arrive(n,lib,{})
	check(n.npcs[NPC].greeting.active!=PREFIX+"greeting.rescue","special greeting occurs once")
	check(lib.segment_for(n.npcs[NPC],PREFIX+"medicine.02").lines.any(func(l): return "那若是在山里" in l.text),"later rescue does not rewrite old history")
	var after := new_story(lib)
	after.flags[RESCUE] = true
	read_stage(after,lib,"medicine")
	DialogueJournal.select(after,lib,"medicine",0,{})
	check(after.npcs[NPC].variants[PREFIX+"medicine.02"]=="after_rescue","already rescued chooses retrospective branch")
	after.flags.erase(RESCUE)
	finish(after,lib)
	check(after.flags.get(KNOWN,false),"started branch stays fixed while flags change")
	check(not lib.segment_for(after.npcs[NPC],PREFIX+"medicine.02").lines.any(func(l): return "那若是在山里" in l.text),"retrospective has no hypothetical rescue")
	var during := new_story(lib)
	read_stage(during,lib,"medicine")
	DialogueJournal.select(during,lib,"medicine",0,{})
	during.flags[RESCUE] = true
	finish(during,lib)
	check(not during.flags.get(KNOWN,false) and not during.npcs[NPC].get("variants",{}).has(PREFIX+"medicine.02"),"unfinished hypothetical freezes even if rescue completes")
	read_stage(during,lib,"medicine")
	check(during.flags.get(KNOWN,false),"separate followup reports rescue after old branch")
	for stage in 2: read_stage(n,lib,"chat")
	DialogueJournal.visit(n,lib,0)
	check(DialogueJournal.next_segment(n,lib,"chat",{}).is_empty(),"same-day revisit cannot consume pool")
	DialogueJournal.visit(n,lib,90)
	DialogueJournal.visit(n,lib,600)
	check(n.npcs[NPC].visits.chat.unlocked==2,"unread revisit pair retained without accumulating")
	read_stage(n,lib,"chat",600)
	DialogueJournal.visit(n,lib,600)
	check(DialogueJournal.next_segment(n,lib,"chat",{})==PREFIX+"revisit.02","same batch second chat is available")
	read_stage(n,lib,"chat",600)
	for day in [690,780]:
		DialogueJournal.visit(n,lib,day)
		read_stage(n,lib,"chat",day)
		read_stage(n,lib,"chat",day)
	check(n.npcs[NPC].visits.chat.unlocked==6 and DialogueJournal.next_segment(n,lib,"chat",{}).is_empty(),"all six revisits archived")
	n.flags["base.story.qinglan.departure_ready"] = true
	DialogueGreetings.arrive(n,lib,{})
	check(n.npcs[NPC].greeting.active==PREFIX+"greeting.departure","departure greeting uses real story fact")
	read_stage(n,lib,"chat",12)
	n.flags["base.story.qinglan.joined"] = true
	check(DialogueJournal.next_segment(n,lib,"chat",{}).is_empty(),"joining alone does not imply returning")
	n.flags["base.story.qinglan.first_town_return"] = true
	DialogueGreetings.arrive(n,lib,{})
	check(n.npcs[NPC].greeting.active==PREFIX+"greeting.return","first return welcome")
	read_stage(n,lib,"chat",13)
	check(DialogueJournal.valid_record(n) and lib.journal_error(n.npcs[NPC]).is_empty(),"full played journal remains valid")
	var daily := new_story(lib)
	for i in 7:
		DialogueGreetings.arrive(daily,lib,{"resources":{"hp":50},"maxima":{"hp":100}})
		check(daily.npcs[NPC].greeting.active==PREFIX+"greeting.daily.%02d"%[i%5+1],"five normal greetings cycle at healthy threshold")
	var index: int = daily.npcs[NPC].greeting.ordinary_index
	DialogueGreetings.arrive(daily,lib,{"resources":{"hp":49},"maxima":{"hp":100}})
	check(daily.npcs[NPC].greeting.active==PREFIX+"greeting.injured" and daily.npcs[NPC].greeting.ordinary_index==index,"injury welcome below half does not consume daily pool")
	var snapshot: Dictionary = map.loadout.snapshot()
	var state: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	state.narrative = n
	var path := "res://artifacts/yesongnian-model.json"
	check(MapLoadoutStore.save(state,path).is_empty(),"isolated journal saves")
	check(MapLoadoutStore.load_into(state,path).is_empty() and state.narrative==n,"both NPC histories and knowledge reload")
	var before: Dictionary = state.snapshot()
	check(not NpcDialogueActions.command(state,lib,"visit",FAILURE_PATH).is_empty() and state.snapshot()==before,"failed save rolls back welcome rotation")
	state.narrative = during
	before = state.snapshot()
	check(not NpcDialogueActions.command(state,lib,"select",FAILURE_PATH,"medicine").is_empty() and state.snapshot()==before,"failed save does not reveal next segment")
	state.narrative = after
	check(MapLoadoutStore.save(state,path).is_empty() and MapLoadoutStore.load_into(state,path).is_empty() and state.narrative==after,"frozen variant reloads with correct length")
	state.narrative = after.duplicate(true)
	state.narrative.npcs[NPC].seen[PREFIX+"medicine.02"] -= 1
	state.narrative.npcs[NPC].done.erase(PREFIX+"medicine.02")
	state.narrative.flags.erase(KNOWN)
	before = state.snapshot()
	check(not NpcDialogueActions.command(state,lib,"advance",FAILURE_PATH).is_empty() and state.snapshot()==before,"failed final report save leaves knowledge and final line unpublished")
	check(NpcDialogueActions.command(state,lib,"advance",path).is_empty() and state.narrative.flags.get(KNOWN,false),"retry final report publishes knowledge only after save")
	var invalid := after.duplicate(true)
	invalid.npcs[NPC].variants[PREFIX+"medicine.02"] = "missing"
	check(not lib.journal_error(invalid.npcs[NPC]).is_empty(),"unknown saved variant rejected")
	var bad := lib.definition.duplicate(true)
	bad.segments[PREFIX+"medicine.02"].variants[0].requires_flags = ["not-a-fact"]
	check(not NpcDialogueLibrary.new().configure(bad).is_empty(),"malformed branch condition rejected")
	check(map.loadout.snapshot()==snapshot,"model tests never alter map fixture")

func open_herbalist(map: Node) -> void:
	map.travel.current_node_id = HERB_POINT
	map.travel.map_position = map.travel.node_positions[HERB_POINT]
	map.travel.stop_at_current_node()
	map.content.position = map.map_viewport.size*0.5-map.travel.map_position*map.content.scale
	map._select_destination(map.map_to_screen(map.travel.map_position))
	await settle()
	check(map.event_state.active_id==HERBALIST and map.shop_dialog.conversing,"town click opens talk first")

func finish_ui(map: Node) -> void:
	var guard := 0
	while map.shop_dialog.conversation_view._view.can_continue and guard<40:
		map._shop_dialogue_command("advance","")
		guard += 1
	await settle()
	check(guard<40,"UI dialogue terminates")

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+label+".png")

func bridge_checks() -> void:
	MapEventState.session_completed.clear()
	var map = load("res://scenes/maps/qingshihewan.tscn").instantiate()
	map.inventory_save_path = ""
	map.defer_map_music = true
	root.add_child(map)
	map.set_process(false)
	await settle()
	check(map.startup_error.is_empty(),"river startup")
	var point := "base.map.qingshihewan.point.n37"
	check(map.event_state.try_start(point,point,true,"arrival"),"bridge story begins")
	map._present_event_progress()
	var event: Dictionary = map.event_state.active_event()
	for i in event.lines.size()-1: map._advance_dialogue()
	check(not map.loadout.narrative.flags.get(WATER,false),"arrival and partial reading never grant observation")
	map.inventory_save_path = FAILURE_PATH
	map._advance_dialogue()
	check(map.event_state.is_active() and not map.loadout.narrative.flags.get(WATER,false),"failed completion save retains final line and no fact")
	map.inventory_save_path = "res://artifacts/yesongnian-bridge.json"
	map._advance_dialogue()
	check(not map.event_state.is_active() and map.loadout.narrative.flags.get(WATER,false),"successful completion publishes observation")
	check(not map.loadout.narrative.flags.get(RESCUE,false),"bridge never marks rescue complete")
	check(not map.event_registry.events.values().any(func(e): return RESCUE in e.get("story_flags_on_complete",[])),"current wounded-disciple scene has no rescue completion binding")
	var restored: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	check(MapLoadoutStore.load_into(restored,map.inventory_save_path).is_empty() and restored.narrative.flags.get(WATER,false),"observation survives reload")
	map.queue_free()
	await settle()

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
	check(map.startup_error.is_empty(),"town starts: "+map.startup_error)
	if not map.startup_error.is_empty(): quit(1); return
	await open_herbalist(map)
	var shop: MapShopDialog = map.shop_dialog
	var talk: MapClinicDialog = shop.conversation_view
	var lib: NpcDialogueLibrary = talk.library
	check(lib!=null,"shared clinic dialogue library loaded")
	if lib==null: quit(1); return
	check(talk.backing.texture.atlas.resource_path.ends_with("yaocaipu-2.webp"),"requested conversation background")
	check(not shop.canvas.visible and talk.visible and not talk.treatment_tab.visible,"one visible modal canvas")
	check(talk.title_label.text=="药材铺" and talk.description_label.text==shop.description_label.text,"trade title and introduction retained")
	check(talk.conversation_tab.position.x<talk.canvas.get_node("ShopBuyTab").position.x and talk.canvas.get_node("ShopBuyTab").position.x<talk.canvas.get_node("ShopSellTab").position.x,"talk buy sell order")
	check(talk.dialogue_rows.get_child(0) is DialogueBubble and talk.dialogue_rows.get_child(0).portrait.texture.resource_path.ends_with("ui-portrait-yesongnian.webp"),"clinic bubble uses elder portrait")
	check(load(lib.definition.portrait).get_image().has_mipmaps() and talk.backing.texture.atlas.get_image().has_mipmaps(),"new assets have mipmaps")
	if DisplayServer.get_name()=="headless":
		model_checks(map,lib)
		map.inventory_save_path = "res://artifacts/yesongnian-ui.json"
		await click(talk.continue_button)
		var before: Dictionary = map.loadout.narrative.duplicate(true)
		await click(talk.canvas.get_node("ShopBuyTab"))
		check(not shop.conversing and not shop.selling and shop.canvas.visible and not talk.visible,"native buy tab switches from conversation")
		await click(shop.sell_button)
		await click(shop.conversation_tab)
		check(shop.conversing and map.loadout.narrative==before,"native page switches do not repeat or advance welcome")
		await click(talk.leave_button)
		await open_herbalist(map)
		talk = shop.conversation_view
		check(map.loadout.narrative.npcs[NPC].seen[PREFIX+"welcome"]==2,"interrupted first welcome resumes on next visit")
		await finish_ui(map)
		await click(talk.continue_button)
		await click(talk.topic_buttons[0])
		await click(talk.continue_button)
		await click(talk.topic_buttons[1])
		await click(talk.topic_buttons[0])
		check(map.loadout.narrative.npcs[NPC].seen[PREFIX+"shop.01"]==2,"native topic switches resume partial line")
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = true
		root.push_input(key,true)
		await settle()
		check(map.loadout.narrative.npcs[NPC].seen[PREFIX+"shop.01"]==3,"space advances shop conversation once")
		before = map.loadout.narrative.duplicate(true)
		map.inventory_save_path = FAILURE_PATH
		await click(talk.continue_button)
		check(map.loadout.narrative==before and not talk.dialogue_note.text.is_empty(),"visible save failure leaves read cursor unchanged")
		map.inventory_save_path = "res://artifacts/yesongnian-ui.json"
		await click(talk.canvas.get_node("ShopBuyTab"))
		map.loadout.spirit_stones = 1000
		shop._refresh_page()
		var item: String = shop.selected_id
		var quantity := count(map.loadout,item)
		var price := shop.shop.buy_unit_price(item)
		await click(shop.buy_button)
		check(count(map.loadout,item)==quantity+1 and map.loadout.spirit_stones==1000-price,"purchase works after talk switch")
		await click(shop.sell_button)
		var slot := shop._visible_products.find_custom(func(p): return p.item_id==item)
		check(slot>=0,"newly purchased herb is sellable")
		if slot>=0: await click(shop.slots[slot])
		await click(shop.buy_button)
		check(count(map.loadout,item)==quantity and map.loadout.spirit_stones==1000-price+shop.shop.pricing.sell_unit_price(item),"sale works after talk switch")
		await click(shop.conversation_tab)
		check(map.loadout.narrative==before,"actual transactions preserve conversation")
		await click(talk.leave_button)
		await open_herbalist(map)
		talk = shop.conversation_view
		check(map.loadout.narrative.npcs[NPC].greeting.active==PREFIX+"greeting.daily.01","greeting starts on real reentry")
		before = map.loadout.narrative.duplicate(true)
		await click(talk.canvas.get_node("ShopSellTab"))
		await click(shop.conversation_tab)
		check(map.loadout.narrative==before,"ordinary greeting never rotates on tab switches")
		var restored: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
		check(MapLoadoutStore.load_into(restored,map.inventory_save_path).is_empty() and restored.narrative==before,"actual UI journal reloads")
		map._close_shop()
		var other: Dictionary = map.event_registry.events[EVENT]
		shop.present(other,map.shops[EVENT],map.loadout,map.player_status)
		check(shop.conversation_view!=null and shop.conversation_view.library!=null and shop.conversation_view.library.definition.id=="base.npc.qianwanshun" and shop.conversation_tab.visible and shop.buy_tab.position.x==828-MapShopDialog.FRAME.position.x,"general shop has independent merchant dialogue without herbalist dialogue")
		shop.hide()
		var invalid_event: Dictionary = map.event_registry.events[HERBALIST].duplicate(true)
		invalid_event.presentation = []
		check(not MapEventRegistry.new().configure([invalid_event],[HERB_POINT]).is_empty(),"malformed shop presentation rejected safely")
	else:
		await capture("yesongnian-welcome")
		await finish_ui(map)
		for stage in 2:
			map._shop_dialogue_command("select","medicine")
			await finish_ui(map)
		map._shop_dialogue_command("select","medicine")
		await finish_ui(map)
		# Review the longest topic label while retaining actual authored bubbles.
		var preview := new_story(lib)
		for stage in 2: read_stage(preview,lib,"medicine")
		map.loadout.narrative = preview
		talk.refresh_dialogue()
		await capture("yesongnian-topics")
		var button: Button = talk.topic_buttons[1]
		var style := button.get_theme_stylebox("normal")
		check(button.text=="药材与丹药有何不同？" and button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x<=button.size.x-style.content_margin_left-style.content_margin_right,"longest topic fits its frame")
		var narrative: Dictionary = map.loadout.narrative.duplicate(true)
		shop.set_selling(false)
		await capture("yesongnian-buy")
		shop.set_selling(true)
		await capture("yesongnian-sell")
		check(map.loadout.narrative==narrative,"static trade previews retain narrative")
	map.queue_free()
	await settle()
	if DisplayServer.get_name()=="headless": await bridge_checks()
	root.get_node("UiButtonAudio").player.stop()
	await create_timer(0.1).timeout
	print("YESONGNIAN: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
