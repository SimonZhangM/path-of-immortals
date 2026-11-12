class_name HomecomingQuest
extends RefCounted
## The letter introduction opens the third main quest and the village route.
const ID := "quest.prologue.chaoshengguichu"
const PREFIX := "base.map_event.quest.chaoshengguichu."
const ACCEPTED_FLAG := "base.story.chaoshengguichu.accepted"
const MOTHER := "base.npc.mother"
const REUNION_FLAG := "base.story.chaoshengguichu.home_reunited"
const GUIDED_FLAG := "base.story.chaoshengguichu.guided"
const PRACTICE_STARTED_FLAG := "base.story.chaoshengguichu.breakthrough_started"
const PREPARATION_FLAG := "base.story.chaoshengguichu.preparation_guided"
const BREAKTHROUGH_FAILED_FLAG := "base.story.chaoshengguichu.breakthrough_failed"
const COMPLETED_FLAG := "base.story.chaoshengguichu.completed"
const FIRST_QI_FLAG := "base.story.chaoshengguichu.qi_confirmed"
const OBJECTIVE_STAGES := ["intro", "homeward", "chat", "talks", "guidance", "practice", "rejoice"]
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/homecoming_story.json"))

static func initial() -> Dictionary:
	return {"active":"","line":0,"location":{},"reward_pending":false,
		"accepted_at":0,"updated_at":0,"accepted_location":"","letter_received":false,"home_reunited":false,"guidance_completed":false}

static func story(state: MapLoadoutState) -> Dictionary:
	return state.quests[ID]

static func accepted(state: MapLoadoutState) -> bool:
	return story(state).letter_received

static func available(state: MapLoadoutState) -> bool:
	return RiverQuest.done(state,"closing") and story(state).active.is_empty() and (not accepted(state) or not MerchantRoadQuest.accepted(state))

static func configuration_error() -> String:
	if data.get("quest_id")!=ID or not MapLoadoutState.valid_map_location(data.shop): return "潮声归处接取地点无效。"
	for scene: Dictionary in data.scenes.values():
		if scene.lines.is_empty() or scene.lines.size()!=scene.line_speakers.size(): return "潮声归处对白与说话人不匹配。"
		if scene.has("reward") and not WorldCalendar.integer_between(scene.get("reward_after_line"),0,scene.lines.size()-2): return "潮声归处物品领取时机无效。"
		for index in scene.lines.size():
			if scene.lines[index].is_empty() or not data.speakers.has(scene.line_speakers[index]): return "潮声归处对白内容无效。"
	return ""

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	for key in ["active","accepted_location"]:
		if not raw.get(key) is String: return false
	for key in ["accepted_at","updated_at"]:
		if not WorldCalendar.integer_between(raw.get(key),0,WorldCalendar.MAX_DAY): return false
	if not raw.get("reward_pending") is bool or not raw.get("letter_received") is bool: return false
	if raw.reward_pending and not data.scenes.has(raw.active): return false
	if not raw.get("home_reunited",false) is bool: return false
	if not raw.get("guidance_completed",false) is bool: return false
	if raw.get("guidance_completed",false) and not raw.get("home_reunited",false): return false
	if not raw.get("location") is Dictionary or not WorldCalendar.integer_between(raw.get("line"),0,1000): return false
	if raw.accepted_location not in ["",data.shop.map_id]: return false
	# Both openings share a dialogue layer, but each quest starts only after its own last line.
	if raw.active in ["merchant_intro","bridge","intro"]:
		if raw.location!=data.shop or raw.line>=data.scenes[raw.active].lines.size(): return false
		if raw.active!="merchant_intro" and raw.letter_received: return false
		var opening: Dictionary=data.scenes[raw.active]
		return not raw.reward_pending or (opening.has("reward") and raw.line==opening.reward_after_line)
	if raw.accepted_location.is_empty():
		return raw.active.is_empty() and raw.line==0 and raw.location.is_empty() and not raw.letter_received and not raw.get("home_reunited",false) and raw.accepted_at==0 and raw.updated_at==0
	if raw.active.is_empty(): return raw.line==0 and raw.location.is_empty() and raw.letter_received
	if not data.scenes.has(raw.active) or raw.line>=data.scenes[raw.active].lines.size(): return false
	var scene: Dictionary = data.scenes[raw.active]
	if raw.reward_pending and (not scene.has("reward") or raw.line!=scene.reward_after_line): return false
	if raw.active=="guidance": return raw.location==data.home and raw.letter_received and raw.get("home_reunited",false) and not raw.get("guidance_completed",false)
	if raw.active=="preparation": return raw.location==data.home and raw.letter_received and raw.get("guidance_completed",false) and not raw.reward_pending
	if raw.active=="rejoice": return raw.location==data.home and raw.letter_received and raw.get("guidance_completed",false) and not raw.reward_pending
	if raw.get("home_reunited",false): return false
	if raw.active=="intro": return raw.location==data.shop and not raw.letter_received
	return raw.active=="reunion" and raw.location==data.home and raw.letter_received

static func arrival(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	var location := {"map_id":map_id,"point_id":point_id}
	if not MapEventRegistry.story_allowed(state,point_id): return ""
	var saved := story(state)
	if not saved.active.is_empty(): return saved.active if saved.location==location else ""
	if location==data.home and rejoice_available(state): return "rejoice"
	if location==data.home and guidance_available(state): return "guidance"
	if location==data.home and preparation_available(state): return "preparation"
	if location==data.home and saved.letter_received and not saved.home_reunited: return "reunion"
	if location==data.shop and available(state):
		return "intro" if MerchantRoadQuest.accepted(state) else "merchant_intro"
	return ""

static func interaction(state: MapLoadoutState, map_id: String, point_id: String) -> String:
	return arrival(state,map_id,point_id)

static func migrate(saved: Dictionary, narrative: Dictionary) -> void:
	if saved.has("guidance_completed"): return
	var done: Array = narrative.npcs.get(MOTHER,{}).get("done",[])
	saved.guidance_completed = saved.home_reunited and "base.dialogue.mother.cultivation" in done and "base.dialogue.mother.past" in done

static func topic_done(state: MapLoadoutState, topic: String) -> bool:
	return "base.dialogue.mother."+topic in state.narrative.npcs.get(MOTHER,{}).get("done",[])

static func ready_for_practice(state: MapLoadoutState) -> bool:
	return story(state).get("guidance_completed",false)

static func completed(state: MapLoadoutState) -> bool:
	return state.narrative.flags.get(COMPLETED_FLAG,false)

static func rejoice_available(state: MapLoadoutState) -> bool:
	# The prototype's high realm alone is not evidence of a real first breakthrough.
	return accepted(state) and ready_for_practice(state) and story(state).active.is_empty() and not completed(state) and int(state.growth.realm)>=1 and state.narrative.flags.get(FIRST_QI_FLAG,false)

static func cultivation_full(state: MapLoadoutState) -> bool:
	# Advancing to qi resets ordinary progress, but preserves this achieved goal.
	return int(state.growth.realm)>=1 or int(state.growth.progress)>=CultivationGrowth.target(state.growth)

static func preparation_available(state: MapLoadoutState) -> bool:
	return ready_for_practice(state) and story(state).active.is_empty() and int(state.growth.realm)==0 and not state.narrative.flags.get(PREPARATION_FLAG,false)

static func sync_practice_flags(state: MapLoadoutState) -> void:
	var learning := ready_for_practice(state) and int(state.growth.realm)==0
	if state.growth.get("breakthrough_attempt",{}).get("phase","")=="failed":
		state.narrative.flags[BREAKTHROUGH_FAILED_FLAG] = true
	var failed: bool = learning and state.narrative.flags.get(BREAKTHROUGH_FAILED_FLAG,false)
	var full := cultivation_full(state)
	state.narrative.flags["base.story.chaoshengguichu.practice_pending"] = learning and not full and not failed
	state.narrative.flags["base.story.chaoshengguichu.practice_ready"] = learning and full and not failed
	state.narrative.flags["base.story.chaoshengguichu.practice_failed"] = failed
	state.narrative.flags["base.story.chaoshengguichu.practice_finished"] = int(state.growth.realm)>=1

static func guidance_available(state: MapLoadoutState) -> bool:
	var saved := story(state)
	return saved.home_reunited and saved.active.is_empty() and topic_done(state,"mirror") and topic_done(state,"past") and not ready_for_practice(state)

static func after_dialogue(state: MapLoadoutState) -> void:
	if not accepted(state): return
	if topic_done(state,"mirror"): state.narrative.flags["base.story.chaoshengguichu.mirror_known"] = true
	if ready_for_practice(state): state.narrative.flags[GUIDED_FLAG] = true
	story(state).updated_at = WorldCalendar.current_day(state.calendar)

static func event(scene: String) -> Dictionary:
	var result: Dictionary = data.scenes[scene].duplicate(true)
	result.merge({"id":PREFIX+scene,"type":"dialogue","speaker_id":"base.map_player.chen_yu",
		"presentation":data.presentation.duplicate(true),"speakers":data.speakers.duplicate(true)})
	result.presentation.dismiss_together = result.get("dismiss_together",false)
	return result

static func reward_record(state: MapLoadoutState) -> Dictionary:
	var reward: Dictionary = data.scenes[story(state).active].reward
	var record: Dictionary = state.records[reward.item_id].duplicate(true)
	record.quantity = reward.quantity
	return record

static func command(state: MapLoadoutState, path: String, action: String, scene := "") -> String:
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var next: MapLoadoutState = prepared.state
	next.storage_capacity_rules = state.storage_capacity_rules.duplicate(true)
	var saved := story(next)
	match action:
		"begin":
			if not data.scenes.has(scene): return "归家对白未配置。"
			if not saved.active.is_empty(): return "" if saved.active==scene else "请先完成当前对白。"
			if next.map_location.is_empty() or interaction(next,next.map_location.map_id,next.map_location.point_id)!=scene: return "当前地点或进度不能开始这段对白。"
			saved.active = scene
			saved.location = next.map_location.duplicate(true)
			if scene=="guidance":
				# Earlier versions played these same lines as an ordinary topic.
				var seen := int(next.narrative.npcs.get(MOTHER,{}).get("seen",{}).get("base.dialogue.mother.cultivation",0))
				saved.line = clampi(seen-1,0,data.scenes.guidance.lines.size()-1)
			if scene not in ["merchant_intro","bridge","intro"]:
				next.quest_tracking.ids = [ID]
				next.quest_tracking.shown = true
		"advance":
			if saved.active.is_empty() or saved.reward_pending: return ""
			var entry: Dictionary = data.scenes[saved.active]
			if entry.has("reward") and saved.line==entry.reward_after_line and not next.has_reward(entry.reward.id):
				saved.reward_pending = true
			elif saved.line+1<data.scenes[saved.active].lines.size():
				saved.line += 1
			else:
				var finished_scene: String = saved.active
				var following := ""
				if saved.active=="merchant_intro":
					MerchantRoadQuest.accept(next)
					if not accepted(next): following="bridge"
				elif saved.active=="bridge":
					following="intro"
				elif saved.active=="intro":
					saved.letter_received = true
					saved.accepted_location = data.shop.map_id
					saved.accepted_at = WorldCalendar.current_day(next.calendar)
					next.narrative.flags[ACCEPTED_FLAG] = true
					next.quest_tracking.ids = [ID]
					next.quest_tracking.shown = true
				elif saved.active=="reunion":
					saved.home_reunited = true
					next.narrative.flags[REUNION_FLAG] = true
				elif saved.active=="guidance":
					saved.guidance_completed = true
					next.narrative.flags[GUIDED_FLAG] = true
				elif saved.active=="preparation":
					next.narrative.flags[PREPARATION_FLAG] = true
				elif saved.active=="rejoice":
					next.narrative.flags[COMPLETED_FLAG] = true
				saved.active = ""
				saved.line = 0
				saved.location = {}
				if not following.is_empty():
					saved.active=following
					saved.location=data.shop.duplicate(true)
				elif finished_scene=="guidance" and preparation_available(next):
					saved.active = "preparation"
					saved.location = data.home.duplicate(true)
		"accept":
			if not saved.reward_pending: return ""
			var error := next.add_reward(data.scenes[saved.active].reward)
			if not error.is_empty(): return error
			# add_reward restores the snapshot, so reacquire the quest dictionary.
			saved = story(next)
			saved.reward_pending = false
			saved.line += 1
		_: return "未知潮声归处指令。"
	story(next).updated_at = WorldCalendar.current_day(next.calendar)
	next.quest_tracking = QuestTracking.normalized(next.quest_tracking,QuestTracking.entries(next))
	var error := MapLoadoutStore.save(next,path)
	if not error.is_empty(): return error
	error = state.restore(next.snapshot())
	if error.is_empty(): preload("res://scripts/entry/save_checkpoints.gd").after_action(state,path,"homecoming_story")
	return error

static func display_entry(state: MapLoadoutState, presentation: Dictionary) -> Dictionary:
	var result := presentation.duplicate(true)
	var saved := story(state)
	result.merge(saved,true)
	result.stage_id = "homeward" if saved.letter_received else "intro"
	if saved.home_reunited:
		result.stage_id = "talks" if topic_done(state,"mirror") else "chat"
		if topic_done(state,"mirror") and topic_done(state,"past"): result.stage_id = "guidance"
		if ready_for_practice(state): result.stage_id = "practice"
		if rejoice_available(state) or saved.active=="rejoice" or completed(state): result.stage_id = "rejoice"
	result.objectives = []
	var seen := {}
	var reached_qi := int(state.growth.get("realm",0))>=1
	var completed_goals := {
		"letter":saved.letter_received,
		"home":saved.home_reunited,
		"mirror":topic_done(state,"mirror") or ready_for_practice(state),
		"past":topic_done(state,"past") or ready_for_practice(state),
		"guidance":ready_for_practice(state),
		"cultivation_full":cultivation_full(state),
		"practice":reached_qi,
		"rejoice":completed(state),
	}
	# Preserve revealed objectives instead of replacing them on each stage change.
	for stage: String in OBJECTIVE_STAGES:
		for source: Dictionary in data.objectives[stage]:
			if seen.has(source.id): continue
			seen[source.id] = true
			var objective := source.duplicate(true)
			objective.completed = completed_goals.get(objective.id,false)
			if objective.id=="cultivation_full" and not state.narrative.flags.get(PREPARATION_FLAG,false):
				objective.targets = [data.objectives.homeward[1].targets[0].duplicate(true)]
			if objective.id=="practice" and not cultivation_full(state): objective.targets = []
			if objective.completed: objective.targets = []
			result.objectives.append(objective)
		if stage==result.stage_id: break
	result.has_locked_next = result.stage_id!="rejoice"
	result.rewards = []
	if ready_for_practice(state):
		for source: Dictionary in data.get("completion_rewards",[]):
			var reward := source.duplicate(true)
			reward.name = state.records[reward.item_id].name
			result.rewards.append(reward)
	result.people = data.people.duplicate(true)
	if saved.letter_received: result.people = [data.mother_person.duplicate(true)]
	result.location = data.locations[result.stage_id].duplicate(true)
	if completed(state): result.stage_id = "completed"
	return result
