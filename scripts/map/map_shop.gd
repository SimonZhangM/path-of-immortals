class_name MapShop
extends RefCounted

const PAGE_SIZE := 8
const MAX_QUANTITY := 999
const RULES_PATH := "res://data/shops/trade_rules.json"
const PRICES_PATH := "res://data/shops/item_base_prices.json"
var definition: Dictionary = {}
var profile: Dictionary = {}
var pricing := MapTradePricing.new()

func load_catalog(path: String, state: MapLoadoutState) -> String:
	if not FileAccess.file_exists(path): return "商铺商品配置不存在。"
	return configure(JSON.parse_string(FileAccess.get_file_as_string(path)),state)

func configure(raw: Variant, state: MapLoadoutState, trade_rules: Variant = null, base_prices: Variant = null) -> String:
	if not raw is Dictionary or not raw.get("id") is String or not raw.id.begins_with("base.shop."): return "商铺标识无效。"
	for key in ["title","description"]:
		if not raw.get(key) is String or raw[key].is_empty(): return "商铺文案缺失。"
	if not raw.get("crafting_tab",false) is bool: return "生产页签开关无效。"
	if raw.has("crafting_label") and (not raw.crafting_label is String or raw.crafting_label.strip_edges().is_empty()): return "生产页签名称无效。"
	if raw.has("leave_label") and (not raw.leave_label is String or raw.leave_label.strip_edges().is_empty()): return "商铺离开按钮文案无效。"
	if trade_rules == null: trade_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	if base_prices == null: base_prices = JSON.parse_string(FileAccess.get_file_as_string(PRICES_PATH))
	if not trade_rules is Dictionary or not trade_rules.get("profiles") is Dictionary: return "商铺经营范围配置无效。"
	if not raw.get("profile") is String or not trade_rules.profiles.has(raw.profile): return "商铺经营类型不存在。"
	var candidate_profile: Variant = trade_rules.profiles[raw.profile]
	if not candidate_profile is Dictionary or not candidate_profile.get("categories") is Array or candidate_profile.categories.is_empty() or candidate_profile.categories.size()>4: return "商铺必须配置一至四个分类。"
	var categories := {}
	var inventory_categories := {}
	for category: Variant in candidate_profile.categories:
		if not category is Dictionary or not category.get("id") is String or category.id.is_empty() or category.id=="all" or categories.has(category.id): return "商铺分类无效或重复。"
		if not category.get("label") is String or category.label.is_empty() or not category.get("inventory_categories") is Array: return "商铺分类名称或映射无效。"
		for inventory_category: Variant in category.inventory_categories:
			if not inventory_category is String or inventory_category.is_empty() or inventory_categories.has(inventory_category): return "商铺库存分类映射无效或重复。"
			inventory_categories[inventory_category] = category.id
		categories[category.id] = true
	var candidate_pricing := MapTradePricing.new()
	var pricing_error := candidate_pricing.configure(trade_rules.get("pricing"),base_prices)
	if not pricing_error.is_empty(): return pricing_error
	for id: String in base_prices.prices:
		if not state.records.has(id): return "基准价引用了未知物品。"
	if not raw.get("products") is Array: return "商铺商品列表无效。"
	var ids := {}
	for row: Variant in raw.products:
		if not row is Dictionary or not row.get("item_id") is String or not state.records.has(row.item_id) or ids.has(row.item_id): return "商铺商品不存在或重复。"
		if not row.get("category") is String or not categories.has(row.category): return "商品不在商铺经营范围内。"
		if inventory_categories.get(state.records[row.item_id].category,"")!=row.category: return "商品分类与物品不符。"
		# Do not accept the ambiguous old `price` field as a new base price.
		if row.has("price"): return "请区分基准价与暂定成交价。"
		if row.has("preview_buy_price"):
			if raw.get("provisional")!=true or not WorldCalendar.integer_between(row.preview_buy_price,1,MapTradePricing.MAX_BASE_PRICE) or not MapTradePricing.valid_factor(raw.get("preview_buy_factor_bps")): return "暂定商品价格无效。"
		ids[row.item_id] = true
	definition = raw.duplicate(true)
	profile = candidate_profile.duplicate(true)
	pricing = candidate_pricing
	return ""

func categories() -> Array:
	return profile.get("categories",[]).duplicate(true)

# Scope is independent of stocked products, and is not permission to sell an
# equipped/favorite/quest item. Actual sale protection belongs to the transaction.
func category_for(record: Dictionary) -> String:
	for category: Dictionary in profile.get("categories",[]):
		if record.get("category","") in category.inventory_categories: return category.id
	return ""

func buy_unit_price(item_id: String) -> int:
	var row := product(item_id)
	if row.is_empty(): return -1
	return pricing.buy_unit_price(item_id,int(row.get("preview_buy_price",0)),int(definition.get("preview_buy_factor_bps",15000)))

func products(category := "all") -> Array:
	return definition.get("products",[]).filter(func(row): return category=="all" or row.category==category).duplicate(true)

func product(item_id: String) -> Dictionary:
	for row: Dictionary in definition.get("products",[]):
		if row.item_id == item_id: return row.duplicate()
	return {}

# Scope is independent of stock and of price readiness.
# Only loose, carried units are counted; board placements and warehouses stay out.
func _sale_allowed(state: MapLoadoutState, item_id: String) -> bool:
	var record: Dictionary = state.records.get(item_id,{})
	if category_for(record).is_empty(): return false
	if record.get("favorite",false) or record.get("key_item",false) or record.get("quest_item",false): return false
	if record.get("category","") in ["key","quest"]: return false
	return record.get("board_layout","")!=state.board.id

func sale_items(state: MapLoadoutState, category := "all") -> Array:
	var rows: Array = []
	for entry: Dictionary in state.storage.entries():
		var record: Dictionary = state.records.get(entry.item_id,{})
		var shop_category := category_for(record)
		if shop_category.is_empty() or (category!="all" and shop_category!=category): continue
		if not _sale_allowed(state,entry.item_id): continue
		if entry.units.is_empty(): continue
		rows.append({"item_id":entry.item_id,"category":shop_category,"quantity":entry.units.size()})
	rows.sort_custom(func(a: Dictionary,b: Dictionary):
		var a_time: int = int(state.records[a.item_id].get("acquired_at",0))
		var b_time: int = int(state.records[b.item_id].get("acquired_at",0))
		return a.item_id<b.item_id if a_time==b_time else a_time>b_time
	)
	return rows

func sell(state: MapLoadoutState, item_id: String, quantity: int, save_path: String) -> String:
	if quantity<1 or quantity>MAX_QUANTITY: return "出售数量无效。"
	if state.inventory.locked: return "当前不能出售。"
	if not _sale_allowed(state,item_id): return "此物品不在收购范围内或受到出售保护。"
	var units: Array[String] = []
	for entry: Dictionary in state.storage.entries():
		if entry.item_id==item_id:
			for unit: Dictionary in entry.units: units.append(unit.id)
	if quantity>units.size(): return "储物袋内可出售数量不足，请重新选择。"
	var price := pricing.sell_unit_price(item_id)
	if price<0: return "此物品尚未定价。"
	var total := price*quantity
	if state.spirit_stones+total>1000000000: return "出售后灵石将超过持有上限。"
	var next := state.snapshot()
	for unit_id: String in units.slice(0,quantity): next.owned_units.erase(unit_id)
	next.spirit_stones += total
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var candidate: MapLoadoutState = prepared.state
	var error := candidate.restore(next)
	if error.is_empty(): error = MapLoadoutStore.save(candidate,save_path)
	if not error.is_empty(): return error
	# Removing concrete carried units cannot sell equipped/warehoused copies.
	# Publish money and ownership together only after the atomic write succeeds.
	return state.restore(candidate.snapshot())

func purchase(state: MapLoadoutState, item_id: String, quantity: int, save_path: String) -> String:
	# Price and item identity come from validated content, never from a UI total.
	var row := product(item_id)
	if row.is_empty() or quantity<1 or quantity>MAX_QUANTITY: return "商品或购买数量无效。"
	if state.inventory.locked: return "当前不能购买。"
	var price := buy_unit_price(item_id)
	if price<0: return "此物品尚未定价。"
	var total := price*quantity
	if state.spirit_stones < total: return "灵石不足，还差%d灵石。" % (total-state.spirit_stones)
	if state.purchase_serial>=1000000000: return "交易流水已达上限。"
	var next := state.snapshot()
	next.spirit_stones -= total
	next.purchase_serial += 1
	for index in quantity:
		var id := "purchase.%d.%d" % [int(next.purchase_serial),index]
		if next.owned_units.has(id): return "交易流水冲突，未扣款。"
		next.owned_units[id] = item_id
	var prepared := MapLoadoutStore.candidate(state)
	if not prepared.error.is_empty(): return prepared.error
	var candidate: MapLoadoutState = prepared.state
	var error := candidate.restore(next)
	if error.is_empty(): error = MapLoadoutStore.save(candidate,save_path)
	if not error.is_empty(): return error
	# Money and item ownership commit in one save; a failed write publishes neither.
	return state.restore(candidate.snapshot())
