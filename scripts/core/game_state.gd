class_name GameState
extends RefCounted

enum Phase { PREPARATION, BATTLE, FINISHED }
var phase: Phase = Phase.PREPARATION
var time_usec: int = 0
var finished_at_usec: int = -1
var result: String = ""
var retreat_at_usec: int = -1
var revision: int = 0
var teams: Array = []
var companions: Array = [[], []]
var trait_runtime: Dictionary = {}
var item_runtime: Dictionary = {}
var activation_counts: Array[int] = [0, 0]
var damage_totals: Array[int] = [0, 0]

func _init(allies: Array, enemies: Array, ally_companions: Array, enemy_companions: Array) -> void:
	teams = [allies.duplicate(), enemies.duplicate()]
	companions = [ally_companions.duplicate(), enemy_companions.duplicate()]

func is_finished() -> bool:
	return phase == Phase.FINISHED

func target_for(attacking_side: int) -> PartyMemberState:
	return teams[1 - attacking_side][0] if has_survivor(1 - attacking_side) else null

func has_survivor(side: int) -> bool:
	return teams[side].size() == 1 and teams[side][0].hp > 0
