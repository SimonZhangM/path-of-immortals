class_name MapCultivationSession
extends RefCounted

# Read calendar days from game state; this session never advances time or awards
# cultivation itself. The future progression system supplies numeric progress.
signal changed
var event: Dictionary = {}
var mode_id := ""
var mode_name := ""
var duration_days := 0
var elapsed_days := 0
var last_calendar_day := 0
var paused := false
var active := false
var suspensions: Dictionary = {}
var cultivation_progress: Dictionary = {}
var techniques: Array[Dictionary] = []
var selected_technique_id := ""

func begin(definition: Dictionary, mode: String, days: int, today: int) -> bool:
	var matching: Array = definition.get("modes",[]).filter(func(entry): return entry.id==mode)
	if matching.is_empty() or not definition.get("durations",[]).any(func(value): return int(value)==days): return false
	event=definition.duplicate(true)
	mode_id=mode
	mode_name=matching[0].name
	duration_days=days
	elapsed_days=0
	last_calendar_day=today
	paused=false
	active=true
	suspensions.clear()
	cultivation_progress.clear()
	techniques.clear()
	selected_technique_id=""
	changed.emit()
	return true

func sync_calendar(today: int) -> void:
	if not active or today<=last_calendar_day: return
	var passed:=today-last_calendar_day
	last_calendar_day=today
	if not paused and suspensions.is_empty(): elapsed_days=mini(duration_days,elapsed_days+passed)
	changed.emit()

func set_paused(value: bool, today: int) -> void:
	sync_calendar(today)
	paused=value
	changed.emit()

func suspend(reason: String, value: bool, today: int) -> void:
	sync_calendar(today)
	if value: suspensions[reason]=true
	else: suspensions.erase(reason)
	changed.emit()

func finish(today: int) -> void:
	sync_calendar(today)
	active=false
	suspensions.clear()
	changed.emit()

func set_cultivation_progress(current: float, target: float, caption: String) -> void:
	cultivation_progress=_progress(current,target,caption)
	changed.emit()

static func _progress(current: float, target: float, caption: String) -> Dictionary:
	if not is_finite(current) or not is_finite(target) or current<0 or target<=0: return {}
	return {"current":current,"target":target,"caption":caption,"ratio":clampf(current/target,0.0,1.0)}

func set_available_techniques(records: Array[Dictionary]) -> void:
	techniques=records.duplicate(true)
	if selected_technique().is_empty(): selected_technique_id=""
	changed.emit()

func choose_technique(id: String) -> bool:
	if not techniques.any(func(record): return record.get("id","")==id): return false
	selected_technique_id=id
	changed.emit()
	return true

func selected_technique() -> Dictionary:
	for record in techniques:
		if record.get("id","")==selected_technique_id: return record.duplicate(true)
	return {}

func technique_progress() -> Dictionary:
	var record:=selected_technique()
	return _progress(float(record.get("progress_current",-1)),float(record.get("progress_target",0)),str(record.get("name","")))

func status(kind: String) -> String:
	if kind=="cultivation" and mode_id=="technique": return "本次专注功法，未安排修为修炼。"
	if kind=="technique":
		if mode_id=="cultivation": return "本次专注修为，未安排功法修习。"
		if selected_technique_id.is_empty(): return "尚未选择功法，可点击左侧加号选择。"
	if paused or not suspensions.is_empty(): return "修炼已暂停，当前进度保留。"
	if elapsed_days>=duration_days: return "本次修炼时段已满，可结束修炼。"
	var options: Array=event.stage_two.get(kind+"_statuses",[])
	if options.is_empty(): return ""
	return str(options[(elapsed_days/int(event.stage_two.status_interval_days))%options.size()])
