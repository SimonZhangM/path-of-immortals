class_name MerchantRoadQuest
extends RefCounted
## Pharmacy acceptance, one rescue battle and a persistent escort back to the shop.
const ID := "quest.prologue.shanglujinghun"
const PREFIX := "base.map_event.quest.shanglujinghun."
const RESCUE_FLAG := "base.story.qingshihewan.rescue_completed"
const NAME_FLAG := "base.story.qianwanshun.knows_name"
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/merchant_road.json"))

static func initial() -> Dictionary:
	return {"accepted_at":0,"updated_at":0,"accepted_location":"","stage":"searching","active":"","line":0,"location":{},"reward_pending":false,"town_talk_done":false}

static func normalized(raw: Dictionary) -> Dictionary:
	var result:=initial()
	result.merge(raw,true)
	# The road scene moved to N12; retain dialogue progress from the old N17 site.
	if result.active in ["ambush","rescued"] and result.location=={"map_id":"base.map.qingshihewan","point_id":"base.map.qingshihewan.point.n17"}:
		result.location=data.road.duplicate(true)
	for key in ["accepted_at","updated_at","line"]: result[key]=int(result[key])
	return result

static func story(state: MapLoadoutState) -> Dictionary:
	return state.quests[ID]

static func accepted(state: MapLoadoutState) -> bool:
	return not story(state).accepted_location.is_empty()

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("accepted_location") not in ["","base.map.qingshizhen"]: return false
	for key in ["accepted_at","updated_at"]:
		if not WorldCalendar.integer_between(raw.get(key),0,WorldCalendar.MAX_DAY): return false
	if not WorldCalendar.integer_between(raw.get("line",0),0,1000): return false
	var saved:=normalized(raw)
	if saved.stage not in ["searching","battle","rescued","escorting","completed"]: return false
	if not saved.active is String or not saved.location is Dictionary or not saved.reward_pending is bool or not saved.town_talk_done is bool: return false
	if saved.accepted_location.is_empty() and (saved.accepted_at!=0 or saved.updated_at!=0 or saved.stage!="searching" or not saved.active.is_empty() or saved.town_talk_done): return false
	if saved.town_talk_done and saved.stage not in ["escorting","completed"]: return false
	if saved.stage=="completed" and not saved.town_talk_done: return false
	if saved.active.is_empty(): return saved.line==0 and saved.location.is_empty() and not saved.reward_pending
	if not data.scenes.has(saved.active) or saved.line>=data.scenes[saved.active].lines.size(): return false
	match saved.active:
		"ambush": return saved.stage=="searching" and saved.location==data.road and not saved.reward_pending
		"rescued": return saved.stage=="rescued" and saved.location==data.road and not saved.reward_pending
		"town_arrival": return saved.stage=="escorting" and not saved.town_talk_done and MapLoadoutState.valid_map_location(saved.location) and saved.location.map_id==data.shop.map_id and not saved.reward_pending
		"shop_return": return saved.stage=="escorting" and saved.town_talk_done and saved.location==data.shop and (not saved.reward_pending or saved.line==data.scenes.shop_return.lines.size()-1)
	return false

static func configuration_error() -> String:
	if data.get("quest_id")!=ID: return "商路惊魂配置无效。"
	for location: Dictionary in [data.road,data.town_entry,data.shop]:
		if not MapLoadoutState.valid_map_location(location): return "商路惊魂地点无效。"
	if data.battle.enemy_id!="base.enemy.chisong_liaozhu" or data.battle.point_id!=data.road.point_id: return "商路惊魂战斗配置无效。"
	var encounter_error:=MapEventRegistry.new().configure([data.battle],[data.road.point_id])
	if not encounter_error.is_empty(): return encounter_error
	for scene: Dictionary in data.scenes.values():
		if scene.lines.is_empty() or scene.lines.size()!=scene.line_speakers.size(): return "商路惊魂对白与说话人不匹配。"
		for i in scene.lines.size():
			if scene.lines[i].is_empty() or not data.speakers.has(scene.line_speakers[i]): return "商路惊魂对白无效。"
	return ""

static func arrival(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	if not accepted(state): return ""
	var saved:=story(state)
	var location:={"map_id":map_id,"point_id":point_id}
	if not saved.active.is_empty(): return saved.active if saved.location==location else ""
	if location==data.road:
		if saved.stage=="searching": return "ambush"
		if saved.stage=="rescued": return "rescued"
	if saved.stage=="escorting" and map_id==data.shop.map_id:
		if not saved.town_talk_done: return "town_arrival"
		if location==data.shop: return "shop_return"
	return ""

static func battle_ready(state: MapLoadoutState) -> bool:
	return accepted(state) and story(state).stage=="battle"

static func shop_away(state: MapLoadoutState) -> bool:
	return accepted(state) and story(state).stage!="completed"

static func event(scene: String) -> Dictionary:
	var result:Dictionary=data.scenes[scene].duplicate(true)
	result.merge({"id":PREFIX+scene,"type":"dialogue","speaker_id":"base.map_player.chen_yu","presentation":data.presentation.duplicate(true),"speakers":data.speakers.duplicate(true)})
	return result

static func record_victory(state: MapLoadoutState, event_id: String) -> void:
	# Called inside the same durable battle transaction as loot and consumption.
	if event_id!=data.battle.id or not battle_ready(state): return
	story(state).stage="rescued"
	story(state).updated_at=WorldCalendar.current_day(state.calendar)
	# This is the same local beast as the ordinary road encounter; avoid a second immediate fight.
	state.encounter_cooldowns[data.ordinary_encounter_id]=WorldCalendar.current_day(state.calendar)+int(data.ordinary_respawn_days)

static func _finish(saved: Dictionary) -> void:
	saved.active=""; saved.line=0; saved.location={}; saved.reward_pending=false

static func reward_record(state: MapLoadoutState) -> Dictionary:
	var record:Dictionary=MapGatheringRewards.record_for(state.records,MapGatheringRewards.SPIRIT_STONE_ID).duplicate(true)
	record.quantity=int(data.rewards[0].quantity)
	return record

static func command(state: MapLoadoutState, path: String, action: String, scene: String="") -> String:
	var prepared:=MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var next:MapLoadoutState=prepared.state
	var saved:=story(next)
	match action:
		"begin":
			if not saved.active.is_empty(): return "" if saved.active==scene else "请先完成当前对白。"
			if next.map_location.is_empty() or scene.is_empty() or arrival(next,next.map_location.map_id,next.map_location.point_id)!=scene: return "当前地点或进度不能开始这段对白。"
			saved.active=scene; saved.location=next.map_location.duplicate(true)
			if scene=="ambush":
				# The second scene revives this node even if its ordinary beast was killed earlier.
				next.encounter_cooldowns[data.ordinary_encounter_id]=0
		"advance":
			if saved.active.is_empty() or saved.reward_pending: return ""
			if saved.active=="shop_return" and saved.line==0 and next.narrative.flags.get(NAME_FLAG,false): saved.line=4
			elif saved.line+1<data.scenes[saved.active].lines.size():
				if saved.active=="shop_return" and saved.line==3: next.narrative.flags[NAME_FLAG]=true
				saved.line+=1
			elif saved.active=="shop_return": saved.reward_pending=true
			else:
				match saved.active:
					"ambush": saved.stage="battle"
					"rescued": saved.stage="escorting"
					"town_arrival": saved.town_talk_done=true
				_finish(saved)
		"accept":
			if not saved.reward_pending or saved.active!="shop_return": return ""
			var amount:=int(data.rewards[0].quantity)
			if next.spirit_stones>1000000000-amount: return "灵石已达持有上限，暂不能结算。"
			next.spirit_stones+=amount
			saved.stage="completed"
			next.narrative.flags[RESCUE_FLAG]=true
			_finish(saved)
		_: return "未知商路惊魂指令。"
	saved.updated_at=WorldCalendar.current_day(next.calendar)
	next.quest_tracking=QuestTracking.normalized(next.quest_tracking,QuestTracking.entries(next))
	var error:=MapLoadoutStore.save(next,path)
	if not error.is_empty(): return error
	error=state.restore(next.snapshot())
	if error.is_empty(): preload("res://scripts/entry/save_checkpoints.gd").after_action(state,path,"merchant_road")
	return error

static func accept(state: MapLoadoutState) -> void:
	if accepted(state): return
	var saved: Dictionary=state.quests[ID]
	saved.accepted_location="base.map.qingshizhen"
	saved.accepted_at=WorldCalendar.current_day(state.calendar)
	saved.updated_at=saved.accepted_at

static func display_entry(state: MapLoadoutState, presentation: Dictionary) -> Dictionary:
	var result:=presentation.duplicate(true)
	result.merge(state.quests[ID],true)
	var saved:=story(state)
	result.stage_id=saved.stage
	result.objectives=data.objectives.duplicate(true)
	var stage_index:int=["searching","battle","rescued","escorting","completed"].find(saved.stage)
	for i in result.objectives.size(): result.objectives[i].completed=stage_index>i
	result.objectives.resize(mini(4,stage_index+1))
	result.people=data.people.duplicate(true)
	result.rewards=data.rewards.duplicate(true)
	result.location={"name":"青石镇·商铺" if stage_index>=3 else "青石河湾·翻车商道","image":"res://assets/map-qingshizhen.webp" if stage_index>=3 else "res://assets/gamemap-qingshihewan.webp"}
	result.has_locked_next=stage_index<3
	return result
