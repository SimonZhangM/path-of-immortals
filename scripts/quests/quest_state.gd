class_name QuestState
extends RefCounted
## Quest facts belong to the loadout transaction; widgets never advance them.
const ID := "quest.prologue.yaoxiangruchang"
const FLAG := "base.story.quest.yaoxiangruchang."
static var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/prologue.json"))

static func initial(day: int, location := "") -> Dictionary:
	var counts := {}
	for target: Dictionary in definition.objectives: counts[target.id] = 0
	var quest := {"counts":counts,"accepted_at":day,"updated_at":day,"accepted_location":location}
	quest.story = QuestStory.migrated(quest)
	return {ID:quest,RiverQuest.ID:RiverQuest.initial(),HerbQuest.ID:HerbQuest.initial()}

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary or not raw.get(ID) is Dictionary: return false
	for id: String in raw:
		if id not in [ID,RiverQuest.ID,HerbQuest.ID]: return false
	if raw.has(RiverQuest.ID) and not RiverQuest.valid(raw[RiverQuest.ID]): return false
	if raw.has(HerbQuest.ID) and not HerbQuest.valid(raw[HerbQuest.ID]): return false
	var quest: Dictionary = raw[ID]
	if not quest.get("counts") is Dictionary or quest.counts.size()!=definition.objectives.size(): return false
	if not quest.get("accepted_location") is String: return false
	for key in ["accepted_at","updated_at"]:
		if not WorldCalendar.integer_between(quest.get(key),0,WorldCalendar.MAX_DAY): return false
	for target: Dictionary in definition.objectives:
		if not WorldCalendar.integer_between(quest.counts.get(target.id),0,int(target.required)): return false
	if quest.counts.talk==0 and (quest.counts.visit>0 or quest.counts.kuaiye>0 or quest.counts.xilutai>0 or quest.counts.deliver>0): return false
	if quest.counts.deliver>0 and (quest.counts.visit==0 or quest.counts.kuaiye==0 or quest.counts.xilutai==0): return false
	if quest.has("story"):
		if not QuestStory.valid(quest.story): return false
		if quest.counts.deliver>0 and (not quest.story.active.is_empty() or not quest.story.pending.is_empty() or quest.story.wake_pending): return false
		# Legacy one-per-herb saves may still be in the return dialogue.
		if quest.story.active=="returning" and (quest.counts.visit==0 or quest.counts.kuaiye==0 or quest.counts.xilutai==0): return false
	return true

static func normalized(raw: Dictionary) -> Dictionary:
	var result := raw.duplicate(true)
	for key in ["accepted_at","updated_at"]: result[ID][key] = int(result[ID][key])
	for key: String in result[ID].counts: result[ID].counts[key] = int(result[ID].counts[key])
	# A settled legacy quest stays settled when requirements increase.
	if result[ID].counts.deliver>0:
		for target: Dictionary in definition.objectives:
			result[ID].counts[target.id] = int(target.required)
	result[ID].story = QuestStory.migrated(result[ID])
	result[ID].story.line = int(result[ID].story.line)
	if not result.has(RiverQuest.ID): result[RiverQuest.ID] = RiverQuest.initial()
	result[RiverQuest.ID] = RiverQuest.normalized(result[RiverQuest.ID])
	if not result.has(HerbQuest.ID): result[HerbQuest.ID] = HerbQuest.initial()
	for key in ["line","accepted_at","updated_at"]: result[HerbQuest.ID][key] = int(result[HerbQuest.ID][key])
	for key in ["line","accepted_at","updated_at"]: result[RiverQuest.ID][key] = int(result[RiverQuest.ID][key])
	return result

static func stage(quests: Dictionary) -> String:
	var counts: Dictionary = quests[ID].counts
	if counts.talk==0: return "morning"
	if counts.visit==0: return "travel"
	if not objective_complete(counts,"kuaiye") or not objective_complete(counts,"xilutai"): return "gathering"
	return "returning"

static func required_quantity(target_id: String) -> int:
	for target: Dictionary in definition.objectives:
		if target.id==target_id: return int(target.required)
	return 1

static func objective_complete(counts: Dictionary, target_id: String) -> bool:
	return int(counts.get(target_id,0))>=required_quantity(target_id)

static func record(state: MapLoadoutState, target_id: String, quantity := 1) -> void:
	var quest: Dictionary = state.quests[ID]
	var required := required_quantity(target_id)
	if int(quest.counts[target_id])>=required or quantity<=0: return
	quest.counts[target_id] = mini(required,int(quest.counts[target_id])+quantity)
	quest.updated_at = WorldCalendar.current_day(state.calendar)
	state.revision += 1
	sync_flags(state)

static func arrived(state: MapLoadoutState, map_id: String) -> void:
	if state.quests[ID].counts.talk>0 and map_id==definition.map_id: record(state,"visit")

static func gathered(state: MapLoadoutState, offer: Dictionary) -> void:
	if offer.get("quest_id","")!=ID or state.quests[ID].counts.talk==0 or state.quests[ID].counts.visit==0: return
	for target: Dictionary in definition.objectives:
		if target.get("item_id","")==offer.item_id: record(state,target.id,int(offer.quantity))
	QuestStory.gathered(state,offer)

static func delivery_units(state: MapLoadoutState) -> Array[String]:
	var result: Array[String] = []
	for target: Dictionary in definition.objectives:
		if not target.has("item_id"): continue
		var remaining := int(target.required)
		for entry: Dictionary in state.storage.entries():
			if entry.item_id!=target.item_id: continue
			for unit: Dictionary in entry.units:
				result.append(str(unit.id))
				remaining -= 1
				if remaining==0: break
			if remaining==0: break
		if remaining>0: return []
	return result

static func sync_flags(state: MapLoadoutState) -> void:
	HerbQuest.refresh_objectives(state)
	var counts: Dictionary = state.quests[ID].counts
	state.narrative.flags[FLAG+"morning"] = counts.talk==0
	state.narrative.flags[FLAG+"ready"] = stage(state.quests)=="returning" and counts.deliver==0 and not delivery_units(state).is_empty()
	# Keep old topic IDs/history valid, but all new playback uses map story dialogue.
	state.narrative.flags[FLAG+"map_dialogue"] = true

static func after_dialogue(state: MapLoadoutState, previous: Dictionary, npc_id: String) -> String:
	if npc_id!=definition.npc_id: return ""
	var done: Array = state.narrative.npcs.get(npc_id,{}).get("done",[])
	var old_done: Array = previous.npcs.get(npc_id,{}).get("done",[])
	if definition.accept_segment in done and definition.accept_segment not in old_done:
		record(state,"talk")
	if definition.deliver_segment not in done or definition.deliver_segment in old_done: return ""
	return settle_delivery(state)

static func settle_delivery(state: MapLoadoutState) -> String:
	if state.quests[ID].counts.deliver>0: return ""
	if stage(state.quests)!="returning": return "请先完成本次采药。"
	var units := delivery_units(state)
	if units.is_empty(): return "储物袋中需要苦艾叶、溪露苔各3株，请备齐后继续交药。"
	if state.spirit_stones>999999995: return "灵石已达持有上限，暂不能结算。"
	# Removal, completion and currency are committed in the caller's single save.
	var next := state.snapshot()
	for unit_id: String in units: next.owned_units.erase(unit_id)
	next.spirit_stones += int(definition.rewards[0].quantity)
	next.quests[ID].counts.deliver = 1
	next.quest_tracking.ids.erase(ID)
	next.quests[ID].updated_at = WorldCalendar.current_day(state.calendar)
	return state.restore(next)

static func display_entry(state: MapLoadoutState, presentation: Dictionary) -> Dictionary:
	var result := presentation.duplicate(true)
	var quest: Dictionary = state.quests[ID]
	result.merge(quest,true)
	result.stage_id = stage(state.quests)
	result.objectives = []
	var groups := ["morning","travel","gathering","returning"]
	# Presentation groups do not change the stable per-item save counters.
	for goal: Dictionary in definition.display_objectives:
		if groups.find(goal.group)>groups.find(result.stage_id): continue
		var row := goal.duplicate(true)
		row.completed = true
		row.show_count = false
		row.requirements = []
		for target: Dictionary in definition.objectives:
			if target.id not in goal.counter_ids: continue
			var requirement := target.duplicate(true)
			requirement.current = int(quest.counts[target.id])
			requirement.completed = requirement.current>=int(target.required)
			row.completed = row.completed and requirement.completed
			row.requirements.append(requirement)
		if row.requirements.size()==1:
			row.merge(row.requirements[0],true)
			row.erase("requirements")
		result.objectives.append(row)
	result.has_locked_next = result.stage_id!="returning"
	result.rewards = definition.rewards.duplicate(true)
	result.people = definition.people.duplicate(true)
	result.location = definition.locations[result.stage_id].duplicate(true)
	if quest.counts.deliver>0: result.stage_id = "completed"
	return result
