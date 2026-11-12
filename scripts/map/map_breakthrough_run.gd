extends RefCounted
## Owns the first-qi attempt. The view never calculates cultivation or calendar time.
signal changed
signal presentation_events(events: Array[Dictionary])
const FIRST_QI_FLAG := "base.story.chaoshengguichu.qi_confirmed"
const RULES_PATH := "res://data/breakthrough_rules.json"
const SETTLEMENT_STEP_SECONDS := 0.5
var rule: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH)).first_qi
var loadout: MapLoadoutState
var player: MapPlayerStatus
var save_path := ""
var training: MapCultivationSession
var phase := "ready"
var error := ""
var _pending := 0.0

func bind(state: MapLoadoutState, status: MapPlayerStatus, path: String) -> void:
	loadout=state; player=status; save_path=path
	var saved: Dictionary=loadout.growth.get("breakthrough_attempt",{}) if loadout!=null else {}
	phase=str(saved.get("phase","ready"))
	if phase=="running": phase="paused" # No offline progress or automatic resume.
	changed.emit()

func target() -> int:
	var saved: Dictionary=loadout.growth.get("breakthrough_attempt",{})
	# Already successful legacy attempts retain their historical target.
	if saved.get("version",2)==1 and saved.get("phase","")=="succeeded": return 10000
	return CultivationGrowth.cents(float(rule.target))

func day_usec() -> int:
	var saved: Dictionary=loadout.growth.get("breakthrough_attempt",{}) if loadout!=null else {}
	if saved.get("version",2)==1: return 60000000
	return int(rule.day_seconds)*1000000

func limit_usec() -> int:
	return int(rule.max_days)*day_usec()

func elapsed_usec() -> int:
	return int(loadout.growth.get("breakthrough_attempt",{}).get("elapsed_usec",0))

func presentation_usec() -> int:
	return mini(limit_usec(),elapsed_usec()+roundi(_pending*1000000.0))

func progress() -> int:
	if phase=="succeeded": return target()
	return int(loadout.growth.get("breakthrough_attempt",{}).get("progress",0))

func success_chance() -> float:
	var saved: Dictionary=loadout.growth.get("breakthrough_attempt",{}).get("result",{})
	if not saved.is_empty(): return float(saved.chance)
	# The first-qi source realm stays mortal after the promotion has committed.
	return CultivationGrowth.breakthrough_chance({"realm":int(rule.realm)})

func result_snapshot() -> Dictionary:
	if phase not in ["succeeded","failed"]: return {}
	var saved: Dictionary=loadout.growth.get("breakthrough_attempt",{}).get("result",{})
	if not saved.is_empty(): return saved.duplicate(true)
	# Old failed saves discarded their earned points. Do not invent that history.
	var before := CultivationGrowth.maxima(CultivationGrowth.initial(int(rule.realm)))
	var after := CultivationGrowth.maxima(CultivationGrowth.initial(int(rule.realm)+1))
	var gains := {"hp":0,"spirit":0,"stamina":0,"cultivation_efficiency_percent":0}
	if phase=="succeeded":
		for key: String in CultivationGrowth.RESOURCE_KEYS: gains[key]=int(after[key])-int(before[key])
	return {"progress":target() if phase=="succeeded" else -1,"target":target(),
		"chance":success_chance(),"gains":gains}

func remaining_days() -> int:
	return maxi(0,int(rule.max_days)-floori(float(elapsed_usec())/day_usec()))

func recent_gain() -> int:
	var gained := 0
	var cutoff := elapsed_usec()-day_usec()
	for entry: Dictionary in loadout.growth.get("breakthrough_attempt",{}).get("recent_gains",[]):
		if int(entry.at_usec)>cutoff and int(entry.at_usec)<=elapsed_usec(): gained+=int(entry.amount)
	return gained

func eligibility_error() -> String:
	if int(loadout.growth.realm)!=int(rule.realm):
		var realm_name: String = loadout.registry.get_cultivation(loadout.cultivation_rank_id).name
		return "当前为%s%s层。此处仅开放凡人→炼气的首次突破。" % [realm_name,WorldCalendar.chinese_number(int(loadout.growth.layer))]
	if not HomecomingQuest.ready_for_practice(loadout): return "请先完成母亲的修行指导。"
	if not HomecomingQuest.cultivation_full(loadout): return "请先积累修为至100%，再回母亲家尝试突破。"
	if loadout.map_location!={"map_id":rule.map_id,"point_id":rule.point_id}: return "请回母亲家进行首次引气。"
	if loadout.board.id=="base.board.bag": return "基础行囊无法用于突破，请至少装备晓岚阵盘。"
	return ""

func _make_training() -> bool:
	training=MapCultivationSession.new()
	training.enforce_daily_cap=false
	training.direct_resource_cultivation=true
	training.calendar_day_seconds=float(rule.day_seconds)
	training.presentation_events.connect(presentation_events.emit)
	training.begin({"id":rule.training_site_id,"durations":[int(rule.max_days)],
		"modes":[{"id":"cultivation","name":"首次引气"}]},"cultivation",int(rule.max_days),WorldCalendar.current_day(loadout.calendar))
	if not training.bind(loadout,player,save_path):
		error=training.error; training=null; return false
	# Shared resource simulation; breakthrough owns its one-for-one conversion and history.
	training.event.id=rule.id
	var owner: WeakRef = weakref(self)
	training.before_step_save=func(next: MapLoadoutState, seconds: float) -> String:
		var run = owner.get_ref()
		return "突破会话已关闭。" if run==null else run._settle_step(next,seconds)
	training.award_cultivation=func(next: MapLoadoutState, amount: int, offset_usec: int) -> int:
		var run = owner.get_ref()
		return 0 if run==null else run._award(next,amount,offset_usec)
	return true

func start() -> bool:
	if phase!="ready": return false
	error=eligibility_error()
	if not error.is_empty(): changed.emit(); return false
	if not _make_training(): changed.emit(); return false
	var prepared := MapLoadoutStore.candidate(loadout)
	if not prepared.error.is_empty(): return _fail(prepared.error)
	var next: MapLoadoutState=prepared.state
	next.growth.breakthrough_attempt={"version":2,"id":rule.id,"phase":"running","elapsed_usec":0,"progress":0,"recent_gains":[]}
	next.narrative.flags[HomecomingQuest.PRACTICE_STARTED_FLAG]=true
	next.narrative.flags[HomecomingQuest.BREAKTHROUGH_FAILED_FLAG]=false
	if not _commit(next): return false
	_pending=0.0
	phase="running"
	training.paused=false; training.started=true
	changed.emit()
	return true

func set_paused(value: bool) -> void:
	if phase not in ["running","paused"]: return
	if value and phase=="paused": return
	if value:
		if phase=="running" and not _flush(): return
		if phase not in ["running","paused"]: return
	else:
		error=eligibility_error()
		if not error.is_empty(): changed.emit(); return
		if training==null and not _make_training(): changed.emit(); return
		training._sync_board()
		if not training.error.is_empty(): _fail(training.error); return
	var prepared := MapLoadoutStore.candidate(loadout)
	if not prepared.error.is_empty(): _fail(prepared.error); return
	var next: MapLoadoutState=prepared.state
	next.growth.breakthrough_attempt.phase="paused" if value else "running"
	if not _commit(next): return
	phase="paused" if value else "running"
	if training!=null: training.paused=value
	changed.emit()

func reset() -> bool:
	if phase=="running" and not _flush(): return false
	if loadout.growth.has("breakthrough_attempt"):
		var prepared := MapLoadoutStore.candidate(loadout)
		if not prepared.error.is_empty(): return _fail(prepared.error)
		var next: MapLoadoutState=prepared.state
		next.growth.erase("breakthrough_attempt")
		if not _commit(next): return false
	training=null; _pending=0.0; phase="ready"; error=""
	changed.emit()
	return true

func advance(seconds: float) -> void:
	if phase!="running" or not is_finite(seconds) or seconds<=0.0: return
	_pending=minf(_pending+seconds,(limit_usec()-elapsed_usec())/1000000.0)
	while _pending>=SETTLEMENT_STEP_SECONDS and phase=="running":
		if not _step(minf(SETTLEMENT_STEP_SECONDS,_pending)): return
	# A fractional final step must not leave the attempt running past its deadline.
	if phase=="running" and _pending>0.0 and presentation_usec()>=limit_usec(): _flush()

func _flush() -> bool:
	while _pending>0.0000001 and phase=="running":
		if not _step(minf(SETTLEMENT_STEP_SECONDS,_pending)): return false
	return true

func _step(seconds: float) -> bool:
	if training==null: return _fail("修炼运行状态已中断，请暂停后继续。")
	# Keep the shared calendar boundary exact, including prior partial training days.
	seconds=minf(seconds,training.seconds_until_day_end())
	if not training._advance_chunk(seconds):
		var reason := training.error
		_pending=0.0 # Only uncommitted work is discarded; committed time stays in the save.
		training=null
		return _fail("突破已暂停："+reason)
	_pending=maxf(0.0,_pending-seconds)
	phase=str(loadout.growth.breakthrough_attempt.phase)
	if phase in ["failed","succeeded"]:
		_pending=0.0; training=null
		preload("res://scripts/entry/save_checkpoints.gd").after_action(loadout,save_path,"breakthrough_complete")
	changed.emit()
	return true

func _settle_step(next: MapLoadoutState, seconds: float) -> String:
	var g := next.growth
	var attempt: Dictionary=g.breakthrough_attempt
	attempt.elapsed_usec=int(attempt.elapsed_usec)+roundi(seconds*1000000.0)
	var cutoff := int(attempt.elapsed_usec)-day_usec()
	var history: Array=attempt.get("recent_gains",[])
	while not history.is_empty() and int(history[0].at_usec)<=cutoff: history.pop_front()
	attempt.recent_gains=history
	# Reaching the target at the deadline counts as success.
	if int(attempt.progress)>=target() and bool(rule.complete_on_target):
		var before := CultivationGrowth.maxima(g)
		var chance := success_chance()
		g.realm=1; g.layer=1; g.progress=0
		g.breakthrough_serial=int(g.breakthrough_serial)+1
		var after := CultivationGrowth.maxima(g)
		attempt.result={"progress":target(),"target":target(),"chance":chance,
			"gains":{"hp":int(after.hp)-int(before.hp),"spirit":int(after.spirit)-int(before.spirit),
				"stamina":int(after.stamina)-int(before.stamina),"cultivation_efficiency_percent":0}}
		for key: String in g.resources: g.resources[key]=int(g.resources[key])+(int(after[key])-int(before[key]))*100
		attempt.phase="succeeded"
		next.cultivation_rank_id=CultivationGrowth.rank_id(g)
		next.narrative.flags[FIRST_QI_FLAG]=true
		next.narrative.flags[HomecomingQuest.BREAKTHROUGH_FAILED_FLAG]=false
		HomecomingQuest.story(next).updated_at=WorldCalendar.current_day(next.calendar)
	elif int(attempt.elapsed_usec)>=limit_usec():
		attempt.result={"progress":int(attempt.progress),"target":target(),"chance":success_chance(),
			"gains":{"hp":0,"spirit":0,"stamina":0,"cultivation_efficiency_percent":0}}
		attempt.progress=int(rule.timeout_progress)
		attempt.phase="failed"
		next.narrative.flags[HomecomingQuest.BREAKTHROUGH_FAILED_FLAG]=true
	return ""

func _award(next: MapLoadoutState, amount: int, offset_usec: int) -> int:
	var attempt: Dictionary=next.growth.breakthrough_attempt
	var accepted := mini(maxi(0,amount),target()-int(attempt.progress))
	attempt.progress=int(attempt.progress)+accepted
	if accepted>0:
		var history: Array=attempt.get("recent_gains",[])
		var at_usec := int(attempt.elapsed_usec)+offset_usec
		if not history.is_empty() and int(history[-1].at_usec)==at_usec:
			history[-1].amount=int(history[-1].amount)+accepted
		else: history.append({"at_usec":at_usec,"amount":accepted})
		attempt.recent_gains=history
	return accepted

func _commit(next: MapLoadoutState) -> bool:
	error=MapLoadoutStore.save(next,save_path)
	if not error.is_empty(): return _fail(error)
	error=loadout.restore(next.snapshot())
	if not error.is_empty(): return _fail(error)
	player.apply_growth(loadout.growth)
	return true

func _fail(message: String) -> bool:
	error=message
	if phase=="running": phase="paused"
	changed.emit()
	return false

func cooldown_snapshot() -> Dictionary:
	# Read committed timers without settling or advancing the simulation from UI.
	var result := {}
	if training==null or training.simulation==null: return result
	var sim: CultivationTraining = training.simulation
	for id: String in sim.timeline.timers:
		var timer: Dictionary = sim.timeline.timers[id]
		var work := maxf(0.0,float(sim.state.time_usec)-float(timer.at))*float(timer.speed)
		var entry_work := minf(float(timer.entry),work)
		result[id]={"entry":maxf(0.0,float(timer.entry)-entry_work),
			"remaining":maxf(0.0,float(timer.cd)-(work-entry_work)),
			"duration":sim.timeline.full_cd(id),"speed":float(timer.speed)}
	return result

func status_text() -> String:
	if not error.is_empty(): return error
	if phase=="succeeded": return "突破成功，已晋入炼气一层。"
	if phase=="failed": return "30日期限已到，突破未成。退出后可从0重新尝试。"
	if phase=="ready":
		var missing := eligibility_error()
		return missing if not missing.is_empty() else "准备就绪，可开始引气。"
	return "突破已暂停，可调整阵盘。" if phase=="paused" else "正在引气，积满%d即突破成功。"%int(rule.target)

func status_member() -> PartyMemberState:
	if training==null or training.simulation==null: return null
	return training.simulation.state.teams[0][0]
