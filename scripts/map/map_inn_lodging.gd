class_name MapInnLodging
extends RefCounted

static func configuration_error(config: Variant) -> String:
	if not config is Dictionary or config.get("duration_days")!=1 or not config.get("rooms") is Array or config.rooms.size()!=2: return "住宿配置无效。"
	var ids := {}
	for room: Variant in config.rooms:
		if not room is Dictionary: return "客房配置无效。"
		if not room.get("id") is String or not room.id.begins_with("base.lodging.") or ids.has(room.id): return "客房标识无效。"
		ids[room.id] = true
		for key in ["name","description"]:
			if not room.get(key) is String or room[key].strip_edges().is_empty(): return "客房文案缺失。"
		for key in ["fee","bonus_percent","bonus_days"]:
			if not ContentRegistry._positive_integer(room.get(key)) or room[key]>1000000: return "客房费用或加成无效。"
		if not room.get("image") is String or not ResourceLoader.exists(room.image,"Texture2D"): return "客房图片不存在。"
	return ""

static func valid_bonus(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	if raw.is_empty(): return true
	return raw.size()==4 and raw.get("source_id") is String and raw.source_id.begins_with("base.lodging.") and WorldCalendar.integer_between(raw.get("percent"),1,1000000) and WorldCalendar.integer_between(raw.get("start_day"),0,WorldCalendar.MAX_DAY) and WorldCalendar.integer_between(raw.get("expires_day"),1,WorldCalendar.MAX_DAY) and raw.expires_day>raw.start_day

static func preview(state: MapLoadoutState, config: Dictionary, room_id: String) -> Dictionary:
	var error := configuration_error(config)
	if not error.is_empty(): return {"error":error}
	var room := {}
	for option: Dictionary in config.rooms:
		if option.id==room_id: room = option
	if room.is_empty(): return {"error":"请选择客房。"}
	var start_day := WorldCalendar.current_day(state.calendar)+int(config.duration_days)
	if start_day+int(room.bonus_days)>WorldCalendar.MAX_DAY: error = "日期已超出可用范围。"
	elif state.spirit_stones<int(room.fee): error = "灵石不足，需要%d灵石。" % int(room.fee)
	return {"error":error,"room":room,"start_day":start_day,"expires_day":start_day+int(room.bonus_days)}

static func stay(state: MapLoadoutState, status: MapPlayerStatus, config: Dictionary, room_id: String, path: String) -> Dictionary:
	var quote := preview(state,config,room_id)
	if not quote.error.is_empty(): return quote
	var recovery := status.preview_rest(100,int(config.duration_days),room_id)
	if not recovery.error.is_empty(): return recovery
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return {"error":prepared.error}
	var candidate: MapLoadoutState = prepared.state
	candidate.spirit_stones -= int(quote.room.fee)
	var error := candidate.advance_days(int(config.duration_days),room_id)
	if not error.is_empty(): return {"error":error}
	# One current lodging effect: later stays replace both strength and expiry.
	candidate.lodging_bonus = {"source_id":room_id,"percent":int(quote.room.bonus_percent),"start_day":quote.start_day,"expires_day":quote.expires_day}
	if not candidate.growth.is_empty():
		for key: String in recovery.result.after: candidate.growth.resources[key]=CultivationGrowth.cents(recovery.result.after[key])
	error = MapLoadoutStore.save(candidate,path)
	if not error.is_empty(): return {"error":error}
	error = state.restore(candidate.snapshot())
	if not error.is_empty(): return {"error":error}
	status.apply_rest(recovery.result)
	status.apply_calendar(state.calendar)
	status.cultivation_bonus_percent = state.cultivation_bonus_percent()
	status.changed.emit()
	return quote
