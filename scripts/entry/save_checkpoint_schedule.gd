extends RefCounted
## Real play-time schedule. One pending request survives unsafe UI/game phases.
const INTERVAL := 600.0
var enabled := true
var interval := INTERVAL
var elapsed := 0.0
var pending := false
var retry_after := 0.0

func configure_preferences(active: bool, seconds: float) -> void:
	var next_interval := maxf(1.0,seconds)
	if enabled==active and is_equal_approx(interval,next_interval): return
	enabled = active
	interval = next_interval
	# Applying a different interval starts a fresh countdown; a stale pending
	# request must not write immediately after the player disables/re-enables it.
	elapsed = 0.0
	pending = false
	retry_after = 0.0

func advance(seconds: float, paused: bool, safe: bool) -> bool:
	if not enabled or paused: return false
	retry_after = maxf(0.0,retry_after-maxf(0.0,seconds))
	elapsed = minf(interval,elapsed+maxf(0.0,seconds))
	if elapsed>=interval: pending = true
	return pending and safe and retry_after<=0.0

func complete(success: bool) -> void:
	if success:
		elapsed = 0.0
		pending = false
	else:
		retry_after = 5.0
