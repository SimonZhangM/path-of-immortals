extends RefCounted
## Only registered save slots and the explicit legacy save; never scan test files.
const Files = preload("res://scripts/entry/save_file.gd")
const Session = preload("res://scripts/entry/game_save_session.gd")
var index_path := "user://save_slots.json"
var legacy_path := "user://inventory_loadout.json"
var last_path := ""
var manual_directory := "user://"
var error := ""

func quick_path() -> String:
	return legacy_path.get_base_dir().path_join("quick_save.json") if not legacy_path.is_empty() else ""

func is_system(path: String) -> bool:
	return path==legacy_path or path==quick_path()

func paths() -> Array[String]:
	var result: Array[String] = []
	# Reserve 01/02 even before the first quick/timed checkpoint exists.
	if not legacy_path.is_empty(): result.append_array([quick_path(),legacy_path])
	var source := index_path if FileAccess.file_exists(index_path) else index_path+".bak"
	var raw := Files.read(source)
	if FileAccess.file_exists(source) and (raw.get("version") != 1 or not raw.get("paths") is Array):
		error = "存档列表索引无法读取，已保留原文件。"
	else:
		for path: Variant in raw.get("paths",[]):
			if path is String and not path.is_empty() and path != Session.PREVIEW_PATH and not path.ends_with("live_session.json") and not path.ends_with(".bak") and path not in result:
				result.append(path)
	if not last_path.is_empty() and last_path != Session.PREVIEW_PATH and not last_path.ends_with("live_session.json") and last_path not in result: result.append(last_path)
	return result

func register(path: String) -> Error:
	if not Session.has_save(path): return ERR_INVALID_DATA
	var registered := paths()
	if not error.is_empty(): return ERR_FILE_CORRUPT
	if path not in registered: registered.append(path)
	return Files.write(index_path,{"version":1,"paths":registered})

func entries(include_empty_system := false) -> Array[Dictionary]:
	error = ""
	var result: Array[Dictionary] = []
	var registered := paths()
	for index in registered.size():
		var path := registered[index]
		if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"):
			if not include_empty_system or not is_system(path): continue
		result.append(describe(path,index+1))
	return result

func next_manual_slot() -> Dictionary:
	var registered := paths()
	for index in registered.size():
		var path := registered[index]
		if not is_system(path) and not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"):
			return {"path":path,"slot":index+1}
	var slot := maxi(3,registered.size()+1)
	var path := manual_directory.path_join("manual_save_%02d.json" % slot)
	while FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak") or path in registered:
		slot += 1
		path = manual_directory.path_join("manual_save_%02d.json" % slot)
	return {"path":path,"slot":registered.size()+1 if not registered.is_empty() else 3}

func describe(path: String, slot: int) -> Dictionary:
	var source := path if FileAccess.file_exists(path) else path+".bak"
	var raw := Files.read(source)
	var row := {"slot":slot,"path":path,"readable":Session.has_save(path),"chapter":"序章 山外有仙",
		"save_kind":"quick" if path==quick_path() else ("auto" if path==legacy_path else "manual"),
		"calendar":"时间未记录","location":"地点未记录","picture":"","name":"未记录","rank":"未记录",
		"duration":"未记录","saved_at":"未记录","duration_note":"旧档尚未记录游戏时长，无法还原此前累计时长。"}
	if is_system(path) and not FileAccess.file_exists(source):
		row.empty_system_slot = true
		row.chapter = "尚无快速存档" if path==quick_path() else "尚无自动存档"
		row.calendar = "动作完成或战斗前生成" if path==quick_path() else "到达自动保存时间后生成"
		row.location = ""
		row.saved_at = ""
		row.duration = ""
		row.duration_note = "开启对应保存选项后，在指定时机生成；不能手动覆盖系统档位。"
		return row
	if not row.readable:
		row.chapter = "存档无法读取"
		return row
	var info: Dictionary = raw.get("save_info",{}) if raw.get("save_info",{}) is Dictionary else {}
	var config: Dictionary = Files.read("res://data/ui/save_browser.json")
	var chapter: Dictionary = config.chapters.get(str(info.get("chapter_id","prologue")),{})
	if not chapter.is_empty(): row.chapter = str(chapter.label).strip_edges()+" "+str(chapter.title).strip_edges()
	else: row.chapter = "章节未记录"
	var world: Dictionary = Files.read("res://data/world/world_map_locations.json")
	var map_location: Dictionary = raw.get("map_location",{}) if raw.get("map_location",{}) is Dictionary else {}
	for location: Dictionary in world.locations.values():
		if not str(location.map_id).is_empty() and location.map_id == map_location.get("map_id",""):
			row.location = location.name
			row.picture = location.picture
			break
	var narrative: Dictionary = raw.get("narrative",{}) if raw.get("narrative",{}) is Dictionary else {}
	if DialogueJournal.valid_name(narrative.get("identity")): row.name = DialogueJournal.full_name(narrative)
	var growth: Dictionary = raw.get("growth",{}) if raw.get("growth",{}) is Dictionary else {}
	if not growth.is_empty() and CultivationGrowth.valid(growth):
		row.rank = ["凡人","炼气","筑基","结丹","元婴","化神"][int(growth.realm)]
		if int(growth.realm)>0: row.rank += WorldCalendar.chinese_number(int(growth.layer))+"层"
	var calendar: Variant = raw.get("calendar")
	if WorldCalendar.valid_record(calendar):
		var parts := WorldCalendar.date_parts(calendar)
		row.calendar = str(WorldCalendar.rules().year_names[parts.year_index])+"年·"+["春","夏","秋","冬"][int((parts.month-1)/3)]
		row.calendar_full = WorldCalendar.date_text(calendar,true)
	if info.get("playtime_ms") is int or info.get("playtime_ms") is float:
		row.duration = duration_text(maxi(0,int(info.playtime_ms)))
		if not bool(info.get("playtime_complete",false)):
			row.duration_note = "仅统计接入时长记录之后的游玩；此前时长未记录。"
		else: row.duration_note = "实际进入角色后的累计在线时长，不计离线、开始菜单及加载等待。"
	var timestamp := int(info.get("saved_at_unix",FileAccess.get_modified_time(source)))
	var bias := int(info.get("timezone_bias",Time.get_time_zone_from_system().bias))
	row.saved_at = timestamp_text(timestamp,bias)
	return row

static func duration_text(milliseconds: int) -> String:
	var seconds := int(milliseconds/1000)
	return "%02d:%02d:%02d" % [int(seconds/3600),int(seconds/60)%60,seconds%60]

static func timestamp_text(timestamp: int, timezone_bias: int) -> String:
	if timestamp <= 0: return "未记录"
	var parts := Time.get_datetime_dict_from_unix_time(timestamp+timezone_bias*60)
	return "%04d/%02d/%02d %02d:%02d" % [parts.year,parts.month,parts.day,parts.hour,parts.minute]
