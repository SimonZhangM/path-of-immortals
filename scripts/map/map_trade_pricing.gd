class_name MapTradePricing
extends RefCounted

signal changed

# Basis points: 10000 = 100%. Future reputation, events, etc. calculate the
# effective factors outside this class; this interface does not decide stacking.
const BPS := 10000
const MAX_FACTOR_BPS := 1000000
const MAX_BASE_PRICE := 1000000
var _base_prices: Dictionary = {}
var _buy_bps := 15000
var _sell_bps := 5000

func configure(rules: Variant, prices: Variant) -> String:
	if not rules is Dictionary or rules.get("buy_rounding")!="ceil" or rules.get("sell_rounding")!="floor": return "交易取整配置无效。"
	if not valid_factor(rules.get("buy_factor_bps")) or not valid_factor(rules.get("sell_factor_bps")): return "交易价格因数无效。"
	if not prices is Dictionary or not prices.get("prices") is Dictionary: return "物品基准价表无效。"
	for id: Variant in prices.prices:
		if not id is String or not WorldCalendar.integer_between(prices.prices[id],1,MAX_BASE_PRICE): return "物品基准价无效。"
	_base_prices = prices.prices.duplicate()
	return set_factors(int(rules.buy_factor_bps),int(rules.sell_factor_bps))

static func valid_factor(value: Variant) -> bool:
	return WorldCalendar.integer_between(value,1,MAX_FACTOR_BPS)

func set_factors(buy_bps: int, sell_bps: int) -> String:
	if not valid_factor(buy_bps) or not valid_factor(sell_bps): return "交易价格因数无效。"
	_buy_bps = buy_bps
	_sell_bps = sell_bps
	changed.emit()
	return ""

func factors() -> Dictionary:
	return {"buy_factor_bps":_buy_bps,"sell_factor_bps":_sell_bps}

func has_base_price(item_id: String) -> bool:
	return _base_prices.has(item_id)

func buy_unit_price(item_id: String, preview_quote := 0, preview_factor_bps := 15000) -> int:
	if has_base_price(item_id): return _round_ratio(int(_base_prices[item_id])*_buy_bps,BPS,true)
	# Old demo prices were final purchase quotes at 150%, NOT base prices.
	# Keep that reference explicit until each item's real base price is assigned.
	if not WorldCalendar.integer_between(preview_quote,1,MAX_BASE_PRICE) or not valid_factor(preview_factor_bps): return -1
	return _round_ratio(preview_quote*_buy_bps,preview_factor_bps,true)

func sell_unit_price(item_id: String) -> int:
	if not has_base_price(item_id): return -1
	return _round_ratio(int(_base_prices[item_id])*_sell_bps,BPS,false)

static func _round_ratio(numerator: int, denominator: int, upward: bool) -> int:
	# Integer arithmetic avoids floating-point overcharging at exact boundaries.
	@warning_ignore("integer_division")
	return (numerator+denominator-1)/denominator if upward else numerator/denominator
