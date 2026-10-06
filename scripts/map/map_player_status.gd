class_name MapPlayerStatus
extends RefCounted

signal changed

var character_id := ""
var display_name := ""
var rank_name := ""
var cultivation_rank_id := ""
var age := 15
var lifespan := 80
var spirit_stones := 0
var experience := 0
var resources: Dictionary = {}
var character_definition: Dictionary = {}
var companion_ids: Array[String] = []
var maxima: Dictionary = {}
var _active_board_bonuses: Dictionary = {}
var cultivation_progress := 0
var cultivation_required := 100

func configure(registry: ContentRegistry, config: Dictionary) -> String:
	var character := registry.get_character(config.get("character_id", ""))
	if character.is_empty():
		return "地图状态栏角色不存在。"
	var roster: Variant = config.get("companion_ids", [])
	if not roster is Array or roster.size() > 2:
		return "当前队友名单无效。"
	companion_ids.clear()
	for id in roster:
		if not id is String or id == character.id or id in companion_ids or registry.get_character(id).is_empty():
			return "当前队友不存在或重复。"
		companion_ids.append(id)
	character_definition = character.duplicate(true)
	character_definition.portrait = config.get("portrait", character.portrait)
	if config.has("portrait_region"):
		character_definition.portrait_region = config.portrait_region.duplicate()
	var rank := registry.get_cultivation(character.get("cultivation_rank", ""))
	if rank.is_empty():
		return "地图状态栏修仙等级不存在。"
	var stage: Variant = character.get("cultivation_stage", "")
	if not stage is String:
		return "地图修仙层级名称无效。"
	for key in ["cultivation_progress", "cultivation_required", "age", "lifespan", "spirit_stones", "experience"]:
		var value: Variant = config.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or float(value) != floorf(float(value)):
			return "地图状态栏数值无效：" + key
	if config.lifespan <= 0 or config.age > config.lifespan:
		return "地图年龄或寿元超出范围。"
	if config.cultivation_required <= 0 or config.cultivation_progress > config.cultivation_required:
		return "地图修为测试进度超出范围。"
	character_id = character.id
	display_name = character.name
	rank_name = rank.name
	cultivation_rank_id = rank.id
	if not stage.is_empty():
		rank_name += " · " + stage
	age = int(config.age)
	lifespan = int(config.lifespan)
	spirit_stones = int(config.spirit_stones)
	experience = int(config.experience)
	var board := registry.get_board(character.get("board_layout", ""))
	_active_board_bonuses = board.resource_bonuses.duplicate() if board != null else {}
	for resource in ["hp", "stamina", "spirit"]:
		maxima[resource] = int(character["max_" + resource]) + (board.resource_bonus(resource) if board != null else 0)
		resources[resource] = maxima[resource]
	cultivation_progress = int(config.cultivation_progress)
	cultivation_required = int(config.cultivation_required)
	changed.emit()
	return ""

func apply_board(board: BoardLayout) -> void:
	if character_definition.get("board_layout", "") == board.id: return
	for resource in ["hp", "stamina", "spirit"]:
		maxima[resource] += board.resource_bonus(resource) - int(_active_board_bonuses.get(resource, 0))
		resources[resource] = minf(resources[resource], maxima[resource])
	_active_board_bonuses = board.resource_bonuses.duplicate()
	character_definition.board_layout = board.id
	changed.emit()

func set_resource(resource: String, value: float) -> void:
	if not maxima.has(resource) or not is_finite(value):
		return
	var next_value := clampf(value, 0.0, maxima[resource])
	if resources[resource] != next_value:
		resources[resource] = next_value
		changed.emit()

func apply_battle_resources(member: PartyMemberState, defeated := false) -> void:
	# Only durable resources cross this boundary; armor, shields and statuses
	# follow their own battle cleanup rules. Map progression is not reset.
	assert(member.id == character_id)
	for resource: String in ["hp", "stamina", "spirit"]:
		maxima[resource] = member.maximum(resource)
		resources[resource] = clampf(float(member.get(resource)),0.0,maxima[resource])
	# Recovery belongs to the post-battle map state, not the defeated combatant.
	if defeated and member.hp <= 0:
		resources.hp = minf(1.0,float(maxima.hp))
	changed.emit()

func battle_snapshot() -> Dictionary:
	var current := character_definition.duplicate(true)
	current.name = display_name
	current.cultivation_rank = cultivation_rank_id
	return {"character": current, "resources": resources.duplicate(), "companion_ids": companion_ids.duplicate()}
