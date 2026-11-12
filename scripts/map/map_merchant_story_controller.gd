extends "res://scripts/map/map_quest_story_controller.gd"
## The common story adapter plus a dedicated, retryable rescue encounter.

func owns_dialogue() -> bool:
	return super.owns_dialogue() and map.event_state.phase!="encounter"

func try_arrival(point_id: String, _clicked := false) -> bool:
	if map.event_state.is_active(): return owns_dialogue()
	if {"map_id":map.definition.id,"point_id":point_id}==MerchantRoadQuest.data.road and MerchantRoadQuest.accepted(map.loadout):
		if MerchantRoadQuest.battle_ready(map.loadout):
			show_battle()
			return true
		if MerchantRoadQuest.story(map.loadout).stage=="escorting": return true
	return super.try_arrival(point_id)

func show_battle() -> void:
	var event:Dictionary=MerchantRoadQuest.data.battle.duplicate(true)
	map.sign_motion.restore(event.point_id)
	map.event_state.active_id=event.id
	map.event_state._active_snapshot=event
	map.event_state.phase="encounter"
	map.travel.paused=true
	map._end_drag(); map._clear_hover()
	map._present_event_progress()

func finish() -> void:
	super.finish()
	if MerchantRoadQuest.story(map.loadout).stage=="completed" and map.definition.id==MerchantRoadQuest.data.shop.map_id:
		map._story_locked_signs[MerchantRoadQuest.data.shop.point_id]=true
		map._sync_story_locked_signs()
	if MerchantRoadQuest.battle_ready(map.loadout) and map.loadout.map_location==MerchantRoadQuest.data.road:
		show_battle()
	elif MerchantRoadQuest.story(map.loadout).stage=="escorting" and MerchantRoadQuest.story(map.loadout).town_talk_done and map.loadout.map_location==MerchantRoadQuest.data.shop:
		try_arrival(map.travel.current_node_id)
