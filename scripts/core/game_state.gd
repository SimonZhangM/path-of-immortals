class_name GameState
extends RefCounted

enum Phase { PREPARATION, BATTLE, FINISHED }
var phase: Phase = Phase.PREPARATION
var time_usec: int = 0
var finished_at_usec: int = -1
var result: String = ""
var revision: int = 0
var teams: Array = []
var formations: Array = []
var item_runtime: Dictionary = {}
var activation_counts: Array[int] = [0, 0]
var damage_totals: Array[int] = [0, 0]

func _init(allies: Array, enemies: Array, ally_formation: FormationRules.Kind, enemy_formation: FormationRules.Kind) -> void:
	teams = [allies.duplicate(), enemies.duplicate()]
	formations = [ally_formation, enemy_formation]

func is_finished() -> bool:
	return phase == Phase.FINISHED

func target_for(attacking_side: int) -> PartyMemberState:
	var defending_side := 1 - attacking_side
	var team: Array = teams[defending_side]
	for index in FormationRules.target_order(team.size(), formations[defending_side]):
		if team[index].hp > 0:
			return team[index]
	return null

func has_survivor(side: int) -> bool:
	for member in teams[side]:
		if member.hp > 0:
			return true
	return false
