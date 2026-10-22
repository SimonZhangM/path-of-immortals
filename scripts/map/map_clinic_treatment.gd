class_name MapClinicTreatment
extends RefCounted

static func configuration_error(config: Variant) -> String:
	if not config is Dictionary: return "医馆诊治配置无效。"
	if config.has("dialogue_unlock_flag") and not NpcDialogueActions.valid_dialogue_fact(config.dialogue_unlock_flag): return "诊治对话解锁标记无效。"
	if not ContentRegistry._positive_integer(config.get("consultation_hp_per_stone")): return "问诊费的每灵石气血量必须为正整数。"
	if not ContentRegistry._nonnegative_integer(config.get("supplies_fee")): return "药材及耗材费必须为非负整数。"
	if not config.get("waive_consultation") is bool: return "问诊费免收配置无效。"
	if config.waive_consultation:
		for key in ["care_label","care_tooltip"]:
			if not config.get(key) is String or config[key].strip_edges().is_empty(): return "问诊照顾说明缺失："+key
	if config.get("resource")!="hp" or config.get("recovery_percent")!=100 or config.get("duration_days")!=0:
		return "诊治仅恢复全部气血且不消耗时间。"
	for key in ["tagline","payment_note","recovery_note","description","motto"]:
		if not config.get(key) is String or config[key].strip_edges().is_empty(): return "医馆诊治文案缺失："+key
	return ""

static func preview(state: MapLoadoutState, status: MapPlayerStatus, config: Dictionary) -> Dictionary:
	var error := configuration_error(config)
	if not error.is_empty(): return {"error":error}
	var maximum := float(status.maxima.get("hp",0))
	var current := clampf(float(status.resources.get("hp",0)),0.0,maximum)
	var gain := maximum-current
	var consultation_fee := ceili(gain / float(config.consultation_hp_per_stone))
	var waived_fee := consultation_fee if config.waive_consultation else 0
	var supplies_fee := int(config.supplies_fee)
	var fee := consultation_fee - waived_fee + supplies_fee
	if gain<=0: error = "气血已满，无需诊治。"
	elif state.spirit_stones<fee: error = "灵石不足，诊治需要%d灵石。" % fee
	return {"error":error,"current":current,"maximum":maximum,"after":maximum,"gain":gain,"fee":fee,"consultation_fee":consultation_fee,"waived_fee":waived_fee,"supplies_fee":supplies_fee}

static func treat(state: MapLoadoutState, status: MapPlayerStatus, config: Dictionary, path: String, library: NpcDialogueLibrary = null) -> Dictionary:
	var result := preview(state,status,config)
	if not result.error.is_empty(): return result
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return {"error":prepared.error}
	var candidate: MapLoadoutState = prepared.state
	if library!=null and candidate.narrative.npcs.has(library.definition.id):
		var migration_error := library.upgrade_journal(candidate.narrative.npcs[library.definition.id],WorldCalendar.current_day(candidate.calendar),int(candidate.narrative.story_revision))
		if not migration_error.is_empty(): return {"error":migration_error}
		var journal_error := library.journal_error(candidate.narrative.npcs[library.definition.id])
		if not journal_error.is_empty(): return {"error":journal_error}
	DialogueGreetings.queue_treatment(candidate.narrative,library)
	if config.has("dialogue_unlock_flag"):
		candidate.narrative.flags[config.dialogue_unlock_flag] = true
	candidate.spirit_stones -= int(result.fee)
	if not candidate.growth.is_empty(): candidate.growth.resources.hp=CultivationGrowth.cents(float(result.after))
	var error := MapLoadoutStore.save(candidate,path)
	if not error.is_empty(): return {"error":error}
	error = state.restore(candidate.snapshot())
	if not error.is_empty(): return {"error":error}
	# Follow the existing map resource lifecycle: publish recovery only after
	# currency is safely saved, without touching stamina, spirit or calendar.
	status.set_resource("hp",float(result.after))
	return result
