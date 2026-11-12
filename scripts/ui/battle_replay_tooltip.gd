extends ItemTooltip
const Format = preload("res://scripts/presentation/battle_replay_format.gd")
const DETAILS := {"damage_direct":"直接伤害","damage_status":"状态独立伤害","damage_counter":"反击／追击伤害","hits":"命中结算","misses":"未命中／免疫","crits":"暴击结算","generated_barrier":"生成灵盾","generated_thunder_shield":"生成雷盾","generated_sword_screen":"生成剑幕","absorbed_barrier":"灵盾承伤","absorbed_thunder_shield":"雷盾承伤","absorbed_sword_screen":"剑幕承伤","shield_discarded":"替换失效盾值"}
var scroll: ScrollContainer

func configure_stats(item: ItemData, row: Dictionary, registry: ContentRegistry, snapshot: Dictionary, screen: Vector2, context: Dictionary = {}) -> void:
	effect_content_builder = func(content: VBoxContainer): _build_statistics(content,item,row,registry,snapshot,screen)
	configure(item,context)
	name = "BattleReplayTooltip"
	set_meta("replay",true)
	_ignore(self)

func _build_statistics(content: VBoxContainer, item: ItemData, row: Dictionary, registry: ContentRegistry, snapshot: Dictionary, screen: Vector2) -> void:
	var factor := UI_SCALE
	scroll=ScrollContainer.new()
	scroll.name="BattleStatisticsScroll"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var body:=VBoxContainer.new()
	body.name="BattleStatistics"
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",_px(8))
	scroll.add_child(body)
	_text(body,"本场战斗统计",factor)
	var m:Dictionary=row.get("metrics",{})
	var shown:Dictionary={}
	for entry:Dictionary in Format.lines(item,row):
		_metric(body,entry.key,entry.value,factor)
		shown[entry.key]=true
	_text(body,"效果与发动明细",factor)
	for key:String in Format.METRICS:
		if key in shown or key=="rotation" and not Format.rotates(item):continue
		if m.get(key,0)>0:_metric(body,key,m[key],factor)
	for key:String in DETAILS:
		if not m.has(key):continue
		_text(body,DETAILS[key]+"  "+Format.number(m[key]),factor)
	if Format.profile(item)=="attack":_text(body,"每次发动均伤  "+(Format.number(m.get("damage_total",0)/m.rotation) if m.get("rotation",0)>0 else "—"),factor)
	if not row.get("statuses",{}).is_empty():
		_text(body,"涉及状态："+"、".join(row.statuses.keys()),factor)
		if row.get("unknown_assist",false) or not m.has("damage_assist") and not m.has("damage_mitigated"):_text(body,"部分增减伤未单独量化；施加与参与次数已统计。",factor)
	for id:String in row.get("participants",[]):
		var participant:Dictionary=snapshot.get("items",{}).get(id,{})
		var definition:=registry.get_item(participant.get("item_id",""))
		_text(body,"参与武器："+(definition.display_name if definition!=null else id),factor)
	if m.is_empty():_text(body,"本场未产生可累计的实际效果。",factor)
	# Keep the shared item header visible; short statistics use only their actual height.
	var fit_body := func():
		var header := content.get_child(0) as Control
		var available := maxf(80,screen.y-header.get_combined_minimum_size().y-_px(90)-16)
		scroll.custom_minimum_size.y=minf(body.get_combined_minimum_size().y,minf(screen.y*0.55,available))
	body.resized.connect(fit_body)
	fit_body.call()

func _text(parent:Node,text:String,factor:float)->void:
	var label:=Label.new()
	label.text=text
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",_body_font)
	label.add_theme_font_size_override("font_size",roundi(22*factor))
	parent.add_child(label)

func _metric(parent:Node,key:String,value:float,factor:float)->void:
	var line:=HBoxContainer.new()
	line.add_theme_constant_override("separation",9)
	parent.add_child(line)
	var art:=TextureRect.new()
	art.texture=Format.icon(key)
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size=Vector2.ONE*24*factor
	line.add_child(art)
	_text(line,Format.METRICS[key][1]+"  "+Format.formatted(key,value),factor)

func scroll_by(amount:int)->void:
	if scroll!=null:scroll.scroll_vertical+=amount
