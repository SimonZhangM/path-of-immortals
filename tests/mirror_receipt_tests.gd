extends "res://tests/river_quest_tests.gd"

const MIRROR := "base.map_item.broken_mirror"

func run() -> void:
	create_timer(50).timeout.connect(func(): quit(2))
	directory = "res://artifacts/mirror-receipt-20261106/run-%d/"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Slots.auto_path = directory+"auto.json"
	Session.index_path = directory+"session.json"
	Session.clear_selection()
	path = Slots.working_path()
	root.get_node("SavePlaytime").set_process(false)
	root.get_node("GameSettings").apply_values({"background_pause":false,"dialogue_speed":"instant","dialogue_auto":false})
	root.get_node("GameSettings").set_application_focus(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	render = DisplayServer.get_name()!="headless"
	await switch_to("qingshihewan",15)
	var fixture := state.snapshot()
	for id: String in fixture.quests[QuestState.ID].counts: fixture.quests[QuestState.ID].counts[id] = 1
	fixture.quests[QuestState.ID].story = QuestStory.migrated({"counts":fixture.quests[QuestState.ID].counts})
	fixture.quests[RiverQuest.ID].done = ["traces","injured","entrance","root","courtyard_check"]
	fixture.quests[RiverQuest.ID].accepted_location = RiverQuest.RIVER
	check(state.restore(fixture).is_empty(),"mirror prerequisites")
	check(MapLoadoutStore.save(state,path).is_empty(),"save fixture")
	await switch_to("wumingjiuci",5)
	check(RiverQuest.story(state).active=="mirror","altar begins mirror scene")
	for i in 2: map._advance_dialogue()
	check(RiverQuest.story(state).line==2 and not RiverQuest.story(state).reward_pending,"pickup action before receipt")
	check(RiverQuest.item_count(state,MIRROR)==0,"not granted early")
	map._advance_dialogue()
	check(RiverQuest.story(state).line==2 and RiverQuest.story(state).reward_pending,"receipt after pickup action")
	check(map.reward_dialog.visible and map.dialogue.visible and not map.reward_dialog.shade.visible,"receipt over dialogue without black shade")
	check(map.reward_dialog.card.entry.name=="残破古镜" and map.reward_dialog.card.entry.icon=="res://assets/item-faqi-rw-canpogujing.webp","requested name and art")
	check(map.reward_dialog.card.entry.quest_item,"task item")
	check(ItemTooltip.effect_text(state.registry.get_item(MIRROR)).contains("来历与用途尚不明"),"mysterious tooltip description")
	await switch_to("wumingjiuci",5)
	check(RiverQuest.story(state).reward_pending and map.reward_dialog.visible,"pending receipt reload")
	var pending := state.snapshot()
	check(not RiverQuest.command(state,directory+"missing/fail.json","accept").is_empty(),"save failure reported")
	check(state.snapshot()==pending,"save failure preserves cursor and inventory")
	await settle()
	var motion := InputEventMouseMotion.new()
	motion.position = map.reward_dialog.card.square.get_global_rect().get_center()
	root.push_input(motion,true)
	await create_timer(0.65).timeout
	var host := ItemTooltipHost.for_control(map.reward_dialog.card)
	check(host.tooltip!=null and host.tooltip.visible,"receipt actual mouse hover shows tooltip")
	await shot("mirror-receipt-tooltip")
	host.dismiss(false)
	await click(map.reward_dialog.accept_button)
	check(RiverQuest.item_count(state,MIRROR)==1,"receipt grants one mirror")
	check(RiverQuest.story(state).line==3 and not RiverQuest.story(state).reward_pending,"receipt continues dialogue")
	RiverQuest.command(state,path,"accept")
	check(RiverQuest.item_count(state,MIRROR)==1,"duplicate accept does not duplicate mirror")
	for line in [4,6,8,9]:
		map._advance_dialogue()
		check(RiverQuest.story(state).line==line,"gallery sequence unchanged: "+str(line))
	finish_scene("mirror")
	check(state.narrative.flags.get("base.story.hewanfengxian.broken_mirror",false),"narrative mirror flag retained")
	await switch_to("wumingjiuci",5)
	check(RiverQuest.item_count(state,MIRROR)==1 and RiverQuest.done(state,"mirror"),"completed reload retains item without replay")
	var result := {"checks":checks,"failures":failures,"render":render,"directory":directory}
	var file := FileAccess.open(directory+"result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print(JSON.stringify(result))
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
