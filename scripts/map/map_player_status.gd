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
var maxima: Dictionary = {}
var cultivation_progress := 0
var cultivation_required := 100

func configure(registry: ContentRegistry, config: Dictionary) -> String:
	var character := registry.get_character(config.get("character_id", ""))
	if character.is_empty():
		return "地图状态栏角色不存在。"
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
	for resource in ["hp", "stamina", "spirit"]:
		maxima[resource] = int(character["max_" + resource]) + (board.resource_bonus(resource) if board != null else 0)
		resources[resource] = maxima[resource]
	cultivation_progress = int(config.cultivation_progress)
	cultivation_required = int(config.cultivation_required)
	changed.emit()
	return ""

func set_resource(resource: String, value: int) -> void:
	if not maxima.has(resource):
		return
	var next_value := clampi(value, 0, maxima[resource])
	if resources[resource] != next_value:
		resources[resource] = next_value
		changed.emit()
