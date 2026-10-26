extends RefCounted
## Session-local creation draft. No gameplay save is read or written.
var full_name := ""
var surname := ""
var given_name := ""
var gender := ""
var root_selection: Dictionary = {}
var _pool: Array = []
var _bags: Dictionary = {}
var _last_random_name := ""
var _rng := RandomNumberGenerator.new()

func _init(pool: Array) -> void:
	_pool = pool.duplicate(true)
	# Independent OS entropy on every entry; never shares a gameplay/test RNG seed.
	var entropy := Crypto.new().generate_random_bytes(8)
	if entropy.size() == 8:
		_rng.seed = entropy.decode_s64(0)
	else:
		_rng.randomize()

func set_manual_name(value: String) -> void:
	full_name = value
	# A single input cannot reliably distinguish compound surnames. Preserve the
	# raw name; formal creation can request the split instead of guessing it.
	surname = ""
	given_name = ""

func identity_complete() -> bool:
	return not full_name.replace("　", "").strip_edges().is_empty() and gender in ["male", "female"]

func draw_name() -> String:
	if _pool.is_empty(): return full_name
	var scope := gender if gender in ["male", "female"] else "all"
	var remaining: Array = _bags.get(scope, [])
	if remaining.is_empty():
		for index in _pool.size():
			if scope == "all" or _pool[index].get("gender", "") == scope:
				remaining.append(index)
		if remaining.is_empty(): return full_name
		for index in range(remaining.size() - 1, 0, -1):
			var other := _rng.randi_range(0, index)
			var temporary: int = remaining[index]
			remaining[index] = remaining[other]
			remaining[other] = temporary
	# Each scope keeps its round when switching genders; avoid adjacent repeats when possible.
	if remaining.size() > 1 and _name_at(remaining.back()) == _last_random_name:
		var other := _rng.randi_range(0, remaining.size() - 2)
		var temporary: int = remaining.back()
		remaining[remaining.size() - 1] = remaining[other]
		remaining[other] = temporary
	var entry: Dictionary = _pool[remaining.pop_back()]
	_bags[scope] = remaining
	surname = entry.surname
	given_name = entry.given_name
	full_name = surname + given_name
	_last_random_name = full_name
	return full_name

func _name_at(index: int) -> String:
	return str(_pool[index].surname) + str(_pool[index].given_name)
