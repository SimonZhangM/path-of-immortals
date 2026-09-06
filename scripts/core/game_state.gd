class_name GameState
extends RefCounted

var time_usec: int = 0
var enemy_id: String
var enemy_hp: int
var item_id: String
var item_instance_id: String = "run.item.001"
var next_activation_usec: int = 0
var activation_count: int = 0
var damage_total: int = 0
var defeated_at_usec: int = -1
var revision: int = 0

func _init(item: ItemData, enemy: Dictionary) -> void:
	item_id = item.id
	enemy_id = enemy["id"]
	enemy_hp = int(enemy["max_hp"])
	next_activation_usec = item.cooldown_usec

func is_finished() -> bool:
	return enemy_hp <= 0
