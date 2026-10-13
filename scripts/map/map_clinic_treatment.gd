class_name MapClinicTreatment
extends RefCounted

static func configuration_error(config: Variant) -> String:
	if not config is Dictionary: return "医馆诊治配置无效。"
	if not ContentRegistry._positive_integer(config.get("fee")): return "诊金必须为正整数。"
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
	var fee := int(config.fee)
	if gain<=0: error = "气血已满，无需诊治。"
	elif state.spirit_stones<fee: error = "灵石不足，诊治需要%d灵石。" % fee
	return {"error":error,"current":current,"maximum":maximum,"after":maximum,"gain":gain,"fee":fee}

static func treat(state: MapLoadoutState, status: MapPlayerStatus, config: Dictionary, path: String) -> Dictionary:
	var result := preview(state,status,config)
	if not result.error.is_empty(): return result
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return {"error":prepared.error}
	var candidate: MapLoadoutState = prepared.state
	candidate.spirit_stones -= int(result.fee)
	var error := MapLoadoutStore.save(candidate,path)
	if not error.is_empty(): return {"error":error}
	error = state.restore(candidate.snapshot())
	if not error.is_empty(): return {"error":error}
	# Follow the existing map resource lifecycle: publish recovery only after
	# currency is safely saved, without touching stamina, spirit or calendar.
	status.set_resource("hp",float(result.after))
	return result
