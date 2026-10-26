extends RefCounted
## Content lookup and session-local random draw; no scene/save dependencies.
const CONFIG := "res://data/character_root_descriptions.json"
var configurations: Array = []
var records: Array = []
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	records = data.records
	var entropy := Crypto.new().generate_random_bytes(8)
	if entropy.size() == 8: _rng.seed = entropy.decode_s64(0)
	else: _rng.randomize()
	for count in range(1, 6): _combinations(data.elements, count, 0, [])

func _combinations(elements: Array, count: int, start: int, selected: Array) -> void:
	if selected.size() == count:
		configurations.append(selected.duplicate())
		return
	for index in range(start, elements.size()):
		selected.append(elements[index])
		_combinations(elements, count, index + 1, selected)
		selected.pop_back()

func describe(elements: Array, variant: int = 0) -> Dictionary:
	var candidates: Array = []
	for record: Dictionary in records:
		if int(record.count) != elements.size(): continue
		if elements.size() <= 3:
			if record.elements.size() != elements.size(): continue
			var matches := true
			for id in record.elements:
				if not elements.has(id): matches = false
			if not matches: continue
		candidates.append(record)
	if candidates.is_empty(): return {}
	var result: Dictionary = candidates[posmod(variant, candidates.size())].duplicate(true)
	result["elements"] = elements.duplicate()
	return result

func draw() -> Dictionary:
	# One ticket per prose entry: 7/21/35/5/5 out of 73, as confirmed by the user.
	var result: Dictionary = records[_rng.randi_range(0, records.size() - 1)].duplicate(true)
	if int(result.count) >= 4:
		var candidates: Array = []
		for elements: Array in configurations:
			if elements.size() == int(result.count): candidates.append(elements)
		result["elements"] = candidates[_rng.randi_range(0, candidates.size() - 1)].duplicate()
	return result
