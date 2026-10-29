extends RefCounted
## Presentation-only reveal and dwell time. Owners decide whether advancing is
## allowed; this helper never selects choices, grants rewards or changes story.
const RATES := {"slow":15.0,"medium":30.0,"fast":60.0}
const AUTO_WAIT := 2.0
var labels: Array[Label] = []
var character_count := 0
var revealed := 0.0
var dwell := 0.0
var fired := false

func begin(targets: Array[Label], speed: String, animate := true) -> void:
	labels = targets
	character_count = 0
	for label in labels: character_count += label.text.length()
	revealed = 0.0 if animate and speed!="instant" else float(character_count)
	dwell = 0.0
	fired = false
	_sync_labels()

func is_revealing() -> bool:
	return revealed<float(character_count)

func finish_reveal() -> bool:
	if not is_revealing(): return false
	revealed = float(character_count)
	dwell = 0.0
	_sync_labels()
	return true

func suspend() -> void:
	dwell = 0.0

func advance(seconds: float, speed: String, auto_allowed: bool) -> bool:
	var remaining := maxf(0.0,seconds)
	if is_revealing():
		if speed=="instant":
			finish_reveal()
		else:
			var rate: float = RATES.get(speed,RATES.medium)
			var reveal_time := (float(character_count)-revealed)/rate
			var used := minf(remaining,reveal_time)
			revealed = minf(float(character_count),revealed+used*rate)
			remaining -= used
			_sync_labels()
	if is_revealing() or not auto_allowed or fired:
		dwell = 0.0
		return false
	dwell += remaining
	if dwell<AUTO_WAIT: return false
	fired = true
	dwell = 0.0
	return true

func _sync_labels() -> void:
	var available := int(floor(revealed))
	for label in labels:
		if not is_instance_valid(label): continue
		var length := label.text.length()
		label.visible_characters = -1 if available>=length else maxi(0,available)
		available -= length
