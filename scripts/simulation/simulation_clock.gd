class_name SimulationClock
extends RefCounted

const SPEEDS := [1, 2, 4, 8]
var time_usec: int = 0
var speed_multiplier: int = 1
var paused: bool = false
var _fractional_usec: float = 0.0

func set_speed(speed: int) -> void:
	if speed in SPEEDS:
		speed_multiplier = speed

func advance(real_delta: float) -> int:
	if paused or not is_finite(real_delta) or real_delta <= 0.0:
		return time_usec
	var scaled_usec := real_delta * speed_multiplier * 1_000_000.0 + _fractional_usec
	var whole_usec := roundi(scaled_usec)
	_fractional_usec = scaled_usec - whole_usec
	time_usec += whole_usec
	return time_usec
