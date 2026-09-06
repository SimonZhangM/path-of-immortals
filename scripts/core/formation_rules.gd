class_name FormationRules
extends RefCounted

enum Kind { FRONT_ONE, FRONT_TWO }

static func rows(count: int, kind: Kind = Kind.FRONT_ONE) -> Dictionary:
	if count <= 1:
		return {"front": [], "rear": [], "single": [0] if count == 1 else []}
	if count == 2:
		return {"front": [0], "rear": [1], "single": []}
	return {"front": [1, 2] if kind == Kind.FRONT_TWO else [0], "rear": [0] if kind == Kind.FRONT_TWO else [1, 2], "single": []}

static func target_order(count: int, kind: Kind = Kind.FRONT_ONE) -> Array:
	var ranks := rows(count, kind)
	return ranks["single"] + ranks["front"] + ranks["rear"]

static func label(count: int, kind: Kind = Kind.FRONT_ONE) -> String:
	if count <= 1:
		return "单人阵型"
	if count == 2:
		return "前1后1"
	return "前2后1" if kind == Kind.FRONT_TWO else "前1后2"
