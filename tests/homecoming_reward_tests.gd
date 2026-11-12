extends "res://tests/breakthrough_audio_tests.gd"
const MIRROR := "base.map_item.broken_mirror"

func run() -> void:
	if not await prepare_audio_fixture("res://artifacts/homecoming-rewards-20261106"): quit(1); return
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1920,1080)
	root.get_node("GameSettings").apply_values({"dialogue_speed":"instant","dialogue_auto":false})
	state.narrative.flags[HomecomingQuest.PREPARATION_FLAG]=true
	map.travel.current_node_id=HomecomingQuest.data.home.point_id
	map.travel.map_position=map.travel.node_positions[map.travel.current_node_id]
	map.travel.stop_at_current_node()
	check(state.add_reward(RiverQuest.data.scenes.mirror.reward).is_empty(),"one existing mirror fixture")
	check(state.records[MIRROR].name=="残破古镜" and state.registry.get_item(MIRROR).display_name=="残破古镜","unidentified name before task completion")
	check(state.records[GUIDE].quest_item,"mortal guide still protected")
	var original := state.snapshot()
	var candidate := MapLoadoutStore.candidate(state)
	candidate.state.narrative.flags[HomecomingQuest.COMPLETED_FLAG]=true
	candidate.state._refresh_quest_item_status()
	check(candidate.state.records[MIRROR].name=="照尘镜" and state.records[MIRROR].name=="残破古镜","candidate identity cannot leak to live item")
	check(candidate.state.registry.get_item(MIRROR).display_name=="照尘镜" and state.registry.get_item(MIRROR).display_name=="残破古镜","candidate tooltip cannot leak to live registry")
	var flow: RefCounted=map.breakthrough_session
	check(flow.start(),"start actual breakthrough")
	state.growth.breakthrough_attempt.progress=19900
	flow.advance(9)
	check(state.growth.realm==1 and not state.records[GUIDE].quest_item,"actual qi unlocks ordinary guide")
	check("任务物品" not in state.registry.get_item(GUIDE).tags,"guide tooltip loses task label")
	map.set_breakthrough_open(false)
	check(HomecomingQuest.story(state).active=="rejoice","continue final conversation")
	var quest := HomecomingQuest.story(state)
	quest.line=HomecomingQuest.data.scenes.rejoice.lines.size()-1
	map.homecoming_story_controller.present()
	var owned: Dictionary = state.snapshot().owned_units.duplicate(true)
	var growth := state.growth.duplicate(true)
	var before := state.snapshot()
	check(not HomecomingQuest.command(state,directory+"missing/rewards.json","advance").is_empty(),"failed completion save rejected")
	check(state.snapshot()==before and state.records[MIRROR].name=="残破古镜","failed save preserves old mirror identity")
	map._advance_dialogue()
	await create_timer(0.25).timeout
	check(HomecomingQuest.completed(state) and state.records[MIRROR].name=="照尘镜","task completion identifies existing mirror")
	check(state.records[MIRROR].quest_item and state.records[MIRROR].category=="key","mirror retains task-item status")
	check(state.registry.get_item(MIRROR).display_name=="照尘镜" and ItemTooltip.effect_text(state.registry.get_item(MIRROR)).contains("先人可能曾经用过"),"shared tooltip uses qualified family history")
	check(ItemTooltip.effect_text(state.registry.get_item(MIRROR)).contains("不知它的用法") and state.records[MIRROR].effects.is_empty(),"mirror has no invented use or powers")
	check(state.snapshot().owned_units==owned and state.growth==growth,"completion does not duplicate either item or growth")
	var entry := HomecomingQuest.display_entry(state,{})
	check(entry.rewards.size()==2 and entry.rewards[0].name=="导引石" and entry.rewards[1].name=="照尘镜","two task rewards use current item names")
	check(entry.rewards[0].badge_text=="解锁" and entry.rewards[1].badge_text=="识名","badges describe changes instead of extra copies")
	var completed := state.snapshot()
	var reloaded := MapLoadoutStore.candidate(state)
	check(reloaded.error.is_empty() and MapLoadoutStore.load_into(reloaded.state,path).is_empty(),"completion reloads from disk")
	check(reloaded.state.records[MIRROR].name=="照尘镜" and not reloaded.state.records[GUIDE].quest_item,"reload retains both item states")
	check(state.restore(original).is_empty(),"restore earlier save")
	check(state.records[MIRROR].name=="残破古镜" and state.records[GUIDE].quest_item,"earlier save restores unrecognized mirror and protected guide")
	check(state.restore(completed).is_empty(),"restore completion")
	map.set_task_open(true)
	map.task_screen.task_list.select_task(HomecomingQuest.ID)
	await settle()
	var slots: HBoxContainer=map.task_screen.detail_body.reward_slots
	check(slots.get_child_count()==2,"task reward section renders both items")
	var square: Control=slots.get_child(1).get_child(0)
	var motion := InputEventMouseMotion.new()
	motion.position=square.get_global_rect().get_center()
	root.push_input(motion,true)
	await create_timer(0.65).timeout
	var host := ItemTooltipHost.for_control(square)
	check(host.tooltip!=null and host.tooltip.visible,"mirror task-reward hover opens actual tooltip")
	if DisplayServer.get_name()!="headless": await capture("completed-rewards-mirror-tooltip")
	host.dismiss(false)
	map.set_task_open(false)
	check(HomecomingQuest.command(state,path,"advance").is_empty() and state.snapshot().owned_units==owned,"repeat completion does not duplicate items")
	# Invalid story identity records fail before entering gameplay.
	var invalid: Dictionary=state.records[MIRROR].duplicate(true)
	invalid.story_identity.after.description=""
	check(not MapInventoryCatalog.new().replace_entries([invalid]).is_empty(),"missing identity text rejected")
	print("HOMECOMING REWARDS: %d checks, %d failures; %s"%[checks,failures,directory])
	map.deactivate_location()
	map.free()
	quit(1 if failures else 0)
