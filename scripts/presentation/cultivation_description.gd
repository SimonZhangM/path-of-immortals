class_name CultivationDescription
extends RefCounted

static func mastery_caption(stage: int) -> String:
	return "未领悟" if stage <= 0 else "习得%d重" % stage

static func tooltip_context(knowledge: CultivationKnowledge, book_id: String, item: ItemData = null) -> Dictionary:
	if item != null and item.category == "spell":
		return {"effect_description":spell(CultivationLibrary.resolve_spell(item.combat, knowledge)), "spell_knowledge":knowledge}
	return {"book_level": knowledge.level(book_id), "book_practice": knowledge.practice_value(book_id)}

static func number(value: float) -> String:
	return EffectSystem.number_text(value)

static func book(p: Dictionary) -> String:
	var lines: PackedStringArray = ["%s，共%d重。" % [p.role, int(p.max_level)]]
	var role := str(p.role)
	if role.begins_with("属性总纲"):
		lines.append("【学成常驻】学会相关强化后生效，无需原书上阵。")
	elif role.begins_with("状态专精"):
		lines.append("【学成常驻】已学状态专精无需原书上阵。")
	elif role.begins_with("战斗"):
		lines.append("【学成常驻】已学战斗被动无需原书上阵。")
		lines.append("【上阵生效】解锁法术须独立上阵使用，无需同时上阵原书。")
	else:
		lines.append("技艺分支强化专长，具体生产、探索玩法尚待接入。")
	lines.append("功法书不能放入阵盘。须在修炼点选修、累计修炼度升重；需有对应灵根并满足境界要求。")
	if int(p.max_level) == 8: lines.append("达到第一、三、五、七重时自动习得相应法术，法术独立上阵使用。")
	lines.append("分支确认后不能直接更换；当前不开放重选。")
	var pending: Dictionary = p.get("deferred_branches", {})
	if not pending.is_empty():
		var names: PackedStringArray = []
		for key: String in pending:
			names.append(str(p.get("branch_display_names", {}).get(key, key)))
		lines.append("【%s】连携系统开放后可用；当前仅可预览，可保留待选，不阻止继续升重。" % "／".join(names))
	if p.has("deferred"): lines.append(str(p.deferred))
	return "\n".join(lines)

static func spell(p: Dictionary) -> String:
	var lines: PackedStringArray = []
	var presentation: Dictionary = p.get("presentation", {})
	if not presentation.is_empty(): lines.append("《%s》第%d重。" % [presentation.book_name, int(p.learned_at_book_level)])
	var selected := str(p.get("selected_branch", ""))
	if not selected.is_empty(): lines.append("已选强化【%s】：%s" % [selected, presentation.get("branch_descriptions", {}).get(selected, "已按本术强化更新下列效果。")])
	if p.get("prepared", false):
		lines.append("预备式：上阵并开启后，冷却%s秒进入待发；触发时消耗%s灵力。" % [number(p.cooldown*(1+float(p.get("cd_pct",0)))),number(p.spirit_cost*(1+float(p.get("cost_pct",0))))])
	else:
		lines.append("冷却%s秒，施放时消耗%s灵力。" % [number(p.cooldown*(1+float(p.get("cd_pct",0)))),number(p.spirit_cost*(1+float(p.get("cost_pct",0))))])
	match p.opcode:
		"attack":
			lines.append("造成%s点法术伤害，基础命中率95%%，不会触发武器暴击。" % number(p.damage*(1+float(p.get("damage_pct",0)))))
			if p.get("hit_bonus",0) != 0:
				lines.append("本术命中率额外＋%s个百分点。" % number(p.hit_bonus*100))
		"sword_screen": lines.append("生成%s点剑幕，吸收%s%%伤害；替换其他特殊盾。%s" % [number(p.shield),number(p.absorption*100),"击破时返剑反击%s基础伤害。" % number(p.counter) if p.get("counter",0)>0 else ""])
		"enchant": lines.append("下一次武器发动附加其基础攻击%s%%的金属性法术伤害，只保留一份。" % number(p.ratio*100))
		"weapon_barrier": lines.append("以最强武器基础攻击的%s%%生成普通灵盾。%s" % [number(p.ratio*100),"下一次武器发动消耗本术剩余灵盾的一半，等量增加本体基础伤害。" if p.get("return_edge",false) else ""])
		"command_weapon": lines.append("驱使一件可用武器攻击一次，并支付该武器的攻击消耗；不改变武器自身的冷却。")
		"weapon_union": lines.append("驱使可用武器合击一次：主兵发挥%s%%威力，其他武器发挥%s%%威力；各消耗平时所需体力与灵力的一半，不改变武器自身的冷却。" % [number(p.main_ratio*100),number(p.other_ratio*100)])
		"heal": lines.append("恢复%s点气血。" % number(p.heal*(1+float(p.get("heal_pct",0)))))
		"guard_critical": lines.append("遇到原本会暴击的武器攻击时压为普通命中，各直接伤害部分减少%s%%，不判定或消耗坚韧。" % number(p.reduction*100))
		"force_critical": lines.append("下一次真实武器攻击命中必暴；钝击本体增加%s%%，钝击暴击倍率%s。" % [number(p.blunt_pct*100),number(p.blunt_critical)])
		"tax_cast": lines.append("敌方下一次需耗体灵的发动，非零基础费用各增加%s%%，并施加%d层重伤；敌方付不起加重后的费用时，取消该次发动、重开冷却，重伤仍会施加。" % [number(p.surcharge*100),int(p.injury)])
		"armor_counter": lines.append("受击实际损失护甲、且整次攻击结束后仍存活时，按本次实际扣甲的%s%%反震。" % number(p.ratio*100))
		"dodge": lines.append("下一次受到可闪避的攻击时，必定闪避。")
		"followup": lines.append("下一次武器原始攻击命中后必定追击1次，基础伤害取首击过盾甲前武器本体伤害的%s%%；另判命中，不复制独立附伤。" % number((.5+float(p.get("followup_bonus",0)))*100))
		"thunder_counter": lines.append("自身存活时，雷盾被攻击击破并成功麻痹攻击者，立即反击%s点基础雷伤；每次来袭攻击最多触发1次，反击另判命中。" % number(p.damage))
		"change_cd": lines.append("使可影响目标的当前冷却%s%s秒。" % ["延长" if p.has("delay_cd") else "提前",number(p.get("delay_cd",p.get("advance_cd",0)))])
	for entry: Dictionary in p.get("statuses",[]):
		lines.append("%s向%s施加%d层%s。" % [{"always":"发动时","hit":"命中后","hp_damage":"实际伤血后","armor_damage":"实际伤甲后"}[entry.gate],"自身" if entry.target=="self" else "目标",int(entry.count),entry.status])
	if p.has("damage_pct"): lines.append("本术主体伤害修正%s%s%%，与适用修正同基础相加。" % ["＋" if p.damage_pct>=0 else "",number(p.damage_pct*100)])
	if p.has("armor_only"): lines.append("盾后伤害另产生%s%%仅扣护甲伤害，超额作废。" % number(p.armor_only*100))
	if p.has("armor_bonus"): lines.append("盾后仍有护甲时伤害增加%s%%，可溢入气血。" % number(p.armor_bonus*100))
	if p.has("root"): lines.append("命中后使敌方武器定身%s秒，暂停其入阵、轮转与出击，期间不能被御兵调用。" % number(p.root))
	if p.has("drain_spirit"): lines.append("命中后削减目标%s点灵力，最多扣至0，不转扣体力。" % number(p.drain_spirit))
	if p.has("burst_status"):
		var applies_burst_status := false
		for entry: Dictionary in p.get("statuses", []):
			if entry.status == p.burst_status: applies_burst_status = true
		var status_note := "" if applies_burst_status else "本术不施加%s。" % p.burst_status
		lines.append("命中后读取攻击前目标已有的%s，每层追加%s基础伤害。%s" % [p.burst_status,number(p.burst_ratio*(1+float(p.get("burst_pct",0)))),status_note])
		if p.burst_status in ["疲惫", "重伤"]: lines.append("本术不消耗%s。" % p.burst_status)
	if p.has("missing_scale"): lines.append("按敌方体力与灵力平均缺失比例增伤；两项上限为0的资源不参与均值。")
	if p.get("return_resources",false): lines.append("额外增伤部分的实际伤害按自身缺失比例回补体力与灵力。")
	if p.get("extra_chain",false): lines.append("本体实际造成雷伤后，引雷可追加1次连环；未引雷时最多逐次触发2次连环。本术不施加雷印或连环，须借用目标已有状态。")
	if p.get("weapon_pct",0)>0: lines.append("本次御兵调用的武器本体伤害增加%s%%。" % number(p.weapon_pct*100))
	if p.get("bleed",0)>0: lines.append("附灵武器本次直接攻击实际伤及气血后施加%d层流血。" % int(p.bleed))
	if p.get("life_per_hp",0)>0: lines.append("实际伤及气血后，按该伤害的%s%%向自身施加生机，取整且至少1层。" % number(p.life_per_hp*100))
	if p.get("poison_entangle",0)>0: lines.append("命中已有毒蚀的目标时，额外施加%d层缠绕。" % int(p.poison_entangle))
	if p.get("drain_return",0)>0: lines.append("实际抽取灵力的%s%%返还自身。" % number(p.drain_return*100))
	if p.has("wither_resource"): lines.append("本次枯脉只作用于%s。" % ("灵力" if p.wither_resource=="spirit" else "体力"))
	if p.get("freeze_extra",0)>0: lines.append("本术触发的冰冻额外延长%s秒。" % number(p.freeze_extra))
	if p.has("missing_scale"): lines.append("资源完全缺失时，本术该项增伤上限%s%%。" % number(p.missing_scale*100))
	if p.has("damage_layers"): lines.append("读取攻击前目标已有的%s，每层使本体伤害增加%s%%，上限%s%%；本术不施加这些状态。" % ["／".join(p.damage_layers),number(p.layer_ratio*100),number(p.layer_cap*100)])
	if p.get("refresh_fire",false): lines.append("命中后刷新目标已有灼烧。")
	if p.get("tenacity",0)>0: lines.append("守岳触发后获得%d层坚韧。" % int(p.tenacity))
	if p.opcode=="force_critical" and p.get("injury",0)>0: lines.append("本次武器攻击造成有效伤害后施加%d层重伤。" % int(p.injury))
	if p.get("agility",0)>0: lines.append("成功闪避后获得%d层轻灵。" % int(p.agility))
	if p.opcode!="change_cd" and p.get("advance_cd",0)>0: lines.append("触发时使合格对象当前冷却提前%s秒。" % number(p.advance_cd))
	if p.get("followup_hit",0)>0: lines.append("本次追击命中增加%s个百分点。" % number(p.followup_hit*100))
	if p.get("pierce_bonus",0)>0: lines.append("穿刺武器追击额外增加%s个百分点。" % number(p.pierce_bonus*100))
	if p.get("dispel_bonus",0)>0: lines.append("本次驱散额外削减%s个百分点。" % number(p.dispel_bonus*100))
	if p.get("chain_bonus",0)>0: lines.append("本术触发的连环伤害增加%s%%。" % number(p.chain_bonus*100))
	if p.get("strike_bonus",0)>0: lines.append("本术触发的引雷伤害增加%s%%。" % number(p.strike_bonus*100))
	if p.get("counter_bonus",0)>0: lines.append("本术原有相克增伤额外增加%s个百分点。" % number(p.counter_bonus*100))
	if p.get("race_bonus",0)>0: lines.append("对妖／魔／鬼族的本术伤害额外增加%s%%。" % number(p.race_bonus*100))
	if p.get("paralysis_extension",0)>0: lines.append("命中后延长目标当前麻痹%s秒，不凭空施加麻痹。" % number(p.paralysis_extension))
	if p.has("deferred"): lines.append("连携系统开放后可用；当前仅可预览，不能确认选择。")
	return "\n".join(lines)
