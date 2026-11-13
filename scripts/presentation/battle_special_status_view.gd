extends RefCounted
## Read-only projection of existing authority; never turns a log event into a buff.
const DEFINITIONS_PATH := "res://data/ui/battle_special_statuses.json"
static var _definitions: Dictionary = {}

static func definitions() -> Dictionary:
	if _definitions.is_empty():
		for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(DEFINITIONS_PATH)):
			_definitions[entry.name] = entry
	return _definitions

static func snapshot(member: PartyMemberState, simulation: BattleSimulation) -> Dictionary:
	var result := {}
	if member == null or member.hp <= 0: return result
	var now: int = simulation.state.time_usec if simulation != null else 0
	for word: String in ["免疫", "麻痹", "冻结"]:
		var until: int = {"免疫": member.toxin_immune_until_usec, "麻痹": member.paralyzed_until, "冻结": member.frozen_until}[word]
		if until > now:
			result[word] = {"until": until, "badge": "", "current": "毒蚀免疫生效中" if word == "免疫" else "生效中", "sources": []}
	if simulation != null and simulation.timeline != null:
		for control: Dictionary in simulation.timeline.controls.values():
			if control.member != member or int(control.until) <= now: continue
			var word: String = {"freeze": "冻结", "root": "定身"}.get(control.kind, "")
			if word.is_empty(): continue
			var previous: Dictionary = result.get(word, {"until": 0, "badge": "", "current": "生效中", "sources": []})
			previous.until = maxi(int(previous.until), int(control.until))
			if control.get("source", "") not in previous.sources: previous.sources.append(control.get("source", ""))
			result[word] = previous
	var shields: Array[String] = []
	var sources: Array[String] = []
	for index in member.thunder_shields.size():
		if member.thunder_shields[index] <= 0: continue
		shields.append(EffectSystem.number_text(member.thunder_shields[index]))
		if index < member.thunder_shield_origins.size():
			for origin: Dictionary in member.thunder_shield_origins[index].get("replay_sources", []):
				var id: String = origin.get("owner_id", "")
				if not id.is_empty() and id not in sources: sources.append(id)
	if not shields.is_empty():
		result["雷盾"] = {"until": 0, "badge": str(shields.size()), "current": "%d层 · 盾量 %s" % [shields.size(), " / ".join(shields)], "sources": sources}
	return result
