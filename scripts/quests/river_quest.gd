class_name RiverQuest
extends RefCounted
## River/shrine story facts; all mutations use the loadout save transaction.
const ID := "quest.prologue.hewanfengxian"
const PREFIX := "base.map_event.quest.hewanfengxian."
const RIVER := "base.map.qingshihewan"
const SHRINE := "base.map.wumingjiuci"
const TOWN := "base.map.qingshizhen"
const Illustration = preload("res://scripts/dialogue/dialogue_illustration.gd")
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/river_story.json"))

static func initial() -> Dictionary:
	return {"done":[],"active":"","line":0,"location":{},"reward_pending":false,"accepted_at":0,"updated_at":0,"accepted_location":"","parcels":{}}

static func story(state: MapLoadoutState) -> Dictionary:
	return state.quests[ID]

static func done(state: MapLoadoutState, id: String) -> bool:
	return id in story(state).done

static func enabled(state: MapLoadoutState) -> bool:
	return state.quests[QuestState.ID].counts.deliver>0

static func configuration_error() -> String:
	if data.get("quest_id")!=ID: return "河湾任务标识无效。"
	for id: String in data.scenes:
		var entry: Dictionary = data.scenes[id]
		var sequence_error := Illustration.sequence_error(entry.get("illustration",{}),entry.lines.size())
		if not sequence_error.is_empty(): return sequence_error
		if entry.lines.is_empty() or entry.lines.size()!=entry.line_speakers.size(): return "河湾对白与说话人不匹配："+id
		if not MapLoadoutState.valid_map_location({"map_id":entry.map_id,"point_id":entry.point_id}): return "河湾剧情地点无效。"
		for i in entry.lines.size():
			if entry.lines[i].is_empty() or not data.speakers.has(entry.line_speakers[i]): return "河湾对白内容无效。"
		for required: String in entry.requires:
			if not data.scenes.has(required): return "河湾剧情前置不存在。"
		if entry.has("reward_after_line") and (not entry.has("reward") or not WorldCalendar.integer_between(entry.reward_after_line,0,entry.lines.size()-1)):
			return "河湾物品领取时机无效。"
		for choice: Dictionary in entry.get("choices",[]):
			if not data.scenes.has(choice.next_scene): return "河湾剧情选项目标不存在。"
	return ""

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary or not raw.get("done") is Array or not raw.get("active") is String: return false
	if not raw.get("reward_pending") is bool or not raw.get("location") is Dictionary or not raw.get("parcels") is Dictionary: return false
	if not raw.get("accepted_location") is String: return false
	for key in ["accepted_at","updated_at"]:
		if not WorldCalendar.integer_between(raw.get(key),0,WorldCalendar.MAX_DAY): return false
	if not WorldCalendar.integer_between(raw.get("line"),0,1000): return false
	raw = normalized(raw)
	var seen := {}
	for id: Variant in raw.done:
		if not id is String or not data.scenes.has(id) or seen.has(id): return false
		seen[id] = true
		for required: String in data.scenes[id].requires:
			if required not in raw.done: return false
	if raw.active.is_empty():
		if raw.line!=0 or raw.reward_pending or not raw.location.is_empty(): return false
	else:
		if not data.scenes.has(raw.active) or raw.line>=data.scenes[raw.active].lines.size(): return false
		if raw.active in raw.done and not data.scenes[raw.active].get("repeat",false): return false
		if not MapLoadoutState.valid_map_location(raw.location) or raw.location.is_empty(): return false
		var scene: Dictionary = data.scenes[raw.active]
		var legacy_traces: bool = raw.active=="traces" and raw.location.point_id==data.scenes.injured.point_id
		if raw.location.map_id!=scene.map_id or (not scene.get("any_point",false) and not legacy_traces and raw.location.point_id!=scene.point_id and raw.location.point_id not in scene.get("recovery_points",[])): return false
		for required: String in scene.requires:
			if required not in raw.done: return false
		if raw.reward_pending:
			if scene.has("reward"):
				# Old saves may already be awaiting this reward at the former last line.
				if raw.line<int(scene.get("reward_after_line",scene.lines.size()-1)): return false
			elif not scene.has("handover") or raw.line!=scene.lines.size()-1: return false
	for id: Variant in raw.parcels:
		if not data.scenes.has(id) or not data.scenes[id].has("reward") or raw.parcels[id]!=data.scenes[id].reward: return false
		if id not in raw.done and (raw.active!=id or raw.reward_pending or raw.line<=int(data.scenes[id].get("reward_after_line",data.scenes[id].lines.size()-1))): return false
	return true

static func normalized(raw: Dictionary) -> Dictionary:
	var saved := raw.duplicate(true)
	# The pre-existing gate warning uses the same two lines; preserve its cursor.
	if saved.active=="blocked_exit" and "root" in saved.done and "mirror" not in saved.done and "courtyard_check" not in saved.done:
		saved.active = "courtyard_check"
	# Grandfather an already started/completed mirror scene across the new gate visit.
	if (saved.active=="mirror" or "mirror" in saved.done) and "courtyard_check" not in saved.done:
		saved.done.append("courtyard_check")
	# A clinic handover left open by the previous version is superseded by
	# the new river timing. Keep its inventory and existing completed facts.
	if saved.active not in ["return_jade","jade_missing"] or "clinic_arrival" not in saved.done:
		return saved
	var clinic: Dictionary = data.scenes.clinic_arrival
	if saved.location!={"map_id":clinic.map_id,"point_id":clinic.point_id}:
		return saved
	var last_line := 1 if saved.active=="return_jade" else 0
	if not WorldCalendar.integer_between(saved.line,0,last_line):
		return saved
	if saved.reward_pending and (saved.active!="return_jade" or saved.line!=last_line):
		return saved
	saved.active = ""
	saved.line = 0
	saved.location = {}
	saved.reward_pending = false
	return saved

static func picture_page(saved: Dictionary) -> int:
	if saved.active.is_empty(): return -1
	return Illustration.page_at(data.scenes[saved.active].get("illustration",{}),int(saved.line))

static func event(id: String) -> Dictionary:
	var result: Dictionary = data.scenes[id].duplicate(true)
	result.merge({"id":PREFIX+id,"type":"dialogue","speaker_id":"base.map_player.chen_yu","presentation":data.presentation.duplicate(true),"speakers":data.speakers.duplicate(true)})
	if result.has("illustration"): result.presentation.illustration = result.illustration
	return result

static func allowed(state: MapLoadoutState, id: String) -> bool:
	var entry: Dictionary = data.scenes[id]
	if id=="invite_doctor" and not done(state,"return_jade"): return false
	if id=="root_discovery" and done(state,"root"): return false
	if not MapEventRegistry.story_allowed(state,entry.point_id): return false
	if not entry.get("optional",false) and not enabled(state): return false
	if done(state,id) and not entry.get("repeat",false): return false
	for required: String in entry.requires:
		if not done(state,required): return false
	for completed: String in entry.get("skip_after",[]):
		if done(state,completed): return false
	if entry.has("requires_receipt") and not state.has_reward(entry.requires_receipt): return false
	return true

static func arrival(state: MapLoadoutState, map_id: String, point_id: String, manual := false) -> String:
	var saved := story(state)
	if not saved.active.is_empty():
		if not MapEventRegistry.story_allowed(state,point_id): return ""
		return saved.active if saved.location=={"map_id":map_id,"point_id":point_id} else ""
	# Entry is recovered at the actual saved point too, including pre-feature saves.
	if map_id==SHRINE and allowed(state,"entrance"): return "entrance"
	if map_id==RIVER and allowed(state,"blood_herb") and not done(state,"root") and item_count(state,"base.material.zhixuecao")>0: return "blood_herb"
	for id in ["traces","injured","detour","root_discovery","courtyard_check","mirror","beasts_gone","fox_release","fox_notice","array","wood_door","stone_door","medicine","return_jade","invite_doctor","pickup","clinic_arrival","gift_book","closing"]:
		var entry: Dictionary = data.scenes[id]
		if entry.map_id==map_id and (entry.point_id==point_id or point_id in entry.get("recovery_points",[])) and allowed(state,id):
			if id=="medicine" and not has_medicine(state): return "medicine_missing"
			if id=="return_jade" and bag_count(state,"base.map_item.warm_jade")==0: return "jade_missing"
			return id
	if manual and map_id==TOWN and point_id==data.scenes.invite_doctor.point_id and doctor_away(state):
		return "bringing_back" if done(state,"pickup") else "doctor_away"
	# A legacy save already at the temple must still read the path observation.
	if enabled(state) and map_id==RIVER and point_id==data.scenes.injured.point_id and not done(state,"traces"): return "traces"
	if map_id==SHRINE:
		if point_id==data.scenes.fox_notice.point_id and done(state,"fox_notice") and not done(state,"fox_rescue"): return "fox_choice"
	if manual and map_id==SHRINE:
		for id in ["array_again","wood_door_again","stone_door_again"]:
			if point_id==data.scenes[id].point_id and allowed(state,id): return id
	return ""

static func doctor_away(state: MapLoadoutState) -> bool:
	return done(state,"invite_doctor") and not done(state,"clinic_arrival") and story(state).active!="clinic_arrival"

static func migrate_root_discovery(saved: Dictionary, receipts: Dictionary) -> void:
	# Keep already issued legacy roots/parcels; unclaimed automatic rewards
	# resume as discovery and must use the ordinary harvesting transaction.
	if saved.active!="root" or receipts.has(data.scenes.root.reward.id) or saved.parcels.has("root"): return
	saved.active = "root_discovery"
	saved.line = 0
	saved.reward_pending = false
	saved.done.erase("root_discovery")

static func gathered(state: MapLoadoutState, event: Dictionary) -> void:
	if event.id!="base.map_event.wumingjiuci.gathering_n31" or not done(state,"root_discovery") or done(state,"root"): return
	var saved := story(state)
	saved.done.append("root")
	saved.updated_at = WorldCalendar.current_day(state.calendar)

static func bag_count(state: MapLoadoutState, item_id: String) -> int:
	var count := 0
	for entry: Dictionary in state.storage.entries():
		if entry.item_id==item_id: count += entry.units.size()
	return count

static func has_medicine(state: MapLoadoutState) -> bool:
	return item_count(state,"base.material.zhixuecao")>0 and item_count(state,"base.material.qingtenggen")>0

static func _consume(state: MapLoadoutState, items: Array, allow_parcels := false) -> String:
	var snapshot := state.snapshot()
	if not snapshot.has("granted_rewards"): snapshot.granted_rewards = {}
	for item: Dictionary in items:
		var remaining := int(item.quantity)
		for entry: Dictionary in state.storage.entries():
			if entry.item_id!=item.item_id: continue
			for unit: Dictionary in entry.units:
				if remaining==0: break
				if snapshot.owned_units.has(unit.id):
					snapshot.owned_units.erase(unit.id)
					remaining -= 1
		if allow_parcels:
			for id: String in snapshot.quests[ID].parcels.keys():
				var parcel: Dictionary = snapshot.quests[ID].parcels[id]
				if remaining==int(parcel.quantity) and parcel.item_id==item.item_id:
					snapshot.granted_rewards[parcel.id] = {"item_id":parcel.item_id,"quantity":parcel.quantity}
					snapshot.quests[ID].parcels.erase(id)
					remaining = 0
		if remaining>0: return "行囊中物品不足，请备齐后再来。"
	return state.restore(snapshot)

static func exit_blocked(state: MapLoadoutState, map_id: String) -> bool:
	return map_id==SHRINE and enabled(state) and done(state,"injured") and not done(state,"beasts_gone")

static func gates(state: MapLoadoutState, map_id: String) -> Dictionary:
	var result := {"routes":{},"points":{}}
	if map_id==RIVER and not done(state,"injured"):
		for id: String in data.river_gate_routes: result.routes[id] = true
	if map_id==SHRINE and enabled(state) and done(state,"injured") and not done(state,"root"):
		result.points[data.shrine_hidden_point] = true
		for id: String in data.shrine_hidden_routes: result.routes[id] = true
	return result

static func _begin(next: MapLoadoutState, id: String) -> void:
	var saved := story(next)
	saved.active = id
	saved.line = 0
	saved.location = next.map_location.duplicate(true)
	saved.reward_pending = false
	if id=="traces" and saved.accepted_location.is_empty():
		saved.accepted_at = WorldCalendar.current_day(next.calendar)
		saved.accepted_location = RIVER
		next.quest_tracking.ids = [ID]

static func _finish(next: MapLoadoutState) -> void:
	var saved := story(next)
	var id: String = saved.active
	if id not in saved.done: saved.done.append(id)
	saved.active = ""
	saved.line = 0
	saved.location = {}
	saved.reward_pending = false
	if id=="mirror": next.narrative.flags["base.story.hewanfengxian.broken_mirror"] = true
	if id=="fox_rescue": next.narrative.flags["base.story.wumingjiuci.fox_rescued"] = true
	if id=="fox_release": next.narrative.flags["base.story.wumingjiuci.fox_released"] = true
	if id=="closing":
		next.narrative.flags["base.story.qingshihewan.cultivator_rescued"] = true
		next.quest_tracking.ids.erase(ID)
	if data.scenes[id].has("next_scene"): _begin(next,data.scenes[id].next_scene)

static func _continue_after_reward(next: MapLoadoutState) -> void:
	var saved := story(next)
	if saved.line+1<data.scenes[saved.active].lines.size():
		saved.reward_pending = false
		saved.line += 1
	else:
		_finish(next)

static func command(state: MapLoadoutState, path: String, action: String, value := "") -> String:
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var next: MapLoadoutState = prepared.state
	next.storage_capacity_rules = state.storage_capacity_rules
	var saved := story(next)
	match action:
		"begin":
			if not data.scenes.has(value): return "河湾对白未配置。"
			if not saved.active.is_empty(): return "" if saved.active==value else "请先完成当前对白。"
			if next.map_location.is_empty(): return "缺少当前剧情地点。"
			var expected := arrival(next,next.map_location.map_id,next.map_location.point_id,true)
			if value=="blocked_exit":
				if not exit_blocked(next,next.map_location.map_id) or not done(next,"entrance") or next.map_location.point_id!=data.scenes.blocked_exit.point_id: return "此处不能触发门外观察。"
			elif value!=expected: return "当前地点或阶段不能触发这段对白。"
			if data.scenes[value].has("consume"):
				var consume_error := _consume(next,data.scenes[value].consume,true)
				if not consume_error.is_empty(): return consume_error
			_begin(next,value)
		"advance":
			if saved.active.is_empty() or saved.reward_pending: return ""
			var entry: Dictionary = data.scenes[saved.active]
			var reward_due: bool = entry.has("reward") and not next.has_reward(entry.reward.id) and not saved.parcels.has(saved.active)
			var page := picture_page(saved)
			if page>=0:
				var art: Dictionary = entry.illustration
				saved.line = int(art.pages[page+1].line) if page+1<art.pages.size() else int(art.resume_line)
			elif reward_due and saved.line>=int(entry.get("reward_after_line",entry.lines.size()-1)):
				saved.reward_pending = true
			elif saved.line+1<entry.lines.size(): saved.line += 1
			elif entry.has("choices"): return "请先选择要做的事。"
			elif entry.has("handover"): saved.reward_pending = true
			else: _finish(next)
		"choose":
			if saved.active!="fox_choice" or done(next,"fox_rescue"): return "当前没有可用选项。"
			var target := ""
			for choice: Dictionary in data.scenes.fox_choice.choices:
				if choice.id==value: target = choice.next_scene
			if target.is_empty(): return "未知选项。"
			_begin(next,target)
		"accept", "reserve":
			if not saved.reward_pending: return ""
			if data.scenes[saved.active].has("handover"):
				if action!="accept": return "交还物品需要确认。"
				var consume_error := _consume(next,[data.scenes[saved.active].handover])
				if not consume_error.is_empty(): return consume_error
				_finish(next)
			else:
				var reward: Dictionary = data.scenes[saved.active].reward
				if action=="accept":
					var error := next.add_reward(reward)
					if not error.is_empty(): return error
				else:
					story(next).parcels[saved.active] = reward.duplicate(true)
				_continue_after_reward(next)
		"claim_parcels":
			var claimed := false
			for id: String in saved.parcels.keys():
				if next.add_reward(saved.parcels[id]).is_empty():
					story(next).parcels.erase(id)
					claimed = true
			if not claimed: return ""
		_: return "未知河湾剧情指令。"
	story(next).updated_at = WorldCalendar.current_day(next.calendar)
	next.quest_tracking = QuestTracking.normalized(next.quest_tracking,QuestTracking.entries(next))
	var error := MapLoadoutStore.save(next,path)
	if not error.is_empty(): return error
	error = state.restore(next.snapshot())
	if error.is_empty(): preload("res://scripts/entry/save_checkpoints.gd").after_action(state,path,"river_story")
	return error

static func item_count(state: MapLoadoutState, id: String) -> int:
	var count := 0
	for item: String in state.carried_owned().values():
		if item==id: count += 1
	for reward: Dictionary in story(state).parcels.values():
		if reward.item_id==id: count += int(reward.quantity)
	return count

static func display_entry(state: MapLoadoutState, presentation: Dictionary) -> Dictionary:
	var result := presentation.duplicate(true)
	result.merge(story(state),true)
	result.stage_id = "returning" if done(state,"beasts_gone") else ("shrine" if done(state,"entrance") else ("medicine" if done(state,"injured") else "traces"))
	if done(state,"detour") and not done(state,"entrance"): result.stage_id = "detour"
	for pair in [["medicine","doctor"],["invite_doctor","pickup"],["pickup","clinic"],["clinic_arrival","settling"],["closing","completed"]]:
		if done(state,pair[0]): result.stage_id = pair[1]
	if done(state,"medicine") and not done(state,"return_jade") and not done(state,"invite_doctor"):
		result.stage_id = "return_jade"
	if result.stage_id=="returning" and item_count(state,"base.material.zhixuecao")==0:
		result.introductions.returning = "祠中的事暂告一段落，包里的残镜却让人心里发沉。方才一闪而过的画面究竟是什么，眼下无从分辨。还需备齐止血草，再回小庙帮助沈砚舟。"
	result.objectives = []
	_objective(result,"injured","沿血迹查看情况",done(state,"injured"),RIVER,20)
	if done(state,"injured"):
		_objective(result,"zhixuecao","备齐止血草",done(state,"medicine") or item_count(state,"base.material.zhixuecao")>0,RIVER,4,true)
		result.objectives.back().merge({"current":bag_count(state,"base.material.zhixuecao"),"inline_count":true},true)
		_objective(result,"root","寻找青藤根",done(state,"root"),SHRINE if done(state,"entrance") else RIVER,31 if done(state,"entrance") else 3,true)
		result.objectives.back().merge({"current":bag_count(state,"base.material.qingtenggen"),"inline_count":true},true)
		if done(state,"detour") and not done(state,"entrance"):
			result.objectives.back().targets = []
	if done(state,"detour"):
		_objective(result,"shelter","前往无名旧祠",done(state,"entrance"),RIVER,2)
	if done(state,"entrance"):
		_objective(result,"leave","取药后返回前院，查看门外动静",done(state,"beasts_gone"),SHRINE,5 if done(state,"courtyard_check") and not done(state,"mirror") else 1)
		result.objectives.back().targets[0].point_marker = done(state,"root")
	if done(state,"beasts_gone"):
		_objective(result,"return","带着药材返回沈砚舟身边",done(state,"medicine"),RIVER,20)
	if done(state,"medicine"):
		if not done(state,"invite_doctor") or done(state,"return_jade"):
			_objective(result,"jade","归还温玉佩",done(state,"return_jade"),RIVER,20)
		if done(state,"return_jade") or done(state,"invite_doctor"):
			_objective(result,"doctor","回医馆请苏清禾",done(state,"invite_doctor"),TOWN,32)
	if done(state,"invite_doctor"):
		_objective(result,"pickup","带清禾到小庙旁接沈砚舟",done(state,"pickup"),RIVER,20)
	if done(state,"pickup"):
		_objective(result,"settle","送沈砚舟到医馆安置",done(state,"closing"),TOWN,32)
	if done(state,"clinic_arrival"):
		_objective(result,"book","收下《引气诀》",state.has_reward(data.scenes.gift_book.reward.id),TOWN,32)
	result.has_locked_next = not done(state,"pickup")
	result.people = [{"name":"沈砚舟" if done(state,"injured") else "青岚宗弟子","portrait":"res://assets/npc-qlzdz-1.webp"}]
	if done(state,"medicine"): result.people.append({"name":"苏清禾","portrait":"res://assets/UI-portrait-suqinghe.webp"})
	result.rewards = []
	if done(state,"clinic_arrival"): result.rewards = [{"kind":"item","item_id":data.scenes.gift_book.reward.item_id,"name":"引气诀","quantity":1}]
	result.location = {"name":"无名旧祠" if result.stage_id=="shrine" else "青石河湾","image":"res://assets/map-wumingjiuci.webp" if result.stage_id=="shrine" else "res://assets/gamemap-qingshihewan.webp"}
	if result.stage_id in ["doctor","clinic","settling","completed"]:
		result.location = {"name":"青石镇","image":"res://assets/map-qingshizhen.webp"}
	return result

static func _objective(result: Dictionary, id: String, text: String, completed: bool, map_id: String, number: int, count := false) -> void:
	result.objectives.append({"id":id,"text":text,"completed":completed,"show_count":count,"current":1 if completed else 0,"required":1,
		"targets":[{"map_id":map_id,"point_id":map_id+".point.n%02d"%number,"world_location_id":"base.world_location."+map_id.get_slice(".",2)}]})
