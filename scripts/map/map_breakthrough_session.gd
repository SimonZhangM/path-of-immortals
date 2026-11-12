extends RefCounted
## Presentation commands; the optional runtime owns actual first-qi settlement.
signal changed
signal reset_requested
signal result_requested
const FIRST_QI_FLAG := "base.story.chaoshengguichu.qi_confirmed"
var phase := "ready"
var started := false
var pair_index := 0
var elapsed_usec := 0
var _fractional_usec := 0.0
var runtime: RefCounted
var speed := 1.0

func set_speed(value: float) -> void:
	if value not in [0.5,1.0,2.0,4.0] or phase in ["failed","succeeded"]: return
	speed=value
	changed.emit()

func play_normal() -> void:
	set_speed(1.0)
	if phase=="ready": start()
	elif phase=="paused": set_paused(false)

func bind_runtime(loadout: MapLoadoutState, player: MapPlayerStatus, path: String) -> void:
	if runtime!=null: return
	runtime=preload("res://scripts/map/map_breakthrough_run.gd").new()
	runtime.changed.connect(_sync_runtime)
	runtime.bind(loadout,player,path)

func _sync_runtime() -> void:
	phase=runtime.phase
	started=phase!="ready"
	elapsed_usec=runtime.presentation_usec()
	changed.emit()

func configure(loadout: MapLoadoutState) -> void:
	if phase!="ready": return
	# Legacy test saves may already be 化神; the first story breakthrough is 引气.
	pair_index = 0 if not loadout.narrative.flags.get(FIRST_QI_FLAG,false) else clampi(int(loadout.growth.realm),1,4)
	changed.emit()

func start() -> bool:
	if runtime!=null: return runtime.start()
	if phase!="ready": return false
	phase = "running"
	started = true
	changed.emit()
	return true

func activate_primary() -> void:
	if phase in ["succeeded","failed"]: result_requested.emit()
	elif not started: start()
	elif phase in ["running","paused"]: set_paused(phase=="running")

func set_paused(value: bool) -> void:
	if runtime!=null:
		runtime.set_paused(value)
		return
	if phase=="ready": return
	var next := "paused" if value else "running"
	if phase==next: return
	phase = next
	changed.emit()

func can_adjust() -> bool:
	return phase in ["ready","paused"]

func reset() -> bool:
	if runtime!=null and not runtime.reset(): return false
	phase = "ready"
	started = false
	elapsed_usec = 0
	_fractional_usec = 0.0
	speed = 1.0
	# Future authoritative breakthrough progress must reset on this command.
	reset_requested.emit()
	changed.emit()
	return true

func advance(seconds: float) -> void:
	# Only simulation input is scaled; audio and the rest of the game stay realtime.
	seconds *= speed
	if runtime!=null:
		runtime.advance(seconds)
		elapsed_usec=runtime.presentation_usec()
		return
	if phase!="running" or not is_finite(seconds) or seconds<=0.0: return
	var amount := seconds*1000000.0+_fractional_usec
	var whole := floori(amount)
	elapsed_usec += whole
	_fractional_usec = amount-whole
