extends RefCounted

const KEYS := ["armor", "shield", "counter", "vitality", "moisture", "flame", "tenacity", "agility", "thunder"]

static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in value:
		var amount: Variant = value[key]
		if key not in KEYS or not (amount is int or amount is float) or not is_finite(float(amount)) or amount < 0:
			return false
	return true

static func sum_sources(rank: Dictionary, board_bonuses: Dictionary, equipped: Array) -> Dictionary:
	var totals := {}
	for key in KEYS:
		totals[key] = 0.0
	_add(totals, rank.get("buff_bonuses", {}))
	_add(totals, board_bonuses)
	for record: Dictionary in equipped:
		_add(totals, record.get("buff_bonuses", {}))
		# Capacity contributed by armor, not its timed refill.
		totals.armor += float(record.get("armor_capacity", 0))
	return totals

static func _add(totals: Dictionary, source: Dictionary) -> void:
	for key in KEYS:
		totals[key] += float(source.get(key, 0))
