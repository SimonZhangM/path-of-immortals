class_name BattleStatusTooltip
extends PanelContainer

const WIDTH := 440.0
var word: String
var member: PartyMemberState
var manager: GameManager
var _current: Label
var _timing: Label
var _sources: Label
var _capacity: Label

func configure(status: String, actor: PartyMemberState, game: GameManager) -> void:
	word = status
	member = actor
	manager = game
	name = "BattleStatusTooltip"
	custom_minimum_size.x = WIDTH
	ItemTooltip._ensure_fonts()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b101b",0.98)
	style.border_color = Color("b59c60")
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",13)
	add_child(column)
	var buff: bool = ItemTooltip.status_keyword_kinds().get(word) == "buff"
	var title := _label(column,word + (" · 增益" if buff else " · 减益"),28)
	title.add_theme_color_override("font_color",Color(ItemTooltip.status_keyword_colors()[word]))
	title.add_theme_font_override("font",ItemTooltip._term_font)
	var effect: String = ItemTooltip.status_keyword_meanings()[word]
	if word == "毒蚀": effect = "首次2秒后开始，每秒按当前层数直接扣气血，绕过盾甲，每次减少1层。"
	if word == "雷蕴": effect += "\n雷盾：按60%吸收伤害，每层破裂向敌方施加1秒麻痹；优先于灵盾。"
	_label(column,effect,23)
	_line(column)
	var totals := HBoxContainer.new()
	column.add_child(totals)
	var caption := _label(totals,"当前 / 上限",22)
	caption.custom_minimum_size.x = 0
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	_current = _label(totals,"",22)
	_current.custom_minimum_size.x = 0
	_current.autowrap_mode = TextServer.AUTOWRAP_OFF
	_current.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_current.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timing = _label(column,"",20)
	_line(column)
	_label(column,"状态来源",22).add_theme_color_override("font_color",Color("f9f8c8"))
	_sources = _label(column,"",21)
	_label(column,"上限来源",22).add_theme_color_override("font_color",Color("f9f8c8"))
	_capacity = _label(column,"",21)
	_refresh()
	_ignore(self)

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = WIDTH - 44
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",ItemTooltip._body_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("e6e2cf"))
	parent.add_child(label)
	return label

func _line(parent: Node) -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("b59c60",0.4)
	style.thickness = 1
	line.add_theme_stylebox_override("separator",style)
	parent.add_child(line)

func _actor(id: String) -> PartyMemberState:
	if member != null and member.id == id: return member
	if is_instance_valid(manager):
		for team: Array in [manager.party,manager.enemies]:
			for actor: PartyMemberState in team:
				if actor.id == id: return actor
	return null

func _actor_name(actor: PartyMemberState) -> String:
	return str(actor.definition.get("name",actor.id))

func _capacity_text(actor: PartyMemberState) -> String:
	var source := "角色配置" if actor.definition.has("status_capacity") else str(actor.cultivation.get("name","境界"))
	return "%s · %s：%d层" % [_actor_name(actor),source,T01CombatRules.capacity(actor)]

func _refresh() -> void:
	if member == null: return
	var count := T01CombatRules.layers(member,word)
	if word == "毒蚀" and count == 0: count = member.toxin_stacks
	var pool: Dictionary = member.combat_statuses.get(word,{})
	var sources := {}
	for batch: Dictionary in pool.get("batches",[]):
		var id := str(batch.get("source",pool.get("source_id","")))
		sources[id] = int(sources.get(id,0)) + int(batch.count)
	var source_lines: PackedStringArray = []
	for id: String in sources:
		var actor := _actor(id)
		source_lines.append("%s：%d层" % [_actor_name(actor) if actor != null else "来源未记录",sources[id]])
	_sources.text = "\n".join(source_lines) if not source_lines.is_empty() else ("当前未生效" if count == 0 else "来源未记录")
	var buff: bool = ItemTooltip.status_keyword_kinds().get(word) == "buff"
	var cap_owner := member if buff else _actor(str(pool.get("source_id","")))
	_current.text = "%d / %s" % [count,str(T01CombatRules.capacity(cap_owner)) if cap_owner != null else "—"]
	_capacity.text = _capacity_text(cap_owner) if cap_owner != null else "由实际施加者的状态容量决定"
	if not buff and cap_owner != null:
		_capacity.text += "\n按当前施加者容量限制新增层数。"
	var now := manager.simulation.state.time_usec if is_instance_valid(manager) else 0
	var next := int(pool.get("next",0))
	var expires := int(pool.get("expires",0))
	var timing: PackedStringArray = []
	if next > now and word in ["生机","毒蚀","润脉","枯脉","流血","灼烧","重伤","破甲","驱散"]:
		timing.append("下次结算：%.1f秒后" % ((next-now)/1000000.0))
	if expires > now: timing.append("剩余时间：%.1f秒" % ((expires-now)/1000000.0))
	_timing.text = "\n".join(timing)
	_timing.visible = not _timing.text.is_empty()

func _process(_delta: float) -> void:
	_refresh()

func _ignore(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore(child)
