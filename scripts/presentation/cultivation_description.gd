class_name CultivationDescription
extends RefCounted

static func number(value: float) -> String:
	return EffectSystem.number_text(value)

static func spell(p: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("冷却：%s秒，实际发动消耗%s灵力。" % [number(p.cooldown*(1+float(p.get("cd_pct",0)))),number(p.spirit_cost*(1+float(p.get("cost_pct",0))))])
	lines.append("原书第%d重习得，独立占%d格。" % [int(p.learned_at_book_level),int(p.cells)])
	match p.opcode:
		"attack": lines.append("基础伤害%s，按法术型结算；基础命中%s%%，无武器普通暴击。" % [number(p.damage),number((.95+float(p.get("hit_bonus",0)))*100)])
		"sword_screen": lines.append("生成%s点剑幕，吸收%s%%伤害；替换其他特殊盾。%s" % [number(p.shield),number(p.absorption*100),"击破时返剑反击%s基础伤害。" % number(p.counter) if p.get("counter",0)>0 else ""])
		"enchant": lines.append("下一次武器发动附加其基础攻击%s%%的金属性法术伤害，只保留一份。" % number(p.ratio*100))
		"weapon_barrier": lines.append("以最强武器基础攻击的%s%%生成普通灵盾。%s" % [number(p.ratio*100),"下一次武器发动消耗本术剩余灵盾的一半，等量增加本体基础伤害。" if p.get("return_edge",false) else ""])
		"command_weapon": lines.append("调用一件合格武器攻击一次，另付该武器实际费用；参与武器自身CD不变。")
		"weapon_union": lines.append("合格武器合击一次：主兵%s%%、其他武器%s%%；各付一次当前费用的50%%，参与武器CD不变。" % [number(p.main_ratio*100),number(p.other_ratio*100)])
		"heal": lines.append("基础恢复%s气血。" % number(p.heal*(1+float(p.get("heal_pct",0)))))
		"guard_critical": lines.append("遇到原本会暴击的武器攻击时压为普通命中，各直接伤害部分减少%s%%，不判定或消耗坚韧。" % number(p.reduction*100))
		"force_critical": lines.append("下一次真实武器攻击命中必暴；钝击本体增加%s%%，钝击暴击倍率%s。" % [number(p.blunt_pct*100),number(p.blunt_critical)])
		"tax_cast": lines.append("敌方合格发动费用增加原基础费用的%s%%，并施加%d重伤；付不起则取消该次发动、重开CD。" % [number(p.surcharge*100),int(p.injury)])
		"armor_counter": lines.append("受击实际损失护甲且存活时，按本次实际扣甲的%s%%反震。" % number(p.ratio*100))
		"dodge": lines.append("下一次合格受击保证闪避。")
		"followup": lines.append("下一次武器命中后保证追击，基础取首击伤害的%s%%。" % number((.5+float(p.get("followup_bonus",0)))*100))
		"thunder_counter": lines.append("雷盾被攻击击破后反击一次，基础雷伤%s。" % number(p.damage))
		"change_cd": lines.append("使合格目标当前CD%s%s秒。" % ["延长" if p.has("delay_cd") else "提前",number(p.get("delay_cd",p.get("advance_cd",0)))])
	for entry: Dictionary in p.get("statuses",[]):
		lines.append("%s向%s施加%d层%s。" % [{"always":"发动时","hit":"命中后","hp_damage":"实际伤血后","armor_damage":"实际伤甲后"}[entry.gate],"自身" if entry.target=="self" else "目标",int(entry.count),entry.status])
	if p.has("damage_pct"): lines.append("本术主体伤害修正%s%s%%，与适用修正同基础相加。" % ["＋" if p.damage_pct>=0 else "",number(p.damage_pct*100)])
	if p.has("armor_only"): lines.append("盾后伤害另产生%s%%仅扣护甲伤害，超额作废。" % number(p.armor_only*100))
	if p.has("armor_bonus"): lines.append("盾后仍有护甲时伤害增加%s%%，可溢入气血。" % number(p.armor_bonus*100))
	if p.has("root"): lines.append("命中后武器定身%s秒。" % number(p.root))
	if p.has("drain_spirit"): lines.append("命中后抽取%s灵力。" % number(p.drain_spirit))
	if p.has("burst_status"): lines.append("依据攻击前%s层数追加伤害，每层%s基础伤害。" % [p.burst_status,number(p.burst_ratio*(1+float(p.get("burst_pct",0))))])
	if p.has("missing_scale"): lines.append("按敌方体力与灵力平均缺失比例增伤；两项上限为0的资源不参与均值。")
	if p.get("return_resources",false): lines.append("额外增伤部分的实际伤害按自身缺失比例回补体力与灵力。")
	if p.get("extra_chain",false): lines.append("引雷后可追加一次连环；未引雷时最多逐次触发两次连环。")
	if p.has("deferred"): lines.append("当前分支暂未启用："+str(p.deferred))
	lines.append("开启后CD完成进入待发，满足条件才付费；可单独关闭。" if p.prepared else "支持手动／自动，资源不足时保留就绪。")
	return "\n".join(lines)
