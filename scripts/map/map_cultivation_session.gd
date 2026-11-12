class_name MapCultivationSession
extends RefCounted

# Commands own simulation time and atomically commit resources, growth, books and calendar.
signal changed
signal presentation_events(events: Array[Dictionary])
var event: Dictionary = {}
var mode_id := ""
var mode_name := ""
var duration_days := 0
var elapsed_days := 0
var last_calendar_day := 0
var paused := true
var started := false
var active := false
var suspensions: Dictionary = {}
var cultivation_progress: Dictionary = {}
var techniques: Array[Dictionary] = []
var selected_technique_id := ""
var selected_ids: Array[String] = []
var pending_ids: Array[String] = []
var gains: Dictionary = {}
var cultivation_gain := 0
var error := ""
var speed := 1.0
var site: Dictionary = {}
var loadout: MapLoadoutState
var player: MapPlayerStatus
var save_path := ""
var simulation: CultivationTraining
var _tick := 0.0
var _selection_pending := false
var waiting_for_books := false

var _completion_saved := false
## Optional transactional settlement, used by the first breakthrough run.
## Mutates only the candidate; an error rejects the entire step.
var before_step_save: Callable
var award_cultivation: Callable
## Ordinary cultivation shares a daily allowance; breakthrough training does not.
var enforce_daily_cap := true
## Breakthrough converts exact paid stamina + spirit one-for-one, without site/bonus factors.
var direct_resource_cultivation := false
## Simulation seconds per calendar day. Ordinary cultivation retains 60.
var calendar_day_seconds := 60.0

func seconds_until_day_end() -> float:
	return (60000000-int(loadout.growth.day_usec))/1000000.0*calendar_day_seconds/60.0

func begin(definition: Dictionary, mode: String, days: int, today: int) -> bool:
	var matching: Array = definition.get("modes",[]).filter(func(entry): return entry.id==mode)
	if matching.is_empty() or not definition.get("durations",[]).any(func(value): return int(value)==days): return false
	event=definition.duplicate(true)
	mode_id=mode
	mode_name=matching[0].name
	duration_days=days
	elapsed_days=0
	last_calendar_day=today
	paused=true
	started=false
	active=true
	_completion_saved=false
	suspensions.clear()
	cultivation_progress.clear()
	techniques.clear()
	selected_technique_id=""
	changed.emit()
	return true

func sync_calendar(today: int) -> void:
	if loadout != null: return
	if not active or today<=last_calendar_day: return
	var passed:=today-last_calendar_day
	last_calendar_day=today
	if not paused and suspensions.is_empty(): elapsed_days=mini(duration_days,elapsed_days+passed)
	changed.emit()

func set_paused(value: bool, today: int) -> void:
	sync_calendar(today)
	if value: advance(0.0,true)
	if not value and waiting_for_books:
		error="请先选择要修炼的功法，再点击开始修炼。"
		changed.emit()
		return
	paused=value
	if not paused: started=true
	if loadout != null and not paused:
		error=""
		_sync_board()
	changed.emit()

func suspend(reason: String, value: bool, today: int) -> void:
	sync_calendar(today)
	if value: advance(0.0,true)
	if value: suspensions[reason]=true
	else: suspensions.erase(reason)
	if loadout != null and not value: _sync_board()
	changed.emit()

func finish(today: int) -> void:
	sync_calendar(today)
	if loadout != null: advance(0.0, true)
	_save_completion()
	active=false
	suspensions.clear()
	changed.emit()

func _save_completion() -> void:
	if loadout==null or not started or _completion_saved or not error.is_empty(): return
	preload("res://scripts/entry/save_checkpoints.gd").after_action(loadout,save_path,"cultivation_complete")
	_completion_saved = true

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
	if loadout != null and id not in selected_ids: select_books([id])
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
	if not error.is_empty(): return error
	if kind=="cultivation" and mode_id=="technique": return "本次专注功法，未安排修为修炼。"
	if kind=="technique":
		if mode_id=="cultivation": return "本次专注修为，未安排功法修习。"
		if selected_technique_id.is_empty(): return "尚未选择功法，可点击左侧加号选择。"
	if not started: return "准备就绪后，点击开始修炼。"
	if paused or not suspensions.is_empty(): return "修炼已暂停，当前进度保留。"
	if elapsed_days>=duration_days: return "本次修炼时段已满，可结束修炼。"
	if loadout!=null:
		if kind=="cultivation" and int(loadout.growth.progress)>=CultivationGrowth.target(loadout.growth):
			return "人界修为已圆满。" if int(loadout.growth.realm)==5 else "修为已满，可准备境界突破。"
		if not loadout.inventory.get_instances().any(func(entry):
			var item:=loadout.registry.get_item(entry.item_id)
			return item.training or item.category in ["weapon","spell"]
		): return "请将导引石或实练器具放入阵盘。"
		if kind=="technique" and not selected_technique().get("practice_error","").is_empty(): return selected_technique().practice_error
	if kind == "technique" and float(selected_technique().get("progress_target", 0)) <= 0:
		return "当前修炼度：%s；修炼收益与升级所需修炼度待定。" % EffectSystem.number_text(float(selected_technique().get("progress_current", 0)))
	var options: Array=event.stage_two.get(kind+"_statuses",[])
	if options.is_empty(): return ""
	return str(options[(elapsed_days/int(event.stage_two.status_interval_days))%options.size()])

func bind(state: MapLoadoutState, status: MapPlayerStatus, path: String) -> bool:
	loadout = state
	player = status
	save_path = path
	site = CultivationGrowth.rules().sites.get(event.id,{}).duplicate(true)
	if site.is_empty(): error="此修炼点尚未配置收益。"; return false
	refresh_records()
	_sync_board()
	waiting_for_books=mode_id!="cultivation"
	if waiting_for_books: paused=true
	return simulation != null and error.is_empty()

func refresh_records() -> void:
	if loadout == null: return
	techniques.clear()
	for record: Dictionary in loadout.storage_records():
		if record.category != "book" or record.get("reading_only",false): continue
		record.practice_error = CultivationGrowth.book_error(loadout.growth,loadout.registry.library,loadout.knowledge,record.id)
		techniques.append(record)
	set_cultivation_progress(player.cultivation_progress,player.cultivation_required,"当前修为 %s" % CultivationGrowth.display(player.cultivation_progress))

func select_books(ids: Array) -> bool:
	if ids.size()>int(site.get("slots",1)): return false
	var unique: Array[String] = []
	for id: String in ids:
		if id in unique or not techniques.any(func(record): return record.id==id and record.get("practice_error","").is_empty()): return false
		unique.append(id)
	# No backdated gains: when a day is underway, new choices start next day.
	if int(loadout.growth.day_usec)>0:
		pending_ids=unique
		_selection_pending=true
	else: selected_ids=unique
	if not unique.is_empty(): selected_technique_id=unique[0]
	if waiting_for_books and not unique.is_empty():
		waiting_for_books=false
		error=""
	changed.emit()
	return true

func view_next_book() -> void:
	var ids := pending_ids if _selection_pending else selected_ids
	if ids.is_empty(): return
	selected_technique_id=ids[(ids.find(selected_technique_id)+1)%ids.size()]
	changed.emit()

func displayed_gain() -> float:
	return int(gains.get(selected_technique_id,0))/100.0

func _sync_board() -> void:
	if loadout == null: return
	if simulation == null:
		var member := PartyMemberState.new(player.battle_snapshot().character,loadout.registry)
		var copy := MapLoadoutStore.candidate(loadout)
		if not copy.error.is_empty(): error=copy.error; return
		member.inventory=copy.state.inventory
		member.knowledge=loadout.knowledge
		member.test_spell_access=loadout.content_grants.get(MapLoadoutState.TEST_SPELL_GRANT,false)
		member.board=loadout.board
		for key: String in player.resources: member.set(key,player.resources[key])
		simulation=CultivationTraining.new(member,loadout.registry)
		simulation.use_actual_resource_payments=direct_resource_cultivation
		for id: String in simulation.timeline.timers:
			if simulation._definitions[id].combat.get("prepared",false): simulation.timeline.set_enabled(id,false)
		if not simulation.start(): error=simulation.configuration_error; simulation=null
	else:
		var member: PartyMemberState=simulation.state.teams[0][0]
		var new_ids := {}
		for entry: Dictionary in loadout.inventory.get_instances(): new_ids[entry.instance_id]=entry
		for id: String in simulation._definitions.keys():
			if not new_ids.has(id): simulation.detach(id)
		var copy := MapLoadoutStore.candidate(loadout)
		if not copy.error.is_empty(): error=copy.error; return
		member.inventory=copy.state.inventory
		member.board=loadout.board
		member.knowledge=loadout.knowledge
		for key: String in player.resources: member.set(key,player.resources[key])
		for key: String in player.maxima: member.definition["max_"+key]=player.character_definition["max_"+key]
		for id: String in new_ids:
			if not simulation._definitions.has(id): simulation.attach(member,0,id,true)
		for id: String in simulation.timeline.timers:
			if simulation._definitions.has(id) and simulation._definitions[id].combat.get("prepared",false): simulation.timeline.set_enabled(id,false)
	refresh_records()

func advance(delta: float, flush := false) -> void:
	if loadout==null or not active or paused or not suspensions.is_empty() or elapsed_days>=duration_days: return
	if simulation==null: return
	_tick += maxf(0,delta)*speed
	if not flush and _tick<1.0: return
	var remaining := _tick
	_tick=0.0
	while remaining>0.000001 and not paused and elapsed_days<duration_days:
		var duration := minf(minf(remaining,1.0),seconds_until_day_end())
		if not _advance_chunk(duration): return
		remaining -= duration
	if elapsed_days>=duration_days: _save_completion()
	changed.emit()

func daily_cap() -> int:
	var realm := mini(int(loadout.growth.realm),int(site.realm))
	var scale := pow(3.0,maxi(0,realm-1))
	return CultivationGrowth.cents(minf(float(site.cap)*scale,6.0 if int(loadout.growth.realm)==0 else INF))

func _advance_chunk(seconds: float) -> bool:
	error=""
	var prepared := MapLoadoutStore.candidate(loadout)
	if not prepared.error.is_empty(): error=prepared.error; paused=true; return false
	var next: MapLoadoutState=prepared.state
	var growth := next.growth
	var realm := mini(int(growth.realm),int(site.realm))
	var scale := pow(3.0,maxi(0,realm-1))
	# Legacy paid-day markers no longer grant a bonus or create a charge.
	growth.day_paid=false
	var cap := daily_cap()
	var mode: Array=CultivationGrowth.rules().modes[mode_id]
	var simulation_started_usec: int=simulation.state.time_usec
	simulation.advance(seconds)
	if not simulation.configuration_error.is_empty(): error=simulation.configuration_error; paused=true; return false
	var events := simulation.drain_events()
	var member: PartyMemberState=simulation.state.teams[0][0]
	for key: String in player.resources: growth.resources[key]=CultivationGrowth.cents(float(member.get(key)))
	var gained := 0
	var books_gained := {}
	for payment: Dictionary in simulation.take_payments():
		var raw := scale*(float(site.stamina)*float(payment.stamina)+float(site.spirit)*float(payment.spirit))
		var available := CultivationGrowth.cents(raw)
		if enforce_daily_cap:
			available = mini(maxi(0,cap-int(growth.budget)),available)
			growth.budget=int(growth.budget)+available
		var value := CultivationGrowth.cents(available/100.0*float(mode[0])*(1.0+next.cultivation_bonus_percent()/100.0))
		if direct_resource_cultivation:
			value=CultivationGrowth.cents(float(payment.stamina)+float(payment.spirit))
		var payment_offset := int(payment.at)-simulation_started_usec
		var credited := int(award_cultivation.call(next,value,payment_offset)) if award_cultivation.is_valid() else CultivationGrowth.award(growth,value)
		gained += credited
		if credited>0:
			events.append({"kind":"cultivation_gained","value":credited/100.0,"at_usec":payment.at,
				"instance_id":payment.instance_id,"item_id":payment.item_id,"owner_id":payment.owner_id,"target_id":payment.owner_id})
		for id: String in selected_ids:
			var book: Dictionary=next.registry.library.books[id]
			if payment.element!="all" and payment.element!=book.element: continue
			if not next.storage_records().any(func(record): return record.id==id): continue
			var book_value := CultivationGrowth.cents(available/100.0*float(mode[1]))
			books_gained[id]=int(books_gained.get(id,0))+CultivationGrowth.award_book(growth,next.registry.library,next.knowledge,id,book_value)
	var owned: Dictionary=next.snapshot().owned_units
	for id: String in next.knowledge.learned_spells(next.registry.library):
		if id not in owned.values(): next.storage.put(next._unit("learned."+id,id))
	# The shared calendar stores a fraction of a 60-second ordinary day.
	# Scale only calendar time; item CD and status timers keep simulation seconds.
	growth.day_usec=int(growth.day_usec)+roundi(seconds*1000000*60.0/calendar_day_seconds)
	var completed := int(growth.day_usec)>=60000000
	if completed:
		growth.day_usec=0; growth.budget=0; growth.day_paid=false
		error=next.advance_days(1,event.id)
	if error.is_empty() and before_step_save.is_valid(): error=before_step_save.call(next,seconds)
	if error.is_empty(): error=MapLoadoutStore.save(next,save_path)
	if not error.is_empty():
		paused=true
		simulation=null # discard uncommitted simulation work; resume from durable resources
		return false
	error=loadout.restore(next.snapshot())
	if not error.is_empty(): paused=true; simulation=null; return false
	player.apply_growth(loadout.growth)
	cultivation_gain+=gained
	for id: String in books_gained: gains[id]=int(gains.get(id,0))+int(books_gained[id])
	if completed:
		elapsed_days+=1
		if _selection_pending:
			selected_ids=pending_ids.duplicate(); pending_ids.clear(); _selection_pending=false
	for key: String in player.resources: member.set(key,player.resources[key])
	for key: String in player.maxima: member.definition["max_"+key]=player.character_definition["max_"+key]
	member.cultivation_rank_id=player.cultivation_rank_id
	member.knowledge=loadout.knowledge
	refresh_records()
	# Presentation follows a successful commit; failed saves must remain silent.
	presentation_events.emit(events)
	return true

func breakthrough_preview() -> String:
	var g := loadout.growth
	var rule: Dictionary=CultivationGrowth.rules().realms[int(g.realm)]
	return "成功率%d%%，耗时%d天。\n%s" % [roundi(CultivationGrowth.breakthrough_chance(g)*100),int(rule.days),"引气必成。" if int(g.realm)==0 else "失败扣除20%突破准备修为。"]

func breakthrough() -> bool:
	if loadout==null: return false
	# An active panel attempt has its own deadline and atomic settlement.
	if loadout.growth.has("breakthrough_attempt"): return false
	advance(0.0,true)
	var prepared := MapLoadoutStore.candidate(loadout)
	if not prepared.error.is_empty(): error=prepared.error; changed.emit(); return false
	var next: MapLoadoutState=prepared.state
	var g := next.growth
	var needed := CultivationGrowth.target(g)
	if needed<=0 or int(g.progress)<needed or (int(g.realm)>0 and int(g.layer)<10): return false
	var rule: Dictionary=CultivationGrowth.rules().realms[int(g.realm)]
	var rng := RandomNumberGenerator.new()
	rng.seed=1792390426+int(g.breakthrough_serial)
	var success := rng.randf()<CultivationGrowth.breakthrough_chance(g)
	g.breakthrough_serial=int(g.breakthrough_serial)+1
	if success:
		var before := CultivationGrowth.maxima(g)
		g.realm=int(g.realm)+1; g.layer=1; g.progress=0
		var after := CultivationGrowth.maxima(g)
		for key: String in g.resources: g.resources[key]=int(g.resources[key])+(int(after[key])-int(before[key]))*100
	else: g.progress=needed-CultivationGrowth.cents(needed/100.0*0.2)
	next.cultivation_rank_id=CultivationGrowth.rank_id(g)
	error=next.advance_days(int(rule.days),event.id)
	if error.is_empty(): error=MapLoadoutStore.save(next,save_path)
	if not error.is_empty(): changed.emit(); return false
	loadout.restore(next.snapshot())
	player.apply_growth(loadout.growth)
	paused=true
	preload("res://scripts/entry/save_checkpoints.gd").after_action(loadout,save_path,"breakthrough_complete")
	_completion_saved = true
	error="突破成功，已晋入"+player.rank_name if success else "突破未成，需补足准备修为。"
	# A breakthrough ends the old training context; no old cooldown earns again.
	simulation=null
	refresh_records(); changed.emit()
	return success
