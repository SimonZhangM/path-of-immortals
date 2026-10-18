extends "res://tests/npc_topic_gate_tests.gd"

const ELDER_FACT := "base.story.yesongnian.apprentice_discount_seen"
const CLINIC_FACT := "base.story.suqinghe.treatment_used"
const ELDER_CHAT := "base.dialogue.yesongnian.chat.apprentice_price"
const CLINIC_CHAT := "base.dialogue.suqinghe.chat.treatment_fee"
const BAD_PATH := "res://artifacts/no-fee-chat-directory/save.json"
var save_path := "res://artifacts/fee-chat-%d.json" % Time.get_ticks_usec()

func move_pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await settle()

func finish_model(n: Dictionary, lib: NpcDialogueLibrary) -> void:
	var guard := 0
	while DialogueJournal.view(n,lib,{}).can_continue and guard<50:
		DialogueJournal.advance(n,lib,0)
		guard += 1
	check(guard<50,"dialogue terminates")

func model_checks(map: Node, lib: NpcDialogueLibrary, fact: String, sid: String) -> void:
	var n := DialogueJournal.initial()
	DialogueJournal.visit(n,lib,0)
	finish_model(n,lib)
	check(DialogueJournal.next_segment(n,lib,"chat",{})!=sid,"old saves without fact keep new segment locked")
	# Interrupt ordinary content before the new fact arrives.
	DialogueJournal.select(n,lib,"chat",0,{})
	var ordinary: String = n.npcs[lib.definition.id].cursor.chat
	n.flags[fact] = true
	check(DialogueJournal.next_segment(n,lib,"chat",{})==sid,"only matching fact unlocks conditional chat")
	DialogueJournal.select(n,lib,"chat",0,{})
	DialogueJournal.advance(n,lib,0)
	var state: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	state.narrative = n.duplicate(true)
	check(MapLoadoutStore.save(state,save_path).is_empty(),"interrupted conditional chat saves")
	check(MapLoadoutStore.load_into(state,save_path).is_empty() and state.narrative==n,"interrupted chat reloads exact cursor and line")
	finish_model(n,lib)
	check(n.npcs[lib.definition.id].done.has(sid) and n.npcs[lib.definition.id].seen[ordinary]==1,"completion preserves interrupted ordinary content")
	check(DialogueJournal.view(n,lib,{}).rows.size()==lib.segments[sid].lines.size()+1,"new full segment remains in topic history")
	check(DialogueJournal.next_segment(n,lib,"chat",{})==ordinary,"normal initial content resumes after conditional chat")
	for index in lib.topics.chat.initial.size():
		DialogueJournal.select(n,lib,"chat",0,{})
		finish_model(n,lib)
	var visit: Dictionary = n.npcs[lib.definition.id].visits.chat.duplicate(true)
	DialogueJournal.visit(n,lib,0)
	check(n.story_revision==0 and n.npcs[lib.definition.id].visits.chat==visit,"small fact and its reading grant no extra daily chat")
	var before := n.duplicate(true)
	DialogueJournal.select(n,lib,"chat",0,{})
	check(n==before,"completed conditional chat is history, not replay")
	var priority := DialogueJournal.initial()
	DialogueJournal.visit(priority,lib,0)
	finish_model(priority,lib)
	priority.flags[fact] = true
	priority.flags["base.story.qinglan.departure_ready"] = true
	check(DialogueJournal.next_segment(priority,lib,"chat",{})==lib.topics.chat.story[0],"main story retains priority over fee chat")

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
	check(map.startup_error.is_empty(),"town starts")
	if not map.startup_error.is_empty(): quit(1); return
	var elder := await open_person(map,HERB_POINT)
	await finish_greeting(elder)
	check_closed(elder)
	elder.request_continue()
	var shop: MapShopDialog = map.shop_dialog
	await click(elder.canvas.get_node("ShopBuyTab"))
	check(not map.loadout.narrative.flags.has(ELDER_FACT),"viewing shop purchase page does not unlock")
	var badge_point := shop.apprentice_badge.get_global_rect().get_center()
	await move_pointer(badge_point)
	check(root.gui_get_hovered_control()==shop.apprentice_badge,"actual pointer targets benefit badge")
	await move_pointer(Vector2(10,10))
	await create_timer(0.7).timeout
	check(not map.loadout.narrative.flags.has(ELDER_FACT),"brief hover leaving before tooltip does not unlock")
	map.inventory_save_path = BAD_PATH
	var before: Dictionary = map.loadout.snapshot()
	await move_pointer(badge_point)
	await create_timer(0.8).timeout
	check(map.loadout.snapshot()==before and not shop.message.text.is_empty(),"displayed tooltip with save failure preserves state and reports error")
	await move_pointer(Vector2(10,10))
	map.inventory_save_path = save_path
	await move_pointer(badge_point)
	await create_timer(0.8).timeout
	check(map.loadout.narrative.flags.get(ELDER_FACT,false),"actual displayed tooltip unlocks apprentice chat on retry")
	check(shop.message.text.is_empty(),"successful retry clears its previous save error")
	check(not map.loadout.narrative.flags.has(CLINIC_FACT) and map.loadout.narrative.story_revision==0,"tooltip fact is NPC-specific and not main story")
	if DisplayServer.get_name()!="headless": await capture_gate("fee-chat-apprentice-tooltip")
	var revision: int = map.loadout.revision
	await move_pointer(Vector2(10,10))
	await move_pointer(badge_point)
	await create_timer(0.8).timeout
	check(map.loadout.revision==revision,"repeat tooltip does not save or advance anything")
	await move_pointer(Vector2(10,10))
	await click(shop.conversation_tab)
	check(elder.topic_buttons.size()==3 and elder.topic_buttons[2].is_visible_in_tree(),"returning to conversation preserves three open topics")
	await click(elder.topic_buttons[2])
	check(map.loadout.narrative.npcs[elder.library.definition.id].cursor.chat==ELDER_CHAT,"actual chat button selects new elder segment")
	model_checks(map,elder.library,ELDER_FACT,ELDER_CHAT)
	for line in 4: elder.request_continue()
	if DisplayServer.get_name()!="headless": await capture_gate("fee-chat-apprentice")
	var elder_journal: Dictionary = map.loadout.narrative.npcs[elder.library.definition.id].duplicate(true)
	elder.cancelled.emit()
	await settle()
	var clinic := await open_person(map,CLINIC_POINT)
	await finish_greeting(clinic)
	clinic.request_continue()
	await click(clinic.treatment_tab)
	var config: Dictionary = map.event_registry.events[CLINIC_EVENT].treatment
	await move_pointer(clinic.treatment_content.care_badge.get_global_rect().get_center())
	await create_timer(0.8).timeout
	check(not map.loadout.narrative.flags.has(CLINIC_FACT),"clinic page and care tooltip do not unlock fee chat")
	await move_pointer(Vector2(10,10))
	map.loadout.spirit_stones = 10
	map.player_status.set_resource("hp",map.player_status.maxima.hp)
	before = map.loadout.snapshot()
	check(not MapClinicTreatment.treat(map.loadout,map.player_status,config,save_path,clinic.library).error.is_empty() and map.loadout.snapshot()==before,"full hp neither charges nor unlocks")
	map.player_status.set_resource("hp",10)
	map.loadout.spirit_stones = 4
	before = map.loadout.snapshot()
	check(not MapClinicTreatment.treat(map.loadout,map.player_status,config,save_path,clinic.library).error.is_empty() and map.loadout.snapshot()==before,"insufficient currency does not unlock")
	map.loadout.spirit_stones = 10
	before = map.loadout.snapshot()
	check(not MapClinicTreatment.treat(map.loadout,map.player_status,config,BAD_PATH,clinic.library).error.is_empty() and map.loadout.snapshot()==before and map.player_status.resources.hp==10,"failed treatment save neither unlocks, charges nor heals")
	clinic.treatment_content.refresh()
	await click(clinic.treatment_content.confirm_button)
	check(map.loadout.narrative.flags.get(CLINIC_FACT,false) and map.loadout.spirit_stones==5 and map.player_status.resources.hp==map.player_status.maxima.hp,"successful confirm atomically unlocks, pays five, heals")
	var restored: MapLoadoutState = MapLoadoutStore.candidate(map.loadout).state
	check(MapLoadoutStore.load_into(restored,save_path).is_empty() and restored.narrative.flags==map.loadout.narrative.flags,"both independent facts persist")
	check(map.loadout.narrative.npcs[elder.library.definition.id]==elder_journal,"clinic operations do not alter elder journal")
	await click(clinic.conversation_tab)
	await finish_greeting(clinic)
	check_closed(clinic)
	clinic.request_continue()
	await click(clinic.topic_buttons[2])
	check(map.loadout.narrative.npcs[NPC].cursor.chat==CLINIC_CHAT,"actual clinic chat button selects fee segment")
	model_checks(map,clinic.library,CLINIC_FACT,CLINIC_CHAT)
	for line in 4: clinic.request_continue()
	if DisplayServer.get_name()!="headless": await capture_gate("fee-chat-clinic")
	before = map.loadout.snapshot()
	var resources: Dictionary = map.player_status.resources.duplicate(true)
	while clinic._view.can_continue: clinic.request_continue()
	check(map.loadout.spirit_stones==before.spirit_stones and map.player_status.resources==resources,"reading final wound line does not perform another treatment")
	var bad_config := config.duplicate(true)
	bad_config.dialogue_unlock_flag = 42
	check(not MapClinicTreatment.configuration_error(bad_config).is_empty(),"invalid treatment fact rejected before use")
	var bad_shop: Dictionary = shop.shop.definition.duplicate(true)
	bad_shop.purchase_discount.dialogue_unlock_flag = "bad"
	check(not MapShop.new().configure(bad_shop,map.loadout).is_empty(),"invalid shop fact rejected before use")
	check(not NpcDialogueActions.record_dialogue_fact(map.loadout,"",save_path).is_empty(),"invalid direct fact rejected")
	map.queue_free()
	await settle()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	root.get_node("UiButtonAudio").player.stop()
	print("NPC FEE CHAT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
